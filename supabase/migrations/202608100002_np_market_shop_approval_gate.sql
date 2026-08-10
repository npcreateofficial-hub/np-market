alter table public.shops
  alter column status set default 'pending_review';

drop policy if exists "public active products readable" on public.products;
create policy "public approved shop active products readable"
on public.products for select
using (
  status = 'active'
  and exists (
    select 1
    from public.shops s
    where s.id = shop_id
      and s.status = 'active'
  )
);
