export type AdminRole =
  | 'super_admin'
  | 'shop_approver'
  | 'order_admin'
  | 'content_admin'
  | 'support_admin';

export type AdminAccount = {
  id: string;
  username: string;
  password: string;
  name: string;
  role: AdminRole;
  active: boolean;
  expiresAt: string;
  lastLogin: string;
};

export type ShopStatus = 'รอตรวจสอบ' | 'เปิดขาย' | 'ขอแก้ไขข้อมูล' | 'ระงับร้าน';
export type DocumentStatus = 'ครบถ้วน' | 'รอตรวจ' | 'ต้องแก้ไข';
export type ProductStatus = 'กำลังขาย' | 'รอตรวจ' | 'ปิดขาย' | 'ถูกรายงาน' | 'หมดสต๊อก';
export type OrderStatus = 'รอชำระเงิน' | 'รอร้านยืนยัน' | 'รอจัดส่ง' | 'กำลังจัดส่ง' | 'สำเร็จ' | 'ยกเลิก' | 'คืนสินค้า/คืนเงิน';
export type UserStatus = 'ใช้งานอยู่' | 'รอตรวจสอบ' | 'ระงับชั่วคราว';

export type ShopDocument = {
  type: 'สำเนาบัตรประชาชน' | 'หน้าสมุดบัญชี';
  fileName: string;
  uploadedAt: string;
  status: DocumentStatus;
  note: string;
};

export type ShopRecord = {
  id: string;
  shopName: string;
  owner: string;
  category: string;
  province: string;
  phone: string;
  submittedAt: string;
  products: number;
  rating: number;
  orders: number;
  status: ShopStatus;
  documentStatus: DocumentStatus;
  identityLast4: string;
  bankName: string;
  bankAccountLast4: string;
  documents: ShopDocument[];
};

export type ProductRecord = {
  id: string;
  name: string;
  shop: string;
  category: string;
  price: number;
  stock: number;
  sold: number;
  media: string;
  status: ProductStatus;
};

export type OrderRecord = {
  id: string;
  shop: string;
  buyer: string;
  product: string;
  amount: number;
  payment: string;
  carrier: string;
  trackingNo: string;
  status: OrderStatus;
};

export type CarrierRecord = {
  name: string;
  active: boolean;
  baseFee: number;
  sla: string;
  pendingTracking: number;
  delayedOrders: number;
};

export type UserAccount = {
  id: string;
  name: string;
  role: 'ลูกค้า' | 'ผู้ขาย';
  phone: string;
  email: string;
  status: UserStatus;
  orders: number;
};

export type PromotionRecord = {
  id: string;
  name: string;
  type: 'คูปองร้านค้า' | 'คูปองแพลตฟอร์ม' | 'ส่งฟรี' | 'Flash Sale' | 'แบนเนอร์';
  period: string;
  budget: number;
  status: 'เปิดใช้งาน' | 'รอเริ่ม' | 'ปิดใช้งาน';
};

export type VideoRecord = {
  id: string;
  title: string;
  shop: string;
  product: string;
  views: string;
  status: 'รอตรวจ' | 'แสดงผล' | 'ถูกรายงาน' | 'ปิดแสดงผล';
};

export type ReportRecord = {
  id: string;
  type: 'รีวิวสินค้า' | 'รีวิวร้านค้า' | 'รายงานสินค้า' | 'รายงานร้านค้า' | 'คืนสินค้า/คืนเงิน';
  subject: string;
  reporter: string;
  status: 'รอตรวจ' | 'กำลังจัดการ' | 'ปิดเรื่องแล้ว';
};

export const adminAccounts: AdminAccount[] = [
  {
    id: 'A-001',
    username: 'superadmin',
    password: 'admin1234',
    name: 'Super Admin',
    role: 'super_admin',
    active: true,
    expiresAt: '2027-12-31',
    lastLogin: 'วันนี้ 09:10'
  },
  {
    id: 'A-002',
    username: 'shop.approver',
    password: 'admin1234',
    name: 'Shop Approver',
    role: 'shop_approver',
    active: true,
    expiresAt: '2027-06-30',
    lastLogin: 'วันนี้ 08:42'
  },
  {
    id: 'A-003',
    username: 'order.admin',
    password: 'admin1234',
    name: 'Order Admin',
    role: 'order_admin',
    active: true,
    expiresAt: '2027-06-30',
    lastLogin: 'เมื่อวาน 17:22'
  }
];

