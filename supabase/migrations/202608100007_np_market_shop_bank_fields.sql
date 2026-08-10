alter table public.shops
  add column if not exists bank_account_name text not null default '',
  add column if not exists bank_account_number text not null default '',
  add column if not exists bank_name text not null default '';
