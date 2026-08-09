-- NP Market demo data for one connected test loop:
-- Admin web sees shops/products/orders, and Flutter app reads the same active products.
-- Run this after creating at least one Supabase Auth user.

do $$
declare
  demo_user_id uuid;
  fashion_id uuid;
  bag_id uuid;
  home_id uuid;
  beauty_id uuid;
  carrier_flash_id uuid;
  carrier_jnt_id uuid;
begin
  select id
  into demo_user_id
  from auth.users
  order by created_at
  limit 1;

  if demo_user_id is null then
    raise exception 'Please create one user in Supabase Auth first, then run this seed again.';
  end if;

  insert into public.profiles (id, display_name, phone, role)
  values (demo_user_id, 'NP Demo Owner', '0800000000', 'seller')
  on conflict (id) do update set
    display_name = excluded.display_name,
    phone = excluded.phone,
    role = excluded.role,
    updated_at = now();

  insert into public.admin_accounts (user_id, display_name, role, is_active)
  values (demo_user_id, 'Owner Admin', 'super_admin', true)
  on conflict (user_id) do update set
    display_name = excluded.display_name,
    role = 'super_admin',
    is_active = true,
    expires_at = null,
    updated_at = now();

  insert into public.categories (name, sort_order) values
    ('แฟชั่น', 1),
    ('กระเป๋า', 2),
    ('ของใช้ในบ้าน', 3),
    ('ความงาม', 4)
  on conflict (name) do update set sort_order = excluded.sort_order;

  select id into fashion_id from public.categories where name = 'แฟชั่น';
  select id into bag_id from public.categories where name = 'กระเป๋า';
  select id into home_id from public.categories where name = 'ของใช้ในบ้าน';
  select id into beauty_id from public.categories where name = 'ความงาม';
  select id into carrier_flash_id from public.carriers where code = 'flash';
  select id into carrier_jnt_id from public.carriers where code = 'jnt';

  insert into public.shops (
    id, owner_id, name, category, description, logo_url, phone,
    pickup_address, pickup_province, rating, response_rate, status, review_note
  ) values
    (
      '00000000-0000-0000-0000-000000000101',
      demo_user_id,
      'NP Basics Store',
      'แฟชั่น',
      'ร้านสินค้าพื้นฐานสำหรับทดสอบระบบ NP Market',
      'https://images.unsplash.com/photo-1523381294911-8d3cead13475?w=400',
      '0800000001',
      'โกดัง NP Market demo',
      'ขอนแก่น',
      4.8,
      98,
      'active',
      ''
    ),
    (
      '00000000-0000-0000-0000-000000000102',
      demo_user_id,
      'Daily Bag Studio',
      'กระเป๋า',
      'ร้านกระเป๋าทดสอบสำหรับคิวอนุมัติ',
      'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=400',
      '0800000002',
      'อาคารคลังสินค้าเดโม',
      'กรุงเทพมหานคร',
      4.6,
      95,
      'pending_review',
      'ขอแก้ไขข้อมูลบัญชีรับเงิน รอตรวจเอกสาร'
    ),
    (
      '00000000-0000-0000-0000-000000000103',
      demo_user_id,
      'Home Everyday',
      'ของใช้ในบ้าน',
      'ของใช้บ้านราคาดีสำหรับทดสอบหน้าแอดมิน',
      'https://images.unsplash.com/photo-1556228453-efd6c1ff04f6?w=400',
      '0800000003',
      'คลังสินค้าโฮมเดโม',
      'เชียงใหม่',
      4.7,
      96,
      'paused',
      'ต้องแก้ไขรูปเอกสารร้าน'
    )
  on conflict (id) do update set
    name = excluded.name,
    category = excluded.category,
    description = excluded.description,
    logo_url = excluded.logo_url,
    phone = excluded.phone,
    pickup_address = excluded.pickup_address,
    pickup_province = excluded.pickup_province,
    rating = excluded.rating,
    response_rate = excluded.response_rate,
    status = excluded.status,
    review_note = excluded.review_note,
    updated_at = now();

  insert into public.shop_carriers (shop_id, carrier_id, is_enabled)
  values
    ('00000000-0000-0000-0000-000000000101', carrier_flash_id, true),
    ('00000000-0000-0000-0000-000000000101', carrier_jnt_id, true),
    ('00000000-0000-0000-0000-000000000102', carrier_flash_id, true),
    ('00000000-0000-0000-0000-000000000103', carrier_jnt_id, true)
  on conflict (shop_id, carrier_id) do update set is_enabled = excluded.is_enabled;

  insert into public.shop_documents (id, shop_id, type, file_url, file_path, status, note, uploaded_by)
  values
    ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000102', 'identity_card', 'https://example.com/demo/identity-card.jpg', 'demo/identity-card.jpg', 'pending_review', 'รอตรวจความชัดของรูป', demo_user_id),
    ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000102', 'bank_book', 'https://example.com/demo/bank-book.jpg', 'demo/bank-book.jpg', 'needs_fix', 'เลขบัญชีไม่ชัด', demo_user_id),
    ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000103', 'identity_card', 'https://example.com/demo/home-identity-card.jpg', 'demo/home-identity-card.jpg', 'needs_fix', 'รูปเอกสารเอียงเกินไป', demo_user_id)
  on conflict (id) do update set
    status = excluded.status,
    note = excluded.note,
    updated_at = now();

  insert into public.products (
    id, shop_id, category_id, name, description, sku, price, original_price,
    stock, weight_kg, parcel_size, ship_from_province, badge, status, sold_count, rating
  ) values
    ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000101', fashion_id, 'เสื้อยืด Cotton Oversize NP', 'ผ้านุ่ม ใส่ง่าย เหมาะกับทุกวัน', 'NP-TEE-001', 199, 299, 120, 0.25, '25x20x3 ซม.', 'ขอนแก่น', 'ขายดี', 'active', 349, 4.8),
    ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000102', bag_id, 'กระเป๋าสะพาย Daily Mini', 'กระเป๋าขนาดกะทัดรัดสำหรับใช้งานประจำวัน', 'BAG-MINI-001', 259, 399, 80, 0.45, '30x20x8 ซม.', 'กรุงเทพมหานคร', 'ลดพิเศษ', 'active', 182, 4.7),
    ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000103', home_id, 'แก้วน้ำเก็บอุณหภูมิ Home Everyday', 'แก้วสแตนเลสเก็บเย็นสำหรับพกพา', 'HOME-CUP-001', 149, 219, 60, 0.35, '10x10x22 ซม.', 'เชียงใหม่', 'ส่งฟรี', 'active', 91, 4.6),
    ('00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-000000000101', beauty_id, 'เซ็ตแปรงแต่งหน้า Soft Touch', 'ชุดแปรงสำหรับเริ่มต้น ใช้งานง่าย', 'BEAUTY-BRUSH-001', 179, 249, 40, 0.2, '18x12x4 ซม.', 'ขอนแก่น', 'ใหม่', 'active', 64, 4.5)
  on conflict (id) do update set
    category_id = excluded.category_id,
    name = excluded.name,
    description = excluded.description,
    sku = excluded.sku,
    price = excluded.price,
    original_price = excluded.original_price,
    stock = excluded.stock,
    weight_kg = excluded.weight_kg,
    parcel_size = excluded.parcel_size,
    ship_from_province = excluded.ship_from_province,
    badge = excluded.badge,
    status = excluded.status,
    sold_count = excluded.sold_count,
    rating = excluded.rating,
    updated_at = now();

  insert into public.product_media (id, product_id, type, url, sort_order)
  values
    ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000201', 'image', 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=900', 0),
    ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000202', 'image', 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=900', 0),
    ('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000203', 'image', 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=900', 0),
    ('00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-000000000204', 'image', 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=900', 0)
  on conflict (id) do update set
    url = excluded.url,
    sort_order = excluded.sort_order;

  insert into public.product_variants (id, product_id, color, size, sku, price, stock, is_active)
  values
    ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000201', 'ขาว', 'M', 'NP-TEE-001-W-M', 199, 40, true),
    ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000201', 'ดำ', 'L', 'NP-TEE-001-B-L', 199, 35, true),
    ('00000000-0000-0000-0000-000000000503', '00000000-0000-0000-0000-000000000202', 'ครีม', 'Free Size', 'BAG-MINI-001-CR', 259, 38, true),
    ('00000000-0000-0000-0000-000000000504', '00000000-0000-0000-0000-000000000203', 'ชมพู', '600 ml', 'HOME-CUP-001-PK', 149, 25, true)
  on conflict (id) do update set
    price = excluded.price,
    stock = excluded.stock,
    is_active = excluded.is_active;

  insert into public.addresses (id, user_id, recipient_name, phone, detail, province, district, sub_district, postcode, label, is_default)
  values
    ('00000000-0000-0000-0000-000000000601', demo_user_id, 'NP Demo Buyer', '0800000000', '789 หมู่ 5', 'ขอนแก่น', 'เมืองขอนแก่น', 'พระลับ', '40000', 'บ้าน', true)
  on conflict (id) do update set
    recipient_name = excluded.recipient_name,
    phone = excluded.phone,
    detail = excluded.detail,
    province = excluded.province,
    district = excluded.district,
    sub_district = excluded.sub_district,
    postcode = excluded.postcode,
    is_default = excluded.is_default,
    updated_at = now();

  insert into public.orders (
    id, order_no, buyer_id, shop_id, address_id, shipping_address, status,
    payment_method, subtotal, shipping_fee, discount, grand_total, note
  ) values
    (
      '00000000-0000-0000-0000-000000000701',
      'NP-DEMO-1001',
      demo_user_id,
      '00000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000601',
      '{"recipient":"NP Demo Buyer","phone":"0800000000","address":"789 หมู่ 5 พระลับ เมืองขอนแก่น ขอนแก่น 40000"}',
      'seller_confirming',
      'cod',
      398,
      0,
      0,
      398,
      'ออเดอร์ตัวอย่างจาก seed'
    ),
    (
      '00000000-0000-0000-0000-000000000702',
      'NP-DEMO-1002',
      demo_user_id,
      '00000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000000601',
      '{"recipient":"NP Demo Buyer","phone":"0800000000","address":"789 หมู่ 5 พระลับ เมืองขอนแก่น ขอนแก่น 40000"}',
      'awaiting_shipment',
      'promptpay_qr',
      259,
      35,
      0,
      294,
      'ชำระแล้ว รอร้านจัดส่ง'
    ),
    (
      '00000000-0000-0000-0000-000000000703',
      'NP-DEMO-1003',
      demo_user_id,
      '00000000-0000-0000-0000-000000000103',
      '00000000-0000-0000-0000-000000000601',
      '{"recipient":"NP Demo Buyer","phone":"0800000000","address":"789 หมู่ 5 พระลับ เมืองขอนแก่น ขอนแก่น 40000"}',
      'return_refund',
      'mobile_banking',
      149,
      35,
      0,
      184,
      'ลูกค้าขอคืนสินค้า'
    )
  on conflict (id) do update set
    status = excluded.status,
    payment_method = excluded.payment_method,
    subtotal = excluded.subtotal,
    shipping_fee = excluded.shipping_fee,
    discount = excluded.discount,
    grand_total = excluded.grand_total,
    note = excluded.note,
    updated_at = now();

  insert into public.order_items (id, order_id, product_id, product_snapshot, quantity, unit_price, total_price)
  values
    ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000201', '{"id":"00000000-0000-0000-0000-000000000201","name":"เสื้อยืด Cotton Oversize NP","shopName":"NP Basics Store","category":"แฟชั่น","imageUrl":"https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=900"}', 2, 199, 398),
    ('00000000-0000-0000-0000-000000000802', '00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000202', '{"id":"00000000-0000-0000-0000-000000000202","name":"กระเป๋าสะพาย Daily Mini","shopName":"Daily Bag Studio","category":"กระเป๋า","imageUrl":"https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=900"}', 1, 259, 259),
    ('00000000-0000-0000-0000-000000000803', '00000000-0000-0000-0000-000000000703', '00000000-0000-0000-0000-000000000203', '{"id":"00000000-0000-0000-0000-000000000203","name":"แก้วน้ำเก็บอุณหภูมิ Home Everyday","shopName":"Home Everyday","category":"ของใช้ในบ้าน","imageUrl":"https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=900"}', 1, 149, 149)
  on conflict (id) do update set
    product_snapshot = excluded.product_snapshot,
    quantity = excluded.quantity,
    unit_price = excluded.unit_price,
    total_price = excluded.total_price;

  insert into public.order_shipments (id, order_id, carrier_id, carrier_name, tracking_number, shipped_at)
  values
    ('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000702', carrier_flash_id, 'Flash Express', 'FLASH-DEMO-1002', now()),
    ('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-000000000703', carrier_jnt_id, 'J&T Express', 'JNT-DEMO-1003', now() - interval '2 days')
  on conflict (id) do update set
    carrier_id = excluded.carrier_id,
    carrier_name = excluded.carrier_name,
    tracking_number = excluded.tracking_number,
    shipped_at = excluded.shipped_at,
    updated_at = now();

  insert into public.payments (id, order_id, method, status, amount, provider, provider_ref, paid_at)
  values
    ('00000000-0000-0000-0000-000000001001', '00000000-0000-0000-0000-000000000701', 'cod', 'pending', 398, 'cash_on_delivery', 'COD-DEMO-1001', null),
    ('00000000-0000-0000-0000-000000001002', '00000000-0000-0000-0000-000000000702', 'promptpay_qr', 'paid', 294, 'promptpay', 'QR-DEMO-1002', now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000001003', '00000000-0000-0000-0000-000000000703', 'mobile_banking', 'paid', 184, 'bank_transfer', 'BANK-DEMO-1003', now() - interval '3 days')
  on conflict (id) do update set
    status = excluded.status,
    amount = excluded.amount,
    provider_ref = excluded.provider_ref,
    paid_at = excluded.paid_at,
    updated_at = now();

  insert into public.refunds (id, order_id, payment_id, status, reason, amount, requested_by)
  values
    ('00000000-0000-0000-0000-000000001101', '00000000-0000-0000-0000-000000000703', '00000000-0000-0000-0000-000000001003', 'reviewing', 'สินค้าไม่ตรงรายละเอียด', 184, demo_user_id)
  on conflict (id) do update set
    status = excluded.status,
    reason = excluded.reason,
    amount = excluded.amount,
    updated_at = now();

  insert into public.payouts (id, shop_id, status, gross_amount, fee_amount, net_amount, bank_snapshot)
  values
    ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000000101', 'pending', 398, 19.90, 378.10, '{"bank":"Demo Bank","account_last4":"1234"}')
  on conflict (id) do update set
    status = excluded.status,
    gross_amount = excluded.gross_amount,
    fee_amount = excluded.fee_amount,
    net_amount = excluded.net_amount,
    updated_at = now();

  insert into public.reports (id, reporter_id, target_type, target_id, subject, detail, status)
  values
    ('00000000-0000-0000-0000-000000001301', demo_user_id, 'order', '00000000-0000-0000-0000-000000000703', 'ขอคืนสินค้า', 'ลูกค้าแจ้งว่าสินค้าไม่ตรงรายละเอียด', 'reviewing'),
    ('00000000-0000-0000-0000-000000001302', demo_user_id, 'shop', '00000000-0000-0000-0000-000000000103', 'เอกสารร้านต้องตรวจซ้ำ', 'รูปเอกสารไม่ชัดเจน', 'pending')
  on conflict (id) do update set
    subject = excluded.subject,
    detail = excluded.detail,
    status = excluded.status,
    updated_at = now();

  insert into public.banners (id, title, image_url, link_url, placement, sort_order, is_active)
  values
    ('00000000-0000-0000-0000-000000001401', 'NP Market Demo Sale', 'https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=1400', '/campaign/demo-sale', 'home', 1, true)
  on conflict (id) do update set
    title = excluded.title,
    image_url = excluded.image_url,
    link_url = excluded.link_url,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now();
end $$;
