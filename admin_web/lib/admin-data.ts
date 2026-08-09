import { supabase } from './supabase';

export type AdminRole =
  | 'super_admin'
  | 'shop_approver'
  | 'order_admin'
  | 'content_admin'
  | 'support_admin';

export type AdminAccount = {
  id: string;
  user_id: string;
  display_name: string;
  role: AdminRole;
  is_active: boolean;
  expires_at: string | null;
};

export type ShopStatus = 'draft' | 'pending_review' | 'active' | 'paused' | 'suspended';
export type ProductStatus = 'draft' | 'active' | 'sold_out' | 'hidden' | 'suspended';
export type OrderStatus =
  | 'pending_payment'
  | 'seller_confirming'
  | 'awaiting_shipment'
  | 'packed'
  | 'shipped'
  | 'in_transit'
  | 'delivered'
  | 'completed'
  | 'cancelled'
  | 'return_refund';

export type ShopRow = {
  id: string;
  name: string;
  category: string;
  phone: string;
  pickup_province: string;
  rating: number;
  status: ShopStatus;
  review_note: string;
  created_at: string;
  profiles?: { display_name: string; phone: string } | null;
  shop_documents?: Array<{ id: string; type: string; status: string; file_url: string; note: string }>;
};

export type ProductRow = {
  id: string;
  shop_id: string;
  category_id: string | null;
  name: string;
  sku: string;
  price: number;
  original_price: number;
  stock: number;
  status: ProductStatus;
  sold_count: number;
  rating: number;
  created_at: string;
  shops?: { name: string } | null;
  product_media?: Array<{ id: string; url: string; sort_order: number }>;
};

export type OrderRow = {
  id: string;
  order_no: string;
  shop_id: string | null;
  status: OrderStatus;
  payment_method: string;
  grand_total: number;
  created_at: string;
  shops?: { name: string } | null;
  profiles?: { display_name: string; phone: string } | null;
  order_shipments?: Array<{ carrier_name: string; tracking_number: string }>;
};

export type CategoryRow = {
  id: string;
  name: string;
};

export type ProductDraft = {
  shop_id: string;
  category_id: string | null;
  name: string;
  sku: string;
  price: number;
  original_price: number;
  stock: number;
  status: ProductStatus;
};

function firstRelation<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

export async function getCurrentAdmin(): Promise<AdminAccount | null> {
  const { data: userResult, error: userError } = await supabase.auth.getUser();
  if (userError || !userResult.user) return null;

  const { data, error } = await supabase
    .from('admin_accounts')
    .select('id,user_id,display_name,role,is_active,expires_at')
    .eq('user_id', userResult.user.id)
    .maybeSingle();

  if (error) throw error;
  if (!data || !data.is_active) return null;
  if (data.expires_at && new Date(data.expires_at) <= new Date()) return null;
  return data as AdminAccount;
}

export async function signInAdmin(email: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return getCurrentAdmin();
}

export async function signOutAdmin() {
  await supabase.auth.signOut();
}

export async function fetchAdminDashboard() {
  const [shops, products, orders, categories] = await Promise.all([
    supabase
      .from('shops')
      .select('id,name,category,phone,pickup_province,rating,status,review_note,created_at,profiles(display_name,phone),shop_documents(id,type,status,file_url,note)')
      .order('created_at', { ascending: false })
      .limit(100),
    supabase
      .from('products')
      .select('id,shop_id,category_id,name,sku,price,original_price,stock,status,sold_count,rating,created_at,shops(name),product_media(id,url,sort_order)')
      .order('created_at', { ascending: false })
      .limit(100),
    supabase
      .from('orders')
      .select('id,order_no,shop_id,status,payment_method,grand_total,created_at,shops(name),profiles(display_name,phone),order_shipments(carrier_name,tracking_number)')
      .order('created_at', { ascending: false })
      .limit(100),
    supabase.from('categories').select('id,name').order('sort_order', { ascending: true })
  ]);

  for (const result of [shops, products, orders, categories]) {
    if (result.error) throw result.error;
  }

  return {
    shops: ((shops.data ?? []) as Array<ShopRow & { profiles?: ShopRow['profiles'] | ShopRow['profiles'][] }>).map((shop) => ({
      ...shop,
      profiles: firstRelation(shop.profiles)
    })),
    products: ((products.data ?? []) as Array<ProductRow & { shops?: ProductRow['shops'] | ProductRow['shops'][] }>).map((product) => ({
      ...product,
      shops: firstRelation(product.shops)
    })),
    orders: ((orders.data ?? []) as Array<OrderRow & { shops?: OrderRow['shops'] | OrderRow['shops'][]; profiles?: OrderRow['profiles'] | OrderRow['profiles'][] }>).map((order) => ({
      ...order,
      shops: firstRelation(order.shops),
      profiles: firstRelation(order.profiles)
    })),
    categories: (categories.data ?? []) as CategoryRow[]
  };
}

export async function updateShopReview(id: string, status: ShopStatus, reviewNote = '') {
  const { error } = await supabase
    .from('shops')
    .update({
      status,
      review_note: reviewNote,
      approved_at: status === 'active' ? new Date().toISOString() : null
    })
    .eq('id', id);
  if (error) throw error;
}

export async function createProduct(draft: ProductDraft) {
  const { data, error } = await supabase
    .from('products')
    .insert({
      shop_id: draft.shop_id,
      category_id: draft.category_id,
      name: draft.name,
      sku: draft.sku,
      price: draft.price,
      original_price: draft.original_price,
      stock: draft.stock,
      status: draft.status
    })
    .select('id')
    .single();

  if (error) throw error;
  return data.id as string;
}

export async function updateProduct(id: string, patch: Partial<ProductDraft>) {
  const { error } = await supabase.from('products').update(patch).eq('id', id);
  if (error) throw error;
}

export async function deleteProduct(id: string) {
  const { error } = await supabase.from('products').delete().eq('id', id);
  if (error) throw error;
}

export async function uploadProductImage(productId: string, file: File) {
  const ext = file.name.split('.').pop() || 'jpg';
  const path = `${productId}/${crypto.randomUUID()}.${ext}`;
  const upload = await supabase.storage.from('product-media').upload(path, file, {
    cacheControl: '3600',
    upsert: false
  });
  if (upload.error) throw upload.error;

  const publicUrl = supabase.storage.from('product-media').getPublicUrl(path).data.publicUrl;
  const { error } = await supabase
    .from('product_media')
    .insert({ product_id: productId, type: 'image', url: publicUrl, sort_order: 0 });
  if (error) throw error;
  return publicUrl;
}

export async function updateOrderStatus(id: string, status: OrderStatus) {
  const { error } = await supabase.from('orders').update({ status }).eq('id', id);
  if (error) throw error;
}
