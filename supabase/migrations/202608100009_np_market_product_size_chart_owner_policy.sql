drop policy if exists "shop owners manage product size charts" on public.product_size_charts;
grant select on public.product_size_charts to anon, authenticated;

create policy "shop owners manage product size charts"
on public.product_size_charts for all
to authenticated
using (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = (select auth.uid())
  )
);
