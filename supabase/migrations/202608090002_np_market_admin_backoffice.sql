create extension if not exists pgcrypto;

create table if not exists public.admin_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null check (role in ('super_admin', 'shop_approver', 'order_admin', 'content_admin', 'support_admin')),
  is_active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shops
  add column if not exists review_note text not null default '',
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references public.admin_accounts(id) on delete set null;

create table if not exists public.shop_documents (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  type text not null check (type in ('identity_card', 'bank_book', 'business_license', 'other')),
  file_url text not null,
  file_path text not null default '',
  status text not null default 'pending_review' check (status in ('pending_review', 'approved', 'needs_fix', 'rejected')),
  note text not null default '',
  uploaded_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references public.admin_accounts(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  method public.payment_method not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'cancelled', 'refunded')),
  amount numeric(12,2) not null default 0,
  provider text not null default '',
  provider_ref text not null default '',
  evidence_url text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  payment_id uuid references public.payments(id) on delete set null,
  status text not null default 'requested' check (status in ('requested', 'reviewing', 'approved', 'rejected', 'paid')),
  reason text not null default '',
  amount numeric(12,2) not null default 0,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references public.admin_accounts(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'paid', 'held', 'cancelled')),
  gross_amount numeric(12,2) not null default 0,
  fee_amount numeric(12,2) not null default 0,
  net_amount numeric(12,2) not null default 0,
  bank_snapshot jsonb not null default '{}'::jsonb,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_fees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  fee_type text not null check (fee_type in ('percent', 'fixed')),
  value numeric(12,2) not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('shop', 'product', 'order', 'review', 'user')),
  target_id uuid,
  subject text not null,
  detail text not null default '',
  status text not null default 'pending' check (status in ('pending', 'reviewing', 'resolved', 'rejected')),
  assigned_admin_id uuid references public.admin_accounts(id) on delete set null,
  resolution_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  image_url text not null,
  link_url text not null default '',
  placement text not null default 'home',
  sort_order int not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  actor_role text not null default '',
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin(required_role text default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_accounts a
    where a.user_id = (select auth.uid())
      and a.is_active = true
      and (a.expires_at is null or a.expires_at > now())
      and (required_role is null or a.role = required_role or a.role = 'super_admin')
  );
$$;

revoke all on function public.is_admin(text) from public;
grant execute on function public.is_admin(text) to authenticated;

alter table public.admin_accounts enable row level security;
alter table public.shop_documents enable row level security;
alter table public.payments enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.platform_fees enable row level security;
alter table public.reports enable row level security;
alter table public.banners enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "admins read own account" on public.admin_accounts;
create policy "admins read own account" on public.admin_accounts
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin('super_admin'));

drop policy if exists "super admins manage admin accounts" on public.admin_accounts;
create policy "super admins manage admin accounts" on public.admin_accounts
  for all to authenticated
  using (public.is_admin('super_admin'))
  with check (public.is_admin('super_admin'));

drop policy if exists "admins read all shops" on public.shops;
create policy "admins read all shops" on public.shops
  for select to authenticated
  using (public.is_admin());

drop policy if exists "shop approvers update shops" on public.shops;
create policy "shop approvers update shops" on public.shops
  for update to authenticated
  using (public.is_admin('shop_approver'))
  with check (public.is_admin('shop_approver'));

drop policy if exists "admins read shop documents" on public.shop_documents;
create policy "admins read shop documents" on public.shop_documents
  for select to authenticated
  using (
    public.is_admin('shop_approver')
    or exists (
      select 1 from public.shops s
      where s.id = shop_id and s.owner_id = (select auth.uid())
    )
  );

drop policy if exists "shop owners upload documents" on public.shop_documents;
create policy "shop owners upload documents" on public.shop_documents
  for insert to authenticated
  with check (
    exists (
      select 1 from public.shops s
      where s.id = shop_id and s.owner_id = (select auth.uid())
    )
  );

drop policy if exists "shop approvers update documents" on public.shop_documents;
create policy "shop approvers update documents" on public.shop_documents
  for update to authenticated
  using (public.is_admin('shop_approver'))
  with check (public.is_admin('shop_approver'));

drop policy if exists "admins read all products" on public.products;
create policy "admins read all products" on public.products
  for select to authenticated
  using (public.is_admin());

drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products
  for all to authenticated
  using (public.is_admin('content_admin'))
  with check (public.is_admin('content_admin'));

drop policy if exists "admins manage product media" on public.product_media;
create policy "admins manage product media" on public.product_media
  for all to authenticated
  using (public.is_admin('content_admin'))
  with check (public.is_admin('content_admin'));

drop policy if exists "admins manage product variants" on public.product_variants;
create policy "admins manage product variants" on public.product_variants
  for all to authenticated
  using (public.is_admin('content_admin'))
  with check (public.is_admin('content_admin'));

drop policy if exists "admins read all orders" on public.orders;
create policy "admins read all orders" on public.orders
  for select to authenticated
  using (public.is_admin('order_admin') or public.is_admin('support_admin'));

