drop policy if exists "owners and admins read private shop docs" on storage.objects;

create policy "owners and admins read private shop docs"
on storage.objects for select
to authenticated
using (
  bucket_id = 'shop-documents'
  and (
    owner_id = (select auth.uid())::text
    or public.is_admin()
  )
);