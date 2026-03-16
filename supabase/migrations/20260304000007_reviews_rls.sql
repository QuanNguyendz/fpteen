-- RLS policies for menu_item_reviews

ALTER TABLE public.menu_item_reviews ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read reviews; menu UI needs aggregates and (optional) review list later.
CREATE POLICY "reviews_select_all"
  ON public.menu_item_reviews FOR SELECT
  USING (true);

-- Customer can create a review only if they've paid/confirmed an order containing that menu item.
CREATE POLICY "reviews_insert_paid_customer_only"
  ON public.menu_item_reviews FOR INSERT
  WITH CHECK (
    reviewer_id = auth.uid()
    AND public.current_user_role() = 'customer'
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      JOIN public.order_items oi ON oi.order_id = o.id
      WHERE o.customer_id = auth.uid()
        AND o.status IN ('paid', 'confirmed')
        AND oi.menu_item_id = menu_item_reviews.menu_item_id
    )
  );

-- Customer can update their own review (allow edit).
CREATE POLICY "reviews_update_own"
  ON public.menu_item_reviews FOR UPDATE
  USING (reviewer_id = auth.uid());

