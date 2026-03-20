-- RPCs for pickup scheduling / capacity enforcement

CREATE OR REPLACE FUNCTION public.get_store_pickup_slots(
  p_store_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE (
  slot_start TIMESTAMPTZ,
  slot_end TIMESTAMPTZ,
  slot_label TEXT,
  capacity_per_slot INT,
  order_count INT,
  remaining INT
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_slot_size_minutes INT;
  v_max_orders_per_slot INT;
  v_opening_time TIME;
  v_closing_time TIME;
  v_tz TEXT := 'Asia/Ho_Chi_Minh';

  v_from_local TIMESTAMP;
  v_day_local TIMESTAMP;
  v_minute_of_day INT;
  v_slot_index INT;
  v_first_slot_start TIMESTAMPTZ;

  v_slot_start TIMESTAMPTZ;
  v_slot_end TIMESTAMPTZ;
  v_local_time TIME;
  v_order_count INT;
  v_remaining INT;
BEGIN
  SELECT
    slot_size_minutes,
    max_orders_per_slot,
    opening_time,
    closing_time
  INTO
    v_slot_size_minutes,
    v_max_orders_per_slot,
    v_opening_time,
    v_closing_time
  FROM public.stores
  WHERE id = p_store_id
    AND is_active = true;

  IF v_slot_size_minutes IS NULL THEN
    RAISE EXCEPTION 'Store not found or inactive';
  END IF;

  v_from_local := p_from AT TIME ZONE v_tz;
  v_day_local := date_trunc('day', v_from_local);
  v_minute_of_day := (EXTRACT(HOUR FROM v_from_local)::INT * 60) + (EXTRACT(MINUTE FROM v_from_local)::INT);
  v_slot_index := FLOOR(v_minute_of_day::NUMERIC / v_slot_size_minutes::NUMERIC)::INT;
  v_first_slot_start := (v_day_local + make_interval(mins => v_slot_index * v_slot_size_minutes)) AT TIME ZONE v_tz;

  FOR v_slot_start IN
    SELECT generate_series(
      v_first_slot_start,
      p_to,
      make_interval(mins => v_slot_size_minutes)
    )
  LOOP
    v_slot_end := v_slot_start + make_interval(mins => v_slot_size_minutes);
    v_local_time := (v_slot_start AT TIME ZONE v_tz)::TIME;

    -- Only keep slots inside opening window for that day.
    IF v_local_time < v_opening_time OR v_local_time >= v_closing_time THEN
      CONTINUE;
    END IF;

    SELECT COUNT(*) INTO v_order_count
    FROM public.orders
    WHERE store_id = p_store_id
      AND pickup_at >= v_slot_start
      AND pickup_at < v_slot_end
      AND (
        status IN ('paid', 'confirmed')
        OR (status = 'pending' AND created_at >= (now() - INTERVAL '15 minutes'))
      );

    v_remaining := GREATEST(v_max_orders_per_slot - v_order_count, 0);
    IF v_remaining <= 0 THEN
      CONTINUE;
    END IF;

    slot_start := v_slot_start;
    slot_end := v_slot_end;
    slot_label := to_char(v_slot_start AT TIME ZONE v_tz, 'HH24:MI');
    capacity_per_slot := v_max_orders_per_slot;
    order_count := v_order_count;
    remaining := v_remaining;
    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;


CREATE OR REPLACE FUNCTION public.create_order_with_items_and_pickup(
  p_store_id UUID,
  p_items JSONB,
  p_note TEXT DEFAULT NULL,
  p_pickup_at_requested TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  order_id UUID,
  assigned_pickup_at TIMESTAMPTZ,
  rescheduled BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_order_id UUID;
  v_total BIGINT := 0;
  v_caller_role TEXT;

  v_slot_size_minutes INT;
  v_max_orders_per_slot INT;
  v_opening_time TIME;
  v_closing_time TIME;
  v_tz TEXT := 'Asia/Ho_Chi_Minh';

  v_req_pickup_at TIMESTAMPTZ;
  v_candidate_start TIMESTAMPTZ;
  v_slot_start TIMESTAMPTZ;
  v_slot_end TIMESTAMPTZ;

  v_assigned_pickup_at TIMESTAMPTZ;
  v_rescheduled BOOLEAN := false;

  v_order_count INT;
  v_pending_active_window INTERVAL := INTERVAL '15 minutes';

  v_from_local TIMESTAMP;
  v_day_local TIMESTAMP;
  v_minute_of_day INT;
  v_slot_index INT;
BEGIN
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role != 'customer' THEN
    RAISE EXCEPTION 'Only customers can place orders';
  END IF;

  SELECT
    slot_size_minutes,
    max_orders_per_slot,
    opening_time,
    closing_time
  INTO
    v_slot_size_minutes,
    v_max_orders_per_slot,
    v_opening_time,
    v_closing_time
  FROM public.stores
  WHERE id = p_store_id
    AND is_active = true;

  IF v_slot_size_minutes IS NULL THEN
    RAISE EXCEPTION 'Store not found or inactive';
  END IF;

  v_req_pickup_at := COALESCE(p_pickup_at_requested, now());

  -- Compute the first candidate slot start (ceiling to slot boundary).
  v_from_local := v_req_pickup_at AT TIME ZONE v_tz;
  v_day_local := date_trunc('day', v_from_local);
  v_minute_of_day := (EXTRACT(HOUR FROM v_from_local)::INT * 60) + (EXTRACT(MINUTE FROM v_from_local)::INT);
  v_slot_index := FLOOR(v_minute_of_day::NUMERIC / v_slot_size_minutes::NUMERIC)::INT;

  v_candidate_start :=
    ((v_day_local + make_interval(mins => v_slot_index * v_slot_size_minutes)) AT TIME ZONE v_tz);

  IF v_candidate_start < v_req_pickup_at THEN
    v_candidate_start := v_candidate_start + make_interval(mins => v_slot_size_minutes);
  END IF;

  -- Ensure candidate is not in the past.
  WHILE v_candidate_start < now() LOOP
    v_candidate_start := v_candidate_start + make_interval(mins => v_slot_size_minutes);
  END LOOP;

  -- Calculate total using server-side prices (never trust client prices).
  SELECT COALESCE(SUM(mi.price * (item->>'quantity')::INTEGER), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item
  JOIN public.menu_items mi ON mi.id = (item->>'menu_item_id')::UUID
  WHERE mi.store_id = p_store_id AND mi.is_available = true;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'No valid available items in order';
  END IF;

  -- Search next slots within a horizon.
  v_slot_start := v_candidate_start;
  v_assigned_pickup_at := NULL;

  FOR i IN 0..240 LOOP -- max 240 slots * up to 15min ~ 60h, effectively bounded by horizon below
    v_slot_start := v_candidate_start + (i * make_interval(mins => v_slot_size_minutes));
    v_slot_end := v_slot_start + make_interval(mins => v_slot_size_minutes);

    -- Horizon: 6 hours
    IF v_slot_start > (now() + INTERVAL '6 hours') THEN
      EXIT;
    END IF;

    -- Opening window filter
    IF (v_slot_start AT TIME ZONE v_tz)::TIME < v_opening_time
       OR (v_slot_start AT TIME ZONE v_tz)::TIME >= v_closing_time THEN
      CONTINUE;
    END IF;

    SELECT COUNT(*) INTO v_order_count
    FROM public.orders
    WHERE store_id = p_store_id
      AND pickup_at >= v_slot_start
      AND pickup_at < v_slot_end
      AND (
        status IN ('paid', 'confirmed')
        OR (status = 'pending' AND created_at >= (now() - v_pending_active_window))
      );

    IF v_order_count < v_max_orders_per_slot THEN
      v_assigned_pickup_at := v_slot_start;
      EXIT;
    END IF;
  END LOOP;

  IF v_assigned_pickup_at IS NULL THEN
    RAISE EXCEPTION 'No available pickup slots within horizon';
  END IF;

  v_rescheduled := (p_pickup_at_requested IS NOT NULL) AND (v_assigned_pickup_at <> v_candidate_start);

  -- Insert order
  INSERT INTO public.orders (store_id, customer_id, total_amount, note, pickup_at)
  VALUES (p_store_id, auth.uid(), v_total, p_note, v_assigned_pickup_at)
  RETURNING id INTO v_order_id;

  -- Insert items
  INSERT INTO public.order_items (order_id, menu_item_id, quantity, unit_price)
  SELECT
    v_order_id,
    (item->>'menu_item_id')::UUID,
    (item->>'quantity')::INTEGER,
    mi.price
  FROM jsonb_array_elements(p_items) AS item
  JOIN public.menu_items mi ON mi.id = (item->>'menu_item_id')::UUID
  WHERE mi.store_id = p_store_id AND mi.is_available = true;

  order_id := v_order_id;
  assigned_pickup_at := v_assigned_pickup_at;
  rescheduled := v_rescheduled;
  RETURN NEXT;
END;
$$;