export const shops: ShopRecord[] = [
  {
    id: 'SHOP-1001',
    shopName: 'NP Basics Store',
    owner: 'พงศธร ทวีคูล',
    category: 'แฟชั่น',
    province: 'ขอนแก่น',
    phone: '088 576 9845',
    submittedAt: 'วันนี้ 09:24',
    products: 18,
    rating: 4.9,
    orders: 128,
    status: 'รอตรวจสอบ',
    documentStatus: 'รอตรวจ',
    identityLast4: '9845',
    bankName: 'กสิกรไทย',
    bankAccountLast4: '2219',
    documents: [
      {
        type: 'สำเนาบัตรประชาชน',
        fileName: 'id-card-np-basics.jpg',
        uploadedAt: 'วันนี้ 09:21',
        status: 'รอตรวจ',
        note: 'ต้องเทียบชื่อเจ้าของร้านกับบัญชีรับเงิน'
      },
      {
        type: 'หน้าสมุดบัญชี',
        fileName: 'bank-book-np-basics.jpg',
        uploadedAt: 'วันนี้ 09:22',
        status: 'รอตรวจ',
        note: 'บัญชีรับเงินต้องเป็นชื่อเดียวกับผู้ขอเปิดร้าน'
      }
    ]
  },
  {
    id: 'SHOP-1002',
    shopName: 'Daily Bag Studio',
    owner: 'มุก',
    category: 'กระเป๋า',
    province: 'กรุงเทพมหานคร',
    phone: '091 865 5919',
    submittedAt: 'วันนี้ 10:18',
    products: 8,
    rating: 4.7,
    orders: 86,
    status: 'เปิดขาย',
    documentStatus: 'ครบถ้วน',
    identityLast4: '5919',
    bankName: 'ไทยพาณิชย์',
    bankAccountLast4: '7781',
    documents: [
      {
        type: 'สำเนาบัตรประชาชน',
        fileName: 'id-card-daily-bag.jpg',
        uploadedAt: 'วันนี้ 10:11',
        status: 'ครบถ้วน',
        note: 'ภาพชัดเจน ชื่อตรงกับผู้ขาย'
      },
      {
        type: 'หน้าสมุดบัญชี',
        fileName: 'bank-book-daily-bag.jpg',
        uploadedAt: 'วันนี้ 10:12',
        status: 'ครบถ้วน',
        note: 'เลขบัญชีและชื่อบัญชีตรวจแล้ว'
      }
    ]
  },
  {
    id: 'SHOP-1003',
    shopName: 'Home Everyday',
    owner: 'ทีมสินค้าไลฟ์สไตล์',
    category: 'ของใช้บ้าน',
    province: 'เชียงใหม่',
    phone: '082 111 2020',
    submittedAt: 'เมื่อวาน 18:03',
    products: 24,
    rating: 4.6,
    orders: 73,
    status: 'ขอแก้ไขข้อมูล',
    documentStatus: 'ต้องแก้ไข',
    identityLast4: '2020',
    bankName: 'กรุงไทย',
    bankAccountLast4: '5100',
    documents: [
      {
        type: 'สำเนาบัตรประชาชน',
        fileName: 'id-card-home-everyday.jpg',
        uploadedAt: 'เมื่อวาน 18:00',
        status: 'ต้องแก้ไข',
        note: 'ภาพไม่ชัด มุมบัตรถูกตัด ต้องอัปโหลดใหม่'
      },
      {
        type: 'หน้าสมุดบัญชี',
        fileName: 'bank-book-home-everyday.jpg',
        uploadedAt: 'เมื่อวาน 18:01',
        status: 'ครบถ้วน',
        note: 'หน้าสมุดบัญชีอ่านได้ชัดเจน'
      }
    ]
  }
];

export const products: ProductRecord[] = [
  { id: 'P-001', name: 'เสื้อยืดคอตตอนพรีเมียม ใส่สบาย', shop: 'NP Basics Store', category: 'แฟชั่น', price: 199, stock: 120, sold: 1200, media: 'รูปภาพ 5 / วิดีโอ 1', status: 'กำลังขาย' },
  { id: 'P-002', name: 'กระเป๋าสะพายมินิมอล ใช้ได้ทุกวัน', shop: 'Daily Bag Studio', category: 'กระเป๋า', price: 359, stock: 86, sold: 802, media: 'รูปภาพ 13 / วิดีโอ 1', status: 'รอตรวจ' },
  { id: 'P-003', name: 'แก้วเก็บอุณหภูมิ 600ml พร้อมฝาปิด', shop: 'Home Everyday', category: 'ของใช้บ้าน', price: 249, stock: 0, sold: 368, media: 'รูปภาพ 4', status: 'หมดสต๊อก' },
  { id: 'P-004', name: 'หูฟังไร้สายพร้อมเคสชาร์จ', shop: 'Tech Corner', category: 'อุปกรณ์ดิจิทัล', price: 690, stock: 34, sold: 521, media: 'รูปภาพ 6 / วิดีโอ 2', status: 'ถูกรายงาน' }
];

