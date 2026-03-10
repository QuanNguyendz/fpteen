-- Allow store owner to read full_name, phone of customers who have orders at their store
-- (so canteen order list can show customer name instead of "Khách hàng")
CREATE POLICY "users_select_customer_for_store_owner"
  ON public.users FOR SELECT
  USING (
    id = auth.uid()
    OR public.is_admin()
    OR (
      public.current_user_role() = 'store_owner'
      AND EXISTS (
        SELECT 1 FROM public.orders o
        INNER JOIN public.stores s ON s.id = o.store_id AND s.owner_id = auth.uid()
        WHERE o.customer_id = public.users.id
      )
    )
  );
