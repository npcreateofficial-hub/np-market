drop policy if exists "shop carriers readable" on public.shop_carriers;
create policy "shop carriers readable"
on public.shop_carriers for select
to anon, authenticated
using (true);

drop policy if exists "shop owners manage shop carriers" on public.shop_carriers;
create policy "shop owners manage shop carriers"
on public.shop_carriers for all
to authenticated
using (
  exists (
    select 1 from public.shops s
    where s.id = shop_id and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.shops s
    where s.id = shop_id and s.owner_id = (select auth.uid())
  )
);

drop policy if exists "shop owners manage product media" on public.product_media;
create policy "shop owners manage product media"
on public.product_media for all
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

drop policy if exists "shop owners manage product variants" on public.product_variants;
create policy "shop owners manage product variants"
on public.product_variants for all
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

drop policy if exists "buyers create own order items" on public.order_items;
create policy "buyers create own order items"
on public.order_items for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_id and o.buyer_id = (select auth.uid())
  )
);

drop policy if exists "buyers create own order shipments" on public.order_shipments;
create policy "buyers create own order shipments"
on public.order_shipments for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_id and o.buyer_id = (select auth.uid())
  )
);

drop policy if exists "shop owners update order shipments" on public.order_shipments;
create policy "shop owners update order shipments"
on public.order_shipments for update
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.shops s on s.id = o.shop_id
    where o.id = order_id and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.orders o
    join public.shops s on s.id = o.shop_id
    where o.id = order_id and s.owner_id = (select auth.uid())
  )
);

drop policy if exists "related users create tracking events" on public.order_tracking_events;
create policy "related users create tracking events"
on public.order_tracking_events for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    left join public.shops s on s.id = o.shop_id
    where o.id = order_id
      and (o.buyer_id = (select auth.uid()) or s.owner_id = (select auth.uid()))
  )
);

drop policy if exists "buyers create own payments" on public.payments;
create policy "buyers create own payments"
on public.payments for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_id and o.buyer_id = (select auth.uid())
  )
);
