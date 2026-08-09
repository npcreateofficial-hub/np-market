create extension if not exists pgcrypto;

create type public.shop_status as enum ('draft', 'pending_review', 'active', 'paused', 'suspended');
create type public.product_status as enum ('draft', 'active', 'sold_out', 'hidden', 'suspended');
create type public.order_status as enum (
  'pending_payment',
  'seller_confirming',
  'awaiting_shipment',
  'packed',
  'shipped',
  'in_transit',
  'delivered',
  'completed',
  'cancelled',
  'return_refund'
);
create type public.payment_method as enum ('cod', 'promptpay_qr', 'mobile_banking', 'card');
create type public.media_type as enum ('image', 'video');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone text not null default '',
  avatar_url text,
  role text not null default 'buyer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipient_name text not null,
  phone text not null,
  detail text not null,
  province text not null,
  district text not null,
  sub_district text not null,
  postcode text not null,
  label text not null default '',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  category text not null,
  description text not null default '',
  logo_url text,
  phone text not null default '',
  pickup_address text not null default '',
  pickup_province text not null default '',
  rating numeric(2,1) not null default 0,
  response_rate int not null default 0,
  status public.shop_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.carriers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  is_active boolean not null default true
);

create table public.shop_carriers (
  shop_id uuid not null references public.shops(id) on delete cascade,
  carrier_id uuid not null references public.carriers(id) on delete restrict,
  is_enabled boolean not null default true,
  primary key (shop_id, carrier_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  parent_id uuid references public.categories(id) on delete set null,
  sort_order int not null default 0
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text not null default '',
  sku text not null default '',
  price numeric(12,2) not null check (price >= 0),
  original_price numeric(12,2) not null default 0 check (original_price >= 0),
  stock int not null default 0 check (stock >= 0),
  weight_kg numeric(8,2) not null default 0,
  parcel_size text not null default '',
  ship_from_province text not null default '',
  badge text not null default '',
  status public.product_status not null default 'active',
  sold_count int not null default 0,
  rating numeric(2,1) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  type public.media_type not null,
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  color text not null default '',
  size text not null default '',
  sku text not null default '',
  image_url text,
  price numeric(12,2),
  stock int not null default 0 check (stock >= 0),
  is_active boolean not null default true
);

create table public.product_size_charts (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text,
  rows jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  quantity int not null check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vouchers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id) on delete cascade,
  code text not null unique,
  title text not null,
  discount_amount numeric(12,2) not null default 0,
  min_spend numeric(12,2) not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_no text not null unique,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid references public.shops(id) on delete set null,
  address_id uuid references public.addresses(id) on delete set null,
  shipping_address jsonb not null default '{}'::jsonb,
  status public.order_status not null default 'seller_confirming',
  payment_method public.payment_method not null default 'cod',
  subtotal numeric(12,2) not null default 0,
  shipping_fee numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  grand_total numeric(12,2) not null default 0,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,
  product_snapshot jsonb not null default '{}'::jsonb,
  quantity int not null check (quantity > 0),
  unit_price numeric(12,2) not null default 0,
  total_price numeric(12,2) not null default 0
);

create table public.order_shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  carrier_id uuid references public.carriers(id) on delete set null,
  carrier_name text not null default '',
  tracking_number text not null default '',
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_tracking_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null,
  title text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  shop_id uuid references public.shops(id) on delete set null,
  rating int not null check (rating between 1 and 5),
  comment text not null default '',
  media_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'general',
  ref_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  last_message text not null default '',
  updated_at timestamptz not null default now(),
  unique (buyer_id, shop_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

insert into public.carriers (code, name) values
  ('flash', 'Flash Express'),
  ('kex', 'KEX'),
  ('express', 'Express'),
  ('thai_post', 'ไปรษณีย์ไทย'),
  ('jnt', 'J&T Express')
on conflict (code) do nothing;

insert into public.categories (name, sort_order) values
  ('แฟชั่น', 1),
  ('กระเป๋า', 2),
  ('ของใช้ในบ้าน', 3),
  ('อิเล็กทรอนิกส์', 4),
  ('ความงาม', 5),
  ('อาหารและเครื่องดื่ม', 6)
on conflict (name) do nothing;

create index products_shop_id_idx on public.products(shop_id);
create index products_status_idx on public.products(status);
create index product_media_product_id_idx on public.product_media(product_id);
create index product_variants_product_id_idx on public.product_variants(product_id);
create index cart_items_user_id_idx on public.cart_items(user_id);
create index orders_buyer_id_idx on public.orders(buyer_id);
create index orders_shop_id_idx on public.orders(shop_id);
create index order_items_order_id_idx on public.order_items(order_id);
create index order_tracking_events_order_id_idx on public.order_tracking_events(order_id);
create index notifications_user_id_idx on public.notifications(user_id);

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.shops enable row level security;
alter table public.shop_carriers enable row level security;
alter table public.products enable row level security;
alter table public.product_media enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_size_charts enable row level security;
alter table public.favorites enable row level security;
alter table public.cart_items enable row level security;
alter table public.vouchers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_shipments enable row level security;
alter table public.order_tracking_events enable row level security;
alter table public.reviews enable row level security;
alter table public.notifications enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;

create policy "profiles are readable by users" on public.profiles for select using (true);
create policy "users manage own profile" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "users manage own addresses" on public.addresses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "shops are public readable" on public.shops for select using (true);
create policy "owners manage own shops" on public.shops for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy "public active products readable" on public.products for select using (status = 'active');
create policy "shop owners manage products" on public.products for all
  using (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()))
  with check (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()));

create policy "product media readable" on public.product_media for select using (true);
create policy "product variants readable" on public.product_variants for select using (true);
create policy "product size charts readable" on public.product_size_charts for select using (true);

create policy "users manage own favorites" on public.favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage own cart" on public.cart_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "active vouchers readable" on public.vouchers for select using (is_active = true);

create policy "buyers read own orders" on public.orders for select using (auth.uid() = buyer_id);
create policy "buyers create own orders" on public.orders for insert with check (auth.uid() = buyer_id);
create policy "shop owners read and update shop orders" on public.orders for all
  using (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()))
  with check (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()));

create policy "order items readable by related users" on public.order_items for select
  using (exists (
    select 1 from public.orders o
    left join public.shops s on s.id = o.shop_id
    where o.id = order_id and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
  ));

create policy "shipments readable by related users" on public.order_shipments for select
  using (exists (
    select 1 from public.orders o
    left join public.shops s on s.id = o.shop_id
    where o.id = order_id and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
  ));

create policy "tracking readable by related users" on public.order_tracking_events for select
  using (exists (
    select 1 from public.orders o
    left join public.shops s on s.id = o.shop_id
    where o.id = order_id and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
  ));

create policy "users read own notifications" on public.notifications for select using (auth.uid() = user_id);

create policy "chat threads visible to buyer or shop owner" on public.chat_threads for select
  using (auth.uid() = buyer_id or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()));

create policy "chat messages visible to thread members" on public.chat_messages for select
  using (exists (
    select 1 from public.chat_threads t
    left join public.shops s on s.id = t.shop_id
    where t.id = thread_id and (t.buyer_id = auth.uid() or s.owner_id = auth.uid())
  ));
