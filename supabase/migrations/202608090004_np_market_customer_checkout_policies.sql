-- Customer checkout policies.
-- Run this after the core/admin migrations so the Flutter app can create real orders.

drop policy if exists "buyers create own order items" on public.order_items;
create policy "buyers create own order items" on public.order_items
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders o
      where o.id = order_id
        and o.buyer_id = (select auth.uid())
    )
  );

drop policy if exists "buyers create own shipments" on public.order_shipments;
create policy "buyers create own shipments" on public.order_shipments
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders o
      where o.id = order_id
        and o.buyer_id = (select auth.uid())
    )
  );

drop policy if exists "buyers create own payment rows" on public.payments;
create policy "buyers create own payment rows" on public.payments
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders o
      where o.id = order_id
        and o.buyer_id = (select auth.uid())
    )
  );

drop policy if exists "buyers read own payment rows" on public.payments;
create policy "buyers read own payment rows" on public.payments
  for select to authenticated
  using (
    exists (
      select 1
      from public.orders o
      where o.id = order_id
        and o.buyer_id = (select auth.uid())
    )
  );
