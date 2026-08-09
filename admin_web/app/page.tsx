'use client';

import { type ReactNode, useEffect, useMemo, useState } from 'react';
import { Badge, Button, Card, Col, Container, Form, Modal, Nav, Row, Table } from 'react-bootstrap';
import {
  type AdminAccount,
  type CategoryRow,
  type OrderRow,
  type OrderStatus,
  type ProductDraft,
  type ProductRow,
  type ProductStatus,
  type ShopRow,
  type ShopStatus,
  createProduct,
  deleteProduct,
  fetchAdminDashboard,
  getCurrentAdmin,
  signInAdmin,
  signOutAdmin,
  updateOrderStatus,
  updateProduct,
  updateShopReview,
  uploadProductImage
} from '../lib/admin-data';
import { isSupabaseConfigured } from '../lib/supabase';

type SectionKey =
  | 'dashboard'
  | 'shops'
  | 'products'
  | 'orders'
  | 'shipping'
  | 'reports'
  | 'finance'
  | 'settings'
  | 'appUsers'
  | 'admins';

const shopStatusLabels: Record<ShopStatus, string> = {
  draft: 'แบบร่าง',
  pending_review: 'รอตรวจสอบ',
  active: 'เปิดขาย',
  paused: 'ขอแก้ไข',
  suspended: 'ระงับร้าน'
};

const productStatusLabels: Record<ProductStatus, string> = {
  draft: 'แบบร่าง',
  active: 'กำลังขาย',
  sold_out: 'หมดสต็อก',
  hidden: 'ซ่อน',
  suspended: 'ระงับสินค้า'
};

const orderStatusLabels: Record<OrderStatus, string> = {
  pending_payment: 'รอชำระเงิน',
  seller_confirming: 'รอร้านยืนยัน',
  awaiting_shipment: 'รอจัดส่ง',
  packed: 'แพ็กแล้ว',
  shipped: 'ส่งแล้ว',
  in_transit: 'กำลังนำส่ง',
  delivered: 'จัดส่งสำเร็จ',
  completed: 'สำเร็จ',
  cancelled: 'ยกเลิก',
  return_refund: 'คืนสินค้า/คืนเงิน'
};

const mainMenus: Array<{ key: SectionKey; label: string; icon: string }> = [
  { key: 'dashboard', label: 'แดชบอร์ด', icon: 'grid' },
  { key: 'shops', label: 'ร้านค้า', icon: 'shop' },
  { key: 'products', label: 'สินค้า', icon: 'box-seam' },
  { key: 'orders', label: 'ออเดอร์', icon: 'receipt' },
  { key: 'shipping', label: 'ขนส่ง', icon: 'truck' },
  { key: 'reports', label: 'รายงาน', icon: 'flag' },
  { key: 'finance', label: 'การเงิน', icon: 'wallet2' },
  { key: 'settings', label: 'ตั้งค่าระบบ', icon: 'sliders' }
];

const userMenus: Array<{ key: SectionKey; label: string; icon: string }> = [
  { key: 'appUsers', label: 'ผู้ใช้ในแอป', icon: 'people' },
  { key: 'admins', label: 'แอดมิน', icon: 'person-gear' }
];

const pageTitles: Record<SectionKey, string> = {
  dashboard: 'แดชบอร์ด',
  shops: 'ร้านค้า',
  products: 'สินค้า',
  orders: 'ออเดอร์',
  shipping: 'ขนส่ง',
  reports: 'รายงาน',
  finance: 'การเงิน',
  settings: 'ตั้งค่าระบบ',
  appUsers: 'ผู้ใช้ในแอป',
  admins: 'แอดมิน'
};

const emptyDraft: ProductDraft = {
  shop_id: '',
  category_id: null,
  name: '',
  sku: '',
  price: 0,
  original_price: 0,
  stock: 0,
  status: 'draft'
};

export default function AdminHome() {
  const [admin, setAdmin] = useState<AdminAccount | null>(null);
  const [section, setSection] = useState<SectionKey>('dashboard');
  const [shops, setShops] = useState<ShopRow[]>([]);
  const [products, setProducts] = useState<ProductRow[]>([]);
  const [orders, setOrders] = useState<OrderRow[]>([]);
  const [categories, setCategories] = useState<CategoryRow[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showProduct, setShowProduct] = useState(false);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const currentAdmin = await getCurrentAdmin();
      setAdmin(currentAdmin);
      if (currentAdmin) {
        const data = await fetchAdminDashboard();
        setShops(data.shops);
        setProducts(data.products);
        setOrders(data.orders);
        setCategories(data.categories);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const normalizedQuery = query.toLowerCase();

  const filteredShops = useMemo(
    () => shops.filter((shop) => [shop.name, shop.category, shop.phone, shop.pickup_province].join(' ').toLowerCase().includes(normalizedQuery)),
    [shops, normalizedQuery]
  );

  const filteredProducts = useMemo(
    () => products.filter((product) => [product.name, product.sku, product.shops?.name].join(' ').toLowerCase().includes(normalizedQuery)),
    [products, normalizedQuery]
  );

  const filteredOrders = useMemo(
    () => orders.filter((order) => [order.order_no, order.shops?.name, order.profiles?.display_name].join(' ').toLowerCase().includes(normalizedQuery)),
    [orders, normalizedQuery]
  );

  if (!admin) {
    return <LoginScreen loading={loading} error={error} onLoggedIn={load} />;
  }

  return (
    <main className="admin-page">
      <Container fluid className="admin-shell">
        <aside className="admin-sidebar">
          <div className="brand-lockup">
            <span className="brand-mark">NP</span>
            <div>
              <strong>NP Admin</strong>
              <small>{formatRole(admin.role)}</small>
            </div>
          </div>

          <Nav className="admin-nav">
            {mainMenus.map((item) => (
              <SidebarButton key={item.key} active={section === item.key} icon={item.icon} label={item.label} onClick={() => setSection(item.key)} />
            ))}

            <div className="nav-group">
              <div className="nav-group-label">
                <i className="bi bi-people" aria-hidden />
                <span>ผู้ใช้</span>
              </div>
              {userMenus.map((item) => (
                <SidebarButton
                  key={item.key}
                  active={section === item.key}
                  className="nav-subpill"
                  icon={item.icon}
                  label={item.label}
                  onClick={() => setSection(item.key)}
                />
              ))}
            </div>
          </Nav>

          <div className="sidebar-footer">
            <button
              className="nav-pill"
              type="button"
              onClick={async () => {
                await signOutAdmin();
                setAdmin(null);
              }}
            >
              <i className="bi bi-box-arrow-left" aria-hidden />
              <span>ออกจากระบบ</span>
            </button>
          </div>
        </aside>

        <section className="admin-workspace">
          <header className="topbar">
            <div>
              <p className="eyebrow">NP MARKET BACK OFFICE</p>
              <h1>{pageTitles[section]}</h1>
              <span>
                {formatRole(admin.role)} · {formatExpiry(admin.expires_at)} · {isSupabaseConfigured ? 'เชื่อม Supabase แล้ว' : 'รอใส่ anon key'}
              </span>
            </div>
            <div className="topbar-actions">
              <Form.Control
                className="search-input"
                placeholder="ค้นหาร้านค้า ผู้ใช้ สินค้า หรือออเดอร์"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
              <button className="icon-button" aria-label="Refresh" type="button" onClick={load}>
                <i className="bi bi-arrow-clockwise" aria-hidden />
              </button>
              <button className="icon-button" aria-label="Notifications" type="button">
                <i className="bi bi-bell" aria-hidden />
              </button>
              <div className="admin-avatar">{(admin.display_name || 'A').charAt(0)}</div>
            </div>
          </header>

          {error && <div className="form-error">{error}</div>}
          {loading && <div className="muted-note">กำลังโหลดข้อมูล...</div>}

          {section === 'dashboard' && (
            <Dashboard
              shops={shops}
              products={products}
              orders={orders}
              onOpenShops={() => setSection('shops')}
              onOpenOrders={() => setSection('orders')}
              onOpenReports={() => setSection('reports')}
            />
          )}
          {section === 'shops' && <ShopManagement shops={filteredShops} onReload={load} />}
          {section === 'products' && (
            <ProductManagement products={filteredProducts} shops={shops} categories={categories} onReload={load} onCreate={() => setShowProduct(true)} />
          )}
          {section === 'orders' && <OrderManagement orders={filteredOrders} onReload={load} />}
          {section === 'shipping' && (
            <Placeholder
              title="ขนส่ง"
              body="จุดถัดไปคือผูก order_shipments, เลขพัสดุ, บริษัทขนส่ง และสถานะจัดส่ง เพื่อให้แอดมินเห็นออเดอร์ที่ล่าช้าหรือมีปัญหาได้ทันที"
            />
          )}
          {section === 'finance' && (
            <Placeholder
              title="การเงินร้านค้า"
              body="โครงตาราง payments, refunds, payouts และ platform_fees พร้อมแล้ว ขั้นต่อไปคือทำหน้าสรุปยอดรอโอน ค่าธรรมเนียม และประวัติคืนเงิน"
            />
          )}
          {section === 'reports' && (
            <Placeholder
              title="รายงานและเคส"
              body="ใช้สำหรับตรวจรายงานร้านค้า สินค้า รีวิว และออเดอร์ พร้อมบันทึกการตัดสินใจลง audit log เพื่อให้ตลาดปลอดภัยและตรวจย้อนหลังได้"
            />
          )}
          {section === 'settings' && (
            <Placeholder
              title="ตั้งค่าระบบ"
              body="ใช้จัดการหมวดหมู่ แบนเนอร์หน้าแรก วิธีชำระเงิน วิธีขนส่ง และกติกาตลาด โดยแยกจากข้อมูลร้านค้าเพื่อไม่ให้หลังบ้านรก"
            />
          )}
          {section === 'appUsers' && (
            <Placeholder
              title="ผู้ใช้ในแอป"
              body="หน้ารวมลูกค้าและเจ้าของร้านจะเชื่อม profiles เพื่อดูสถานะบัญชี เบอร์โทร ร้านที่ผูกอยู่ และความเสี่ยงจากรายงาน"
            />
          )}
          {section === 'admins' && (
            <Placeholder
              title="แอดมิน"
              body="หน้าจัดการสิทธิ์ admin_accounts สำหรับเพิ่มแอดมิน แยกบทบาท และปิดใช้งานบัญชีที่หมดหน้าที่"
            />
          )}
        </section>
      </Container>

      <ProductModal show={showProduct} shops={shops} categories={categories} onHide={() => setShowProduct(false)} onSaved={load} />
    </main>
  );
}

function SidebarButton({
  active,
  className = '',
  icon,
  label,
  onClick
}: {
  active: boolean;
  className?: string;
  icon: string;
  label: string;
  onClick: () => void;
}) {
  return (
    <button className={`nav-pill ${className} ${active ? 'active' : ''}`} onClick={onClick} type="button">
      <i className={`bi bi-${icon}`} aria-hidden />
      <span>{label}</span>
    </button>
  );
}

function LoginScreen({ loading, error, onLoggedIn }: { loading: boolean; error: string; onLoggedIn: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  return (
    <main className="login-page">
      <section className="login-card" aria-label="NP Market admin login">
        <div className="login-mark">
          <span>NP</span>
        </div>
        <p className="login-eyebrow">Admin Control Center</p>
        <h1>NP Market</h1>
        <p className="login-copy">เข้าสู่ระบบหลังบ้านด้วยบัญชี Supabase Auth ที่ถูกเพิ่มในตาราง admin_accounts</p>
        {!isSupabaseConfigured && <div className="form-error">ยังไม่ได้ใส่ NEXT_PUBLIC_SUPABASE_ANON_KEY ใน admin_web/.env.local</div>}
        {error && <div className="form-error">{error}</div>}
        {loginError && <div className="form-error">{loginError}</div>}
        <Form
          onSubmit={async (event) => {
            event.preventDefault();
            setLoginError('');
            try {
              const admin = await signInAdmin(email, password);
              if (!admin) {
                setLoginError('บัญชีนี้ยังไม่ได้รับสิทธิ์แอดมิน หรือถูกปิดใช้งาน');
                return;
              }
              onLoggedIn();
            } catch (err) {
              setLoginError(err instanceof Error ? err.message : 'เข้าสู่ระบบไม่สำเร็จ');
            }
          }}
        >
          <Form.Group className="mb-3">
            <Form.Label>Email</Form.Label>
            <Form.Control value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" placeholder="admin@example.com" />
          </Form.Group>
          <Form.Group className="mb-3">
            <Form.Label>Password</Form.Label>
            <Form.Control type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" />
          </Form.Group>
          <Button className="primary-glow w-100 login-button" disabled={loading || !email || !password || !isSupabaseConfigured} type="submit">
            เข้าสู่ระบบ
          </Button>
        </Form>
      </section>
    </main>
  );
}

function Dashboard({
  shops,
  products,
  orders,
  onOpenShops,
  onOpenOrders,
  onOpenReports
}: {
  shops: ShopRow[];
  products: ProductRow[];
  orders: OrderRow[];
  onOpenShops: () => void;
  onOpenOrders: () => void;
  onOpenReports: () => void;
}) {
  const pendingShops = shops.filter((shop) => shop.status === 'pending_review');
  const activeShops = shops.filter((shop) => shop.status === 'active').length;
  const activeProducts = products.filter((product) => product.status === 'active').length;
  const openOrders = orders.filter((order) => !['completed', 'cancelled'].includes(order.status)).length;
  const problemOrders = orders.filter((order) => ['cancelled', 'return_refund'].includes(order.status)).length;
  const revenue = orders.reduce((sum, order) => sum + Number(order.grand_total || 0), 0);

  return (
    <div className="stacked-page">
      <Row className="g-3">
        <Col xl={7}>
          <Card className="hero-card">
            <Card.Body>
              <div className="hero-copy">
                <Badge bg="light" text="dark">
                  Admin Console
                </Badge>
                <h2>ควบคุมร้านค้า ออเดอร์ ผู้ใช้ และความปลอดภัยของตลาด</h2>
                <p>เห็นงานที่ต้องจัดการวันนี้ก่อนเสมอ: ร้านรออนุมัติ ออเดอร์มีปัญหา รายงานรอตรวจ และการขายที่ต้องติดตาม</p>
                <div className="hero-actions">
                  <Button className="primary-glow" onClick={onOpenShops}>
                    ตรวจร้านรออนุมัติ
                  </Button>
                  <Button variant="outline-light" onClick={onOpenOrders}>
                    ดูออเดอร์วันนี้
                  </Button>
                </div>
              </div>
              <div className="hero-orbit" aria-label={`${pendingShops.length} pending shops`}>
                <div>
                  <span>รออนุมัติ</span>
                  <strong>{pendingShops.length}</strong>
                  <small>ร้านค้า</small>
                </div>
              </div>
            </Card.Body>
          </Card>
        </Col>

        <Col xl={5}>
          <ApprovalQueue shops={pendingShops.length ? pendingShops : shops.slice(0, 3)} onOpenShops={onOpenShops} />
        </Col>
      </Row>

      <Row className="g-3">
        <Col md={6} xl={3}>
          <MetricCard label="ยอดขายวันนี้" value={`฿${revenue.toLocaleString('th-TH')}`} change="+18.4%" icon="graph-up-arrow" />
        </Col>
        <Col md={6} xl={3}>
          <MetricCard label="ร้านค้าเปิดขาย" value={activeShops.toString()} change="ใช้งานอยู่" icon="shop" />
        </Col>
        <Col md={6} xl={3}>
          <MetricCard label="สินค้ากำลังขาย" value={activeProducts.toString()} change="อยู่ในแค็ตตาล็อก" icon="box-seam" />
        </Col>
        <Col md={6} xl={3}>
          <MetricCard label="ออเดอร์มีปัญหา" value={problemOrders.toString()} change="ต้องจัดการ" icon="exclamation-triangle" />
        </Col>
      </Row>

      <Row className="g-3">
        <Col xl={8}>
          <PerformancePanel orders={orders} />
        </Col>
        <Col xl={4}>
          <TodayPanel pendingShops={pendingShops.length} openOrders={openOrders} problemOrders={problemOrders} onOpenShops={onOpenShops} onOpenReports={onOpenReports} />
        </Col>
      </Row>
    </div>
  );
}

function ApprovalQueue({ shops, onOpenShops }: { shops: ShopRow[]; onOpenShops: () => void }) {
  return (
    <Card className="glass-card h-100">
      <Card.Body>
        <div className="section-heading">
          <div>
            <p className="eyebrow">Approval Queue</p>
            <h3>งานด่วนวันนี้</h3>
          </div>
          <Button variant="link" onClick={onOpenShops}>
            ดูทั้งหมด
          </Button>
        </div>
        <div className="queue-list">
          {shops.length ? (
            shops.slice(0, 3).map((shop) => (
              <button className="queue-item" key={shop.id} onClick={onOpenShops} type="button">
                <span className="queue-logo">{initials(shop.name)}</span>
                <span>
                  <strong>{shop.name}</strong>
                  <small>{shop.review_note || `${shopStatusLabels[shop.status]} · ${shop.category || 'รอตรวจข้อมูล'}`}</small>
                </span>
                <i className="bi bi-chevron-right" aria-hidden />
              </button>
            ))
          ) : (
            <div className="muted-note">ยังไม่มีงานค้างในคิวอนุมัติ</div>
          )}
        </div>
      </Card.Body>
    </Card>
  );
}

function MetricCard({ label, value, icon, change }: { label: string; value: string; icon: string; change: string }) {
  return (
    <Card className="metric-card">
      <Card.Body>
        <span className="metric-icon">
          <i className={`bi bi-${icon}`} aria-hidden />
        </span>
        <span>{label}</span>
        <strong>{value}</strong>
        <small>{change}</small>
      </Card.Body>
    </Card>
  );
}

function PerformancePanel({ orders }: { orders: OrderRow[] }) {
  const bars = buildChartBars(orders);

  return (
    <Card className="glass-card">
      <Card.Body>
        <div className="section-heading">
          <div>
            <p className="eyebrow">Commerce Performance</p>
            <h3>ยอดขายและออเดอร์</h3>
          </div>
          <div className="period-tabs" aria-label="Chart period">
            <button type="button">1D</button>
            <button type="button">1W</button>
            <button type="button">1M</button>
            <button className="active" type="button">
              6M
            </button>
          </div>
        </div>
        <div className="chart-line" aria-hidden>
          {bars.map((height, index) => (
            <span key={`${height}-${index}`} style={{ '--bar': `${height}%` } as React.CSSProperties} />
          ))}
        </div>
        <div className="chart-labels">
          <span>ม.ค.</span>
          <span>มี.ค.</span>
          <span>พ.ค.</span>
          <span>ก.ค.</span>
          <span>ก.ย.</span>
          <span>ธ.ค.</span>
        </div>
      </Card.Body>
    </Card>
  );
}

function TodayPanel({
  pendingShops,
  openOrders,
  problemOrders,
  onOpenShops,
  onOpenReports
}: {
  pendingShops: number;
  openOrders: number;
  problemOrders: number;
  onOpenShops: () => void;
  onOpenReports: () => void;
}) {
  return (
    <Card className="glass-card h-100">
      <Card.Body>
        <div className="section-heading">
          <div>
            <p className="eyebrow">Today</p>
            <h3>งานที่ต้องจัดการ</h3>
          </div>
        </div>
        <div className="task-list">
          <TaskRow index={1} title="ตรวจเอกสารร้านใหม่" value={`${pendingShops} ร้าน`} onClick={onOpenShops} />
          <TaskRow index={2} title="ติดตามออเดอร์เปิดอยู่" value={`${openOrders} ออเดอร์`} />
          <TaskRow index={3} title="จัดการเคสมีปัญหา" value={`${problemOrders} เคส`} onClick={onOpenReports} />
        </div>
      </Card.Body>
    </Card>
  );
}

function TaskRow({ index, title, value, onClick }: { index: number; title: string; value: string; onClick?: () => void }) {
  return (
    <button className="task-row" type="button" onClick={onClick}>
      <span>{index}</span>
      <strong>{title}</strong>
      <small>{value}</small>
    </button>
  );
}

function ShopManagement({ shops, onReload }: { shops: ShopRow[]; onReload: () => void }) {
  const [busyId, setBusyId] = useState('');

  const review = async (shop: ShopRow, status: ShopStatus, note = '') => {
    setBusyId(shop.id);
    try {
      await updateShopReview(shop.id, status, note);
      await onReload();
    } finally {
      setBusyId('');
    }
  };

  return (
    <SectionCard title="ร้านค้า" actionLabel={`${shops.length} รายการ`}>
      <AdminTable headers={['ร้าน', 'เจ้าของ', 'เอกสาร', 'สถานะ', 'จัดการ']}>
        {shops.map((shop) => (
          <tr key={shop.id}>
            <td>
              <strong>{shop.name}</strong>
              <small>
                {shop.category} · {shop.pickup_province || '-'}
              </small>
            </td>
            <td>
              {shop.profiles?.display_name || '-'}
              <small>{shop.phone || shop.profiles?.phone || '-'}</small>
            </td>
            <td>
              {shop.shop_documents?.length ?? 0} ไฟล์<small>{shop.review_note || 'ไม่มีหมายเหตุ'}</small>
            </td>
            <td>
              <StatusBadge status={shopStatusLabels[shop.status]} />
            </td>
            <td>
              <div className="row-actions">
                <Button size="sm" className="primary-glow" disabled={busyId === shop.id} onClick={() => review(shop, 'active')}>
                  อนุมัติ
                </Button>
                <Button
                  size="sm"
                  variant="outline-light"
                  disabled={busyId === shop.id}
                  onClick={() => review(shop, 'paused', 'กรุณาแก้ไขข้อมูลหรือเอกสารร้าน')}
                >
                  ขอแก้ไข
                </Button>
                <Button
                  size="sm"
                  variant="outline-light"
                  disabled={busyId === shop.id}
                  onClick={() => review(shop, 'suspended', 'ร้านถูกระงับโดยแอดมิน')}
                >
                  ระงับ
                </Button>
              </div>
            </td>
          </tr>
        ))}
      </AdminTable>
    </SectionCard>
  );
}

function ProductManagement({
  products,
  shops,
  categories,
  onReload,
  onCreate
}: {
  products: ProductRow[];
  shops: ShopRow[];
  categories: CategoryRow[];
  onReload: () => void;
  onCreate: () => void;
}) {
  const [imageProduct, setImageProduct] = useState<ProductRow | null>(null);
  const [file, setFile] = useState<File | null>(null);

  return (
    <>
      <SectionCard title="สินค้า" actionLabel="เพิ่มสินค้า" onAction={onCreate}>
        <AdminTable headers={['สินค้า', 'ร้าน', 'ราคา/สต็อก', 'สถานะ', 'รูป', 'จัดการ']}>
          {products.map((product) => (
            <tr key={product.id}>
              <td>
                <strong>{product.name}</strong>
                <small>SKU: {product.sku || '-'}</small>
              </td>
              <td>{product.shops?.name || shops.find((shop) => shop.id === product.shop_id)?.name || '-'}</td>
              <td>
                ฿{Number(product.price).toLocaleString('th-TH')}
                <small>สต็อก {product.stock}</small>
              </td>
              <td>
                <StatusBadge status={productStatusLabels[product.status]} />
              </td>
              <td>{product.product_media?.[0]?.url ? <a className="document-link" href={product.product_media[0].url} target="_blank">เปิดรูป</a> : '-'}</td>
              <td>
                <div className="row-actions">
                  <Button size="sm" variant="outline-light" onClick={() => updateProduct(product.id, { status: product.status === 'active' ? 'hidden' : 'active' }).then(onReload)}>
                    {product.status === 'active' ? 'ซ่อน' : 'เปิดขาย'}
                  </Button>
                  <Button size="sm" variant="outline-light" onClick={() => setImageProduct(product)}>
                    อัปโหลดรูป
                  </Button>
                  <Button size="sm" variant="outline-light" onClick={() => deleteProduct(product.id).then(onReload)}>
                    ลบ
                  </Button>
                </div>
              </td>
            </tr>
          ))}
        </AdminTable>
      </SectionCard>

      <Modal show={Boolean(imageProduct)} onHide={() => setImageProduct(null)} centered contentClassName="document-modal">
        <Modal.Header closeButton>
          <Modal.Title>อัปโหลดรูปสินค้า</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form.Control
            type="file"
            accept="image/*"
            onChange={(event) => {
              const input = event.currentTarget as HTMLInputElement;
              setFile(input.files?.[0] ?? null);
            }}
          />
        </Modal.Body>
        <Modal.Footer>
          <Button variant="outline-light" onClick={() => setImageProduct(null)}>
            ยกเลิก
          </Button>
          <Button
            className="primary-glow"
            disabled={!file || !imageProduct}
            onClick={async () => {
              if (!file || !imageProduct) return;
              await uploadProductImage(imageProduct.id, file);
              setFile(null);
              setImageProduct(null);
              await onReload();
            }}
          >
            อัปโหลด
          </Button>
        </Modal.Footer>
      </Modal>
    </>
  );
}

function ProductModal({ show, shops, categories, onHide, onSaved }: { show: boolean; shops: ShopRow[]; categories: CategoryRow[]; onHide: () => void; onSaved: () => void }) {
  const [draft, setDraft] = useState<ProductDraft>(emptyDraft);

  useEffect(() => {
    if (show) setDraft({ ...emptyDraft, shop_id: shops[0]?.id ?? '', category_id: categories[0]?.id ?? null });
  }, [show, shops, categories]);

  return (
    <Modal show={show} onHide={onHide} centered size="lg" contentClassName="document-modal">
      <Modal.Header closeButton>
        <Modal.Title>เพิ่มสินค้า</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <Row className="g-3">
          <Col md={6}>
            <Form.Group>
              <Form.Label>ร้านค้า</Form.Label>
              <Form.Select value={draft.shop_id} onChange={(event) => setDraft({ ...draft, shop_id: event.target.value })}>
                {shops.map((shop) => (
                  <option key={shop.id} value={shop.id}>
                    {shop.name}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group>
              <Form.Label>หมวดหมู่</Form.Label>
              <Form.Select value={draft.category_id ?? ''} onChange={(event) => setDraft({ ...draft, category_id: event.target.value || null })}>
                {categories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.name}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
          </Col>
          <Col md={12}>
            <Form.Group>
              <Form.Label>ชื่อสินค้า</Form.Label>
              <Form.Control value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} />
            </Form.Group>
          </Col>
          <Col md={4}>
            <Form.Group>
              <Form.Label>SKU</Form.Label>
              <Form.Control value={draft.sku} onChange={(event) => setDraft({ ...draft, sku: event.target.value })} />
            </Form.Group>
          </Col>
          <Col md={4}>
            <Form.Group>
              <Form.Label>ราคา</Form.Label>
              <Form.Control type="number" min={0} value={draft.price} onChange={(event) => setDraft({ ...draft, price: Number(event.target.value) })} />
            </Form.Group>
          </Col>
          <Col md={4}>
            <Form.Group>
              <Form.Label>ราคาก่อนลด</Form.Label>
              <Form.Control type="number" min={0} value={draft.original_price} onChange={(event) => setDraft({ ...draft, original_price: Number(event.target.value) })} />
            </Form.Group>
          </Col>
          <Col md={4}>
            <Form.Group>
              <Form.Label>สต็อก</Form.Label>
              <Form.Control type="number" min={0} value={draft.stock} onChange={(event) => setDraft({ ...draft, stock: Number(event.target.value) })} />
            </Form.Group>
          </Col>
          <Col md={4}>
            <Form.Group>
              <Form.Label>สถานะ</Form.Label>
              <Form.Select value={draft.status} onChange={(event) => setDraft({ ...draft, status: event.target.value as ProductStatus })}>
                {Object.entries(productStatusLabels).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
          </Col>
        </Row>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="outline-light" onClick={onHide}>
          ยกเลิก
        </Button>
        <Button
          className="primary-glow"
          disabled={!draft.shop_id || !draft.name}
          onClick={async () => {
            await createProduct(draft);
            onHide();
            await onSaved();
          }}
        >
          บันทึกสินค้า
        </Button>
      </Modal.Footer>
    </Modal>
  );
}

function OrderManagement({ orders, onReload }: { orders: OrderRow[]; onReload: () => void }) {
  return (
    <SectionCard title="ออเดอร์" actionLabel={`${orders.length} รายการ`}>
      <AdminTable headers={['ออเดอร์', 'ร้าน/ลูกค้า', 'ยอดรวม', 'ขนส่ง', 'สถานะ']}>
        {orders.map((order) => (
          <tr key={order.id}>
            <td>
              <strong>{order.order_no}</strong>
              <small>{new Date(order.created_at).toLocaleString('th-TH')}</small>
            </td>
            <td>
              {order.shops?.name || '-'}
              <small>{order.profiles?.display_name || '-'}</small>
            </td>
            <td>
              ฿{Number(order.grand_total).toLocaleString('th-TH')}
              <small>{order.payment_method}</small>
            </td>
            <td>
              {order.order_shipments?.[0]?.carrier_name || '-'}
              <small>{order.order_shipments?.[0]?.tracking_number || '-'}</small>
            </td>
            <td>
              <Form.Select value={order.status} onChange={(event) => updateOrderStatus(order.id, event.target.value as OrderStatus).then(onReload)}>
                {Object.entries(orderStatusLabels).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </Form.Select>
            </td>
          </tr>
        ))}
      </AdminTable>
    </SectionCard>
  );
}

function SectionCard({ title, actionLabel, onAction, children }: { title: string; actionLabel?: string; onAction?: () => void; children: ReactNode }) {
  return (
    <Card className="glass-card table-card">
      <Card.Body>
        <div className="section-heading">
          <div>
            <p className="eyebrow">Operations</p>
            <h3>{title}</h3>
          </div>
          {actionLabel && (
            <Button className="primary-glow" onClick={onAction}>
              {actionLabel}
            </Button>
          )}
        </div>
        {children}
      </Card.Body>
    </Card>
  );
}

function AdminTable({ headers, children }: { headers: string[]; children: ReactNode }) {
  return (
    <Table responsive borderless className="admin-table">
      <thead>
        <tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr>
      </thead>
      <tbody>{children}</tbody>
    </Table>
  );
}

function StatusBadge({ status }: { status: string }) {
  const className = status.includes('เปิด') || status.includes('สำเร็จ') || status.includes('ขาย') ? 'success' : status.includes('รอ') || status.includes('แก้') || status.includes('แพ็ก') || status.includes('ส่ง') ? 'warning' : 'danger';
  return <span className={`status-badge ${className}`}>{status}</span>;
}

function Placeholder({ title, body }: { title: string; body: string }) {
  return (
    <Card className="glass-card">
      <Card.Body>
        <Badge bg="light" text="dark" className="soft-badge">
          Ready schema
        </Badge>
        <h3 className="mt-3">{title}</h3>
        <p className="muted-note">{body}</p>
      </Card.Body>
    </Card>
  );
}

function buildChartBars(orders: OrderRow[]) {
  if (!orders.length) return [38, 52, 45, 64, 58, 72, 66, 82, 76, 88, 78, 92];
  const monthly = Array.from({ length: 12 }, () => 0);
  for (const order of orders) {
    const month = new Date(order.created_at).getMonth();
    monthly[month] += Number(order.grand_total || 0);
  }
  const max = Math.max(...monthly, 1);
  return monthly.map((value) => Math.max(22, Math.round((value / max) * 92)));
}

function initials(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return 'NP';
  const words = trimmed.split(/\s+/);
  return words.length > 1 ? `${words[0][0]}${words[1][0]}`.toUpperCase() : trimmed.slice(0, 2).toUpperCase();
}

function formatRole(role: string) {
  return role
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function formatExpiry(expiresAt: string | null) {
  if (!expiresAt) return 'ไม่มีวันหมดอายุ';
  return `หมดอายุ ${new Date(expiresAt).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })}`;
}
