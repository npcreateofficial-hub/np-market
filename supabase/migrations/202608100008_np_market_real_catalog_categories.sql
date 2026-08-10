-- Prepare the marketplace for real user testing: remove demo commerce rows
-- and use Shopee Thailand-like top-level categories as the product base.

delete from public.order_tracking_events
where order_id in (
  select id from public.orders
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.order_shipments
where order_id in (
  select id from public.orders
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.order_items
where order_id in (
  select id from public.orders
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.payments
where order_id in (
  select id from public.orders
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.orders
where shop_id in (
  select id from public.shops
  where owner_id in (
    select id from auth.users
    where email in ('admin@np-market.local', 'admin@gmail.com')
  )
  or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
);

delete from public.cart_items
where product_id in (
  select id from public.products
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.favorites
where product_id in (
  select id from public.products
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.product_variants
where product_id in (
  select id from public.products
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.product_media
where product_id in (
  select id from public.products
  where shop_id in (
    select id from public.shops
    where owner_id in (
      select id from auth.users
      where email in ('admin@np-market.local', 'admin@gmail.com')
    )
    or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
  )
);

delete from public.products
where shop_id in (
  select id from public.shops
  where owner_id in (
    select id from auth.users
    where email in ('admin@np-market.local', 'admin@gmail.com')
  )
  or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
);

delete from public.shop_documents
where shop_id in (
  select id from public.shops
  where owner_id in (
    select id from auth.users
    where email in ('admin@np-market.local', 'admin@gmail.com')
  )
  or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
);

delete from public.shop_carriers
where shop_id in (
  select id from public.shops
  where owner_id in (
    select id from auth.users
    where email in ('admin@np-market.local', 'admin@gmail.com')
  )
  or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio')
);

delete from public.shops
where owner_id in (
  select id from auth.users
  where email in ('admin@np-market.local', 'admin@gmail.com')
)
or name in ('NP Basics Store', 'Home Everyday', 'Daily Bag Studio');

delete from public.banners
where title ilike '%demo%' or title ilike '%NP Market Demo%';

insert into public.categories (name, sort_order)
values
  ('ความงามและของใช้ส่วนตัว', 1),
  ('กลุ่มผลิตภัณฑ์เพื่อสุขภาพ', 2),
  ('เสื้อผ้าแฟชั่นผู้ชาย', 3),
  ('เสื้อผ้าแฟชั่นผู้หญิง', 4),
  ('กระเป๋า', 5),
  ('รองเท้าผู้ชาย', 6),
  ('รองเท้าผู้หญิง', 7),
  ('เครื่องประดับ', 8),
  ('นาฬิกาและแว่นตา', 9),
  ('เครื่องใช้ในบ้าน', 10),
  ('อุปกรณ์อิเล็กทรอนิกส์', 11),
  ('มือถือ และ แท็บเล็ต', 12),
  ('เครื่องใช้ไฟฟ้าภายในบ้าน', 13),
  ('คอมพิวเตอร์และแล็ปท็อป', 14),
  ('กล้องและอุปกรณ์ถ่ายภาพ', 15),
  ('อาหารและเครื่องดื่ม', 16),
  ('ของเล่น สินค้าแม่และเด็ก', 17),
  ('กีฬาและกิจกรรมกลางแจ้ง', 18),
  ('สัตว์เลี้ยง', 19),
  ('เกมและอุปกรณ์เสริม', 20),
  ('ยานยนต์', 21),
  ('เครื่องเขียน หนังสือ และงานอดิเรก', 22),
  ('ตั๋วและบัตรกำนัล', 23),
  ('ช้อปปี้เพย์ใกล้ตัว', 24)
on conflict (name) do update
set sort_order = excluded.sort_order;