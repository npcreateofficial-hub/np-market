alter table public.shops
  add column if not exists pickup_district text not null default '',
  add column if not exists pickup_sub_district text not null default '',
  add column if not exists pickup_postcode text not null default '';
