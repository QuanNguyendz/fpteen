-- Pickup time-slot + store capacity configuration
-- Enables scheduling orders to reduce peak overload.

ALTER TABLE public.stores
  ADD COLUMN IF NOT EXISTS slot_size_minutes integer NOT NULL DEFAULT 15 CHECK (slot_size_minutes > 0),
  ADD COLUMN IF NOT EXISTS max_orders_per_slot integer NOT NULL DEFAULT 20 CHECK (max_orders_per_slot > 0),
  ADD COLUMN IF NOT EXISTS opening_time time NOT NULL DEFAULT TIME '10:00',
  ADD COLUMN IF NOT EXISTS closing_time time NOT NULL DEFAULT TIME '22:00';

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS pickup_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_orders_store_pickup_at
  ON public.orders (store_id, pickup_at);

