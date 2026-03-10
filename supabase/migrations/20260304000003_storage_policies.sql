-- Storage policies for menu-images bucket
-- Allow store_owner and admin to upload/update/delete images
-- Path-level ownership is enforced at the app layer (uploadMenuImage always uses the correct storeId)

-- Drop old policies if they exist (safe to re-run)
DROP POLICY IF EXISTS "menu_images_select_public"    ON storage.objects;
DROP POLICY IF EXISTS "menu_images_insert_store_owner" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_update_store_owner" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_delete_store_owner" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_insert_auth"      ON storage.objects;
DROP POLICY IF EXISTS "menu_images_update_auth"      ON storage.objects;
DROP POLICY IF EXISTS "menu_images_delete_auth"      ON storage.objects;

-- Allow anyone to view images (public bucket)
CREATE POLICY "menu_images_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'menu-images');

-- Allow store_owner or admin to upload
CREATE POLICY "menu_images_insert_auth"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'menu-images'
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
        AND role IN ('store_owner', 'admin')
    )
  );

-- Allow store_owner or admin to update
CREATE POLICY "menu_images_update_auth"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'menu-images'
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
        AND role IN ('store_owner', 'admin')
    )
  );

-- Allow store_owner or admin to delete
CREATE POLICY "menu_images_delete_auth"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'menu-images'
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
        AND role IN ('store_owner', 'admin')
    )
  );