export const orders: OrderRecord[] = [
  { id: 'NP20260809001', shop: 'NP Basics Store', buyer: 'พงศกร', product: 'เสื้อยืดคอตตอนพรีเมียม', amount: 199, payment: 'เก็บเงินปลายทาง', carrier: 'Flash Express', trackingNo: '-', status: 'รอร้านยืนยัน' },
  { id: 'NP20260809002', shop: 'Daily Bag Studio', buyer: 'มุก', product: 'กระเป๋าสะพายมินิมอล', amount: 359, payment: 'QR พร้อมเพย์', carrier: 'J&T Express', trackingNo: 'JT123456789TH', status: 'กำลังจัดส่ง' },
  { id: 'NP20260809003', shop: 'Home Everyday', buyer: 'กานต์', product: 'แก้วเก็บอุณหภูมิ', amount: 249, payment: 'Mobile Banking', carrier: 'KEX', trackingNo: 'KEX987654321', status: 'รอจัดส่ง' },
  { id: 'NP20260809004', shop: 'Tech Corner', buyer: 'ลูกค้า NP', product: 'หูฟังไร้สาย', amount: 690, payment: 'เก็บเงินปลายทาง', carrier: 'ไปรษณีย์ไทย', trackingNo: 'THP1122334455', status: 'สำเร็จ' }
];

export const carriers: CarrierRecord[] = [
  { name: 'Flash Express', active: true, baseFee: 38, sla: '1-3 วัน', pendingTracking: 4, delayedOrders: 1 },
  { name: 'KEX', active: true, baseFee: 42, sla: '1-3 วัน', pendingTracking: 2, delayedOrders: 0 },
  { name: 'Express', active: true, baseFee: 35, sla: '2-4 วัน', pendingTracking: 5, delayedOrders: 2 },
  { name: 'ไปรษณีย์ไทย', active: true, baseFee: 32, sla: '2-5 วัน', pendingTracking: 1, delayedOrders: 0 },
  { name: 'J&T Express', active: true, baseFee: 36, sla: '1-3 วัน', pendingTracking: 3, delayedOrders: 1 }
];

export const users: UserAccount[] = [
  { id: 'U-1001', name: 'ผู้ใช้ NP Market', role: 'ลูกค้า', phone: '098 765 4321', email: 'buyer@npmarket.local', status: 'ใช้งานอยู่', orders: 7 },
  { id: 'U-1002', name: 'NP Basics Store', role: 'ผู้ขาย', phone: '088 576 9845', email: 'seller.basics@npmarket.local', status: 'ใช้งานอยู่', orders: 42 },
  { id: 'U-1003', name: 'Daily Bag Studio', role: 'ผู้ขาย', phone: '091 865 5919', email: 'dailybag@npmarket.local', status: 'รอตรวจสอบ', orders: 12 },
  { id: 'U-1004', name: 'Tech Corner', role: 'ผู้ขาย', phone: '082 444 9911', email: 'tech@npmarket.local', status: 'ระงับชั่วคราว', orders: 3 }
];

export const promotions: PromotionRecord[] = [
  { id: 'PR-001', name: 'NP DEAL ลดแรงทั้งร้าน', type: 'คูปองแพลตฟอร์ม', period: '9 ส.ค. - 15 ส.ค.', budget: 12000, status: 'เปิดใช้งาน' },
  { id: 'PR-002', name: 'ส่งฟรีร้านโค้ดคืน', type: 'ส่งฟรี', period: 'ทั้งเดือน', budget: 8500, status: 'เปิดใช้งาน' },
  { id: 'PR-003', name: '8.8 Flash Sale', type: 'Flash Sale', period: '8 ส.ค.', budget: 24000, status: 'ปิดใช้งาน' },
  { id: 'PR-004', name: 'แบนเนอร์หน้าแรก', type: 'แบนเนอร์', period: 'รอเริ่ม', budget: 0, status: 'รอเริ่ม' }
];

export const videos: VideoRecord[] = [
  { id: 'V-001', title: 'รีวิวกระเป๋าสะพายมินิมอล', shop: 'Daily Bag Studio', product: 'กระเป๋าสะพายมินิมอล', views: '12.8k', status: 'แสดงผล' },
  { id: 'V-002', title: 'ทดสอบหูฟังไร้สาย', shop: 'Tech Corner', product: 'หูฟังไร้สาย', views: '8.4k', status: 'ถูกรายงาน' },
  { id: 'V-003', title: 'เสื้อยืดใส่ได้ทุกวัน', shop: 'NP Basics Store', product: 'เสื้อยืดคอตตอน', views: '3.1k', status: 'รอตรวจ' }
];

export const reports: ReportRecord[] = [
  { id: 'R-001', type: 'รายงานสินค้า', subject: 'สินค้าไม่ตรงรูป', reporter: 'ลูกค้า U-1001', status: 'รอตรวจ' },
  { id: 'R-002', type: 'คืนสินค้า/คืนเงิน', subject: 'ได้รับของเสียหาย', reporter: 'ลูกค้า U-1005', status: 'กำลังจัดการ' },
  { id: 'R-003', type: 'รีวิวร้านค้า', subject: 'รีวิวกล่าวหาโกง', reporter: 'Daily Bag Studio', status: 'รอตรวจ' }
];
