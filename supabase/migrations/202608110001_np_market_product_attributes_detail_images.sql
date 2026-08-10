create table if not exists public.product_attributes (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  value text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (product_id, name)
);

create index if not exists product_attributes_product_id_sort_order_idx
on public.product_attributes(product_id, sort_order);

create table if not exists public.product_detail_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (product_id, image_url)
);

create index if not exists product_detail_images_product_id_sort_order_idx
on public.product_detail_images(product_id, sort_order);

alter table public.product_attributes enable row level security;
alter table public.product_detail_images enable row level security;

drop policy if exists "product attributes readable" on public.product_attributes;
create policy "product attributes readable"
on public.product_attributes for select
using (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id
      and p.status in ('active', 'sold_out')
      and s.status = 'active'
  )
);

drop policy if exists "shop owners manage product attributes" on public.product_attributes;
create policy "shop owners manage product attributes"
on public.product_attributes for all
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

drop policy if exists "admins manage product attributes" on public.product_attributes;
create policy "admins manage product attributes"
on public.product_attributes for all
to authenticated
using (public.is_admin('content_admin'))
with check (public.is_admin('content_admin'));

drop policy if exists "product detail images readable" on public.product_detail_images;
create policy "product detail images readable"
on public.product_detail_images for select
using (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id
      and p.status in ('active', 'sold_out')
      and s.status = 'active'
  )
);

drop policy if exists "shop owners manage product detail images" on public.product_detail_images;
create policy "shop owners manage product detail images"
on public.product_detail_images for all
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

drop policy if exists "admins manage product detail images" on public.product_detail_images;
create policy "admins manage product detail images"
on public.product_detail_images for all
to authenticated
using (public.is_admin('content_admin'))
with check (public.is_admin('content_admin'));

grant select on public.product_attributes to anon, authenticated;
grant insert, update, delete on public.product_attributes to authenticated;
grant select on public.product_detail_images to anon, authenticated;
grant insert, update, delete on public.product_detail_images to authenticated;