drop policy if exists "order admins update orders" on public.orders;
create policy "order admins update orders" on public.orders
  for update to authenticated
  using (public.is_admin('order_admin'))
  with check (public.is_admin('order_admin'));

drop policy if exists "admins read all order items" on public.order_items;
create policy "admins read all order items" on public.order_items
  for select to authenticated
  using (public.is_admin('order_admin') or public.is_admin('support_admin'));

drop policy if exists "admins read all shipments" on public.order_shipments;
create policy "admins read all shipments" on public.order_shipments
  for select to authenticated
  using (public.is_admin('order_admin') or public.is_admin('support_admin'));

drop policy if exists "order admins manage shipments" on public.order_shipments;
create policy "order admins manage shipments" on public.order_shipments
  for all to authenticated
  using (public.is_admin('order_admin'))
  with check (public.is_admin('order_admin'));

drop policy if exists "admins read payments" on public.payments;
create policy "admins read payments" on public.payments
  for select to authenticated
  using (public.is_admin('order_admin'));

drop policy if exists "admins manage payments" on public.payments;
create policy "admins manage payments" on public.payments
  for all to authenticated
  using (public.is_admin('order_admin'))
  with check (public.is_admin('order_admin'));

drop policy if exists "admins manage refunds" on public.refunds;
create policy "admins manage refunds" on public.refunds
  for all to authenticated
  using (public.is_admin('order_admin') or public.is_admin('support_admin'))
  with check (public.is_admin('order_admin') or public.is_admin('support_admin'));

drop policy if exists "admins manage payouts" on public.payouts;
create policy "admins manage payouts" on public.payouts
  for all to authenticated
  using (public.is_admin('order_admin'))
  with check (public.is_admin('order_admin'));

drop policy if exists "admins manage platform fees" on public.platform_fees;
create policy "admins manage platform fees" on public.platform_fees
  for all to authenticated
  using (public.is_admin('super_admin'))
  with check (public.is_admin('super_admin'));

drop policy if exists "admins manage reports" on public.reports;
create policy "admins manage reports" on public.reports
  for all to authenticated
  using (public.is_admin('support_admin') or public.is_admin('shop_approver'))
  with check (public.is_admin('support_admin') or public.is_admin('shop_approver'));

drop policy if exists "public active banners readable" on public.banners;
create policy "public active banners readable" on public.banners
  for select to anon, authenticated
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

drop policy if exists "content admins manage banners" on public.banners;
create policy "content admins manage banners" on public.banners
  for all to authenticated
  using (public.is_admin('content_admin'))
  with check (public.is_admin('content_admin'));

drop policy if exists "admins read audit logs" on public.audit_logs;
create policy "admins read audit logs" on public.audit_logs
  for select to authenticated
  using (public.is_admin('super_admin'));

drop policy if exists "admins create audit logs" on public.audit_logs;
create policy "admins create audit logs" on public.audit_logs
  for insert to authenticated
  with check (public.is_admin());

insert into storage.buckets (id, name, public)
values
  ('product-media', 'product-media', true),
  ('shop-documents', 'shop-documents', false),
  ('payment-evidence', 'payment-evidence', false)
on conflict (id) do nothing;

drop policy if exists "product media public read" on storage.objects;
create policy "product media public read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'product-media');

drop policy if exists "authenticated product media upload" on storage.objects;
create policy "authenticated product media upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-media');

drop policy if exists "authenticated product media update" on storage.objects;
create policy "authenticated product media update" on storage.objects
  for update to authenticated
  using (bucket_id = 'product-media')
  with check (bucket_id = 'product-media');

drop policy if exists "owners and admins read private shop docs" on storage.objects;
create policy "owners and admins read private shop docs" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'shop-documents'
    and (owner_id = (select auth.uid())::text or public.is_admin('shop_approver'))
  );

drop policy if exists "authenticated upload private shop docs" on storage.objects;
create policy "authenticated upload private shop docs" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'shop-documents');

grant select on public.categories, public.carriers, public.banners, public.products, public.product_media, public.product_variants to anon;

grant select, insert, update, delete on
  public.profiles,
  public.addresses,
  public.shops,
  public.shop_carriers,
  public.products,
  public.product_media,
  public.product_variants,
  public.product_size_charts,
  public.favorites,
  public.cart_items,
  public.vouchers,
  public.orders,
  public.order_items,
  public.order_shipments,
  public.order_tracking_events,
  public.reviews,
  public.notifications,
  public.chat_threads,
  public.chat_messages,
  public.admin_accounts,
  public.shop_documents,
  public.payments,
  public.refunds,
  public.payouts,
  public.platform_fees,
  public.reports,
  public.banners,
  public.audit_logs
to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- After creating an auth user in Supabase Auth, promote that user once:
-- insert into public.admin_accounts (user_id, display_name, role)
-- select id, 'Owner Admin', 'super_admin'
-- from auth.users
-- where email = 'YOUR_ADMIN_EMAIL@example.com'
-- on conflict (user_id) do update set role = 'super_admin', is_active = true;
