create table if not exists public.product_variant_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  option_type text not null check (option_type in ('color', 'size')),
  option_value text not null,
  image_url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (product_id, option_type, option_value)
);

create index if not exists product_variant_images_product_id_idx
on public.product_variant_images(product_id);

alter table public.product_variant_images enable row level security;

drop policy if exists "product variant images readable" on public.product_variant_images;
create policy "product variant images readable"
on public.product_variant_images for select
using (true);

drop policy if exists "shop owners manage product variant images" on public.product_variant_images;
create policy "shop owners manage product variant images"
on public.product_variant_images for all
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

drop policy if exists "admins manage product variant images" on public.product_variant_images;
create policy "admins manage product variant images"
on public.product_variant_images for all
to authenticated
using (public.is_admin('content_admin'))
with check (public.is_admin('content_admin'));

grant select on public.product_variant_images to anon, authenticated;
grant insert, update, delete on public.product_variant_images to authenticated;
