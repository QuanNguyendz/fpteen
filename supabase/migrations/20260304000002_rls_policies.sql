-- FPTeen RLS Policies
-- ============================================================
-- ENABLE RLS
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- ============================================================
-- USERS
-- ============================================================

CREATE POLICY "users_select_own_or_admin"
  ON public.users FOR SELECT
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "users_insert_self"
  ON public.users FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "users_update_self_or_admin"
  ON public.users FOR UPDATE
  USING (id = auth.uid() OR public.is_admin());

-- ============================================================
-- STORES
-- ============================================================

CREATE POLICY "stores_select_active_or_owner"
  ON public.stores FOR SELECT
  USING (is_active = true OR owner_id = auth.uid() OR public.is_admin());

CREATE POLICY "stores_insert_owner_or_admin"
  ON public.stores FOR INSERT
  WITH CHECK (
    (owner_id = auth.uid() AND public.current_user_role() = 'store_owner')
    OR public.is_admin()
  );

CREATE POLICY "stores_update_owner_or_admin"
  ON public.stores FOR UPDATE
  USING (owner_id = auth.uid() OR public.is_admin());

CREATE POLICY "stores_delete_admin_only"
  ON public.stores FOR DELETE
  USING (public.is_admin());

-- ============================================================
-- CATEGORIES
-- ============================================================

CREATE POLICY "categories_select_all"
  ON public.categories FOR SELECT
  USING (true);

CREATE POLICY "categories_insert_store_owner"
  ON public.categories FOR INSERT
  WITH CHECK (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "categories_update_store_owner"
  ON public.categories FOR UPDATE
  USING (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "categories_delete_store_owner"
  ON public.categories FOR DELETE
  USING (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

-- ============================================================
-- MENU ITEMS
-- ============================================================

CREATE POLICY "menu_items_select_all"
  ON public.menu_items FOR SELECT
  USING (true);

CREATE POLICY "menu_items_insert_store_owner"
  ON public.menu_items FOR INSERT
  WITH CHECK (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "menu_items_update_store_owner"
  ON public.menu_items FOR UPDATE
  USING (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "menu_items_delete_store_owner"
  ON public.menu_items FOR DELETE
  USING (
    store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

-- ============================================================
-- ORDERS
-- ============================================================

CREATE POLICY "orders_select_relevant_parties"
  ON public.orders FOR SELECT
  USING (
    customer_id = auth.uid()
    OR store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "orders_insert_customer_only"
  ON public.orders FOR INSERT
  WITH CHECK (
    customer_id = auth.uid()
    AND public.current_user_role() = 'customer'
  );

CREATE POLICY "orders_update_relevant_parties"
  ON public.orders FOR UPDATE
  USING (
    customer_id = auth.uid()
    OR store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

-- ============================================================
-- ORDER ITEMS
-- ============================================================

CREATE POLICY "order_items_select_via_order"
  ON public.order_items FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE customer_id = auth.uid()
         OR store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    )
    OR public.is_admin()
  );

CREATE POLICY "order_items_insert_customer_pending"
  ON public.order_items FOR INSERT
  WITH CHECK (
    order_id IN (
      SELECT id FROM public.orders
      WHERE customer_id = auth.uid() AND status = 'pending'
    )
  );

-- ============================================================
-- PAYMENTS
-- ============================================================

CREATE POLICY "payments_select_via_order"
  ON public.payments FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE customer_id = auth.uid()
         OR store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid())
    )
    OR public.is_admin()
  );

CREATE POLICY "payments_insert_customer"
  ON public.payments FOR INSERT
  WITH CHECK (
    order_id IN (
      SELECT id FROM public.orders WHERE customer_id = auth.uid()
    )
  );

-- ============================================================
-- REPORTS
-- ============================================================

CREATE POLICY "reports_select_own_or_admin"
  ON public.reports FOR SELECT
  USING (reporter_id = auth.uid() OR public.is_admin());

CREATE POLICY "reports_insert_customer_only"
  ON public.reports FOR INSERT
  WITH CHECK (
    reporter_id = auth.uid()
    AND public.current_user_role() = 'customer'
  );

CREATE POLICY "reports_update_admin_only"
  ON public.reports FOR UPDATE
  USING (public.is_admin());

-- ============================================================
-- REALTIME: enable for live order updates
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;
