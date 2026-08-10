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
  const [shopFromDate, setShopFromDate] = useState('');
  const [shopToDate, setShopToDate] = useState('');
  const [shopPageSize, setShopPageSize] = useState(50);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showProduct, setShowProduct] = useState(false);

  const load = async (silent = false) => {
    if (!silent) setLoading(true);
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
      if (!silent) setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  useEffect(() => {
    if (!admin) return undefined;
    const timer = window.setInterval(() => {
      void load(true);
    }, 10000);
    return () => window.clearInterval(timer);
  }, [admin]);

  const normalizedQuery = query.toLowerCase();
  const pendingShopCount = shops.filter((shop) => shop.status === 'pending_review').length;

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
              <SidebarButton
                key={item.key}
                active={section === item.key}
                count={item.key === 'shops' ? pendingShopCount : 0}
                icon={item.icon}
                label={item.label}
                onClick={() => setSection(item.key)}
              />
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
            <SidebarButton
              active={section === 'settings'}
              icon="sliders"
              label={pageTitles.settings}
              onClick={() => setSection('settings')}
            />
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
            <div className="topbar-actions">
              {section === 'shops' && (
                <>
                  <DateRangePicker
                    fromDate={shopFromDate}
                    toDate={shopToDate}
                    onChange={(from, to) => {
                      setShopFromDate(from);
                      setShopToDate(to);
                    }}
                  />
                  <Form.Select
                    className="page-size-select"
                    value={shopPageSize}
                    onChange={(event) => setShopPageSize(Number(event.target.value))}
                  >
                    <option value={50}>50 รายการ</option>
                    <option value={100}>100 รายการ</option>
                  </Form.Select>
                </>
              )}
              <Form.Control
                className="search-input"
                placeholder="ค้นหาร้านค้า ผู้ใช้ สินค้า หรือออเดอร์"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
              <button className="icon-button" aria-label="Refresh" type="button" onClick={() => load()}>
                <i className="bi bi-arrow-clockwise" aria-hidden />
              </button>
              <button className="icon-button notification-button" aria-label="Notifications" type="button" onClick={() => setSection('shops')}>
                <i className="bi bi-bell" aria-hidden />
                {pendingShopCount > 0 && <span className="notification-dot">{pendingShopCount}</span>}
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
          {section === 'shops' && (
            <ShopManagement
              shops={filteredShops}
              onReload={() => load(true)}
              fromDate={shopFromDate}
              toDate={shopToDate}
              pageSize={shopPageSize}
            />
          )}
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
  count = 0,
  icon,
  label,
  onClick
}: {
  active: boolean;
  className?: string;
  count?: number;
  icon: string;
  label: string;
  onClick: () => void;
}) {
  return (
    <button className={`nav-pill ${className} ${active ? 'active' : ''}`} onClick={onClick} type="button">
      <i className={`bi bi-${icon}`} aria-hidden />
      <span>{label}</span>
      {count > 0 && <span className="nav-count">{count}</span>}
    </button>
  );
}

function LoginScreen({ loading, error, onLoggedIn }: { loading: boolean; error: string; onLoggedIn: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [loginBusy, setLoginBusy] = useState(false);
  const canSubmit = Boolean(isSupabaseConfigured && !loginBusy);

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
          method="post"
          onSubmit={async (event) => {
            event.preventDefault();
            if (!canSubmit) return;
            setLoginError('');
            const formData = new FormData(event.currentTarget);
            const formEmail = String(formData.get('email') ?? email).trim();
            const formPassword = String(formData.get('password') ?? password);
            if (!formEmail || !formPassword) {
              setLoginError('กรุณากรอกอีเมลและรหัสผ่าน');
              return;
            }
            setLoginBusy(true);
            try {
              const admin = await signInAdmin(formEmail, formPassword);
              if (!admin) {
                setLoginError('บัญชีนี้เข้าสู่ระบบ Auth ได้แล้ว แต่ยังไม่มีสิทธิ์แอดมินในตาราง admin_accounts หรือบัญชีถูกปิดใช้งาน');
                return;
              }
              onLoggedIn();
            } catch (err) {
              const message = err instanceof Error ? err.message : '';
              if (message.toLowerCase().includes('invalid login credentials')) {
                setLoginError('อีเมลหรือรหัสผ่านไม่ถูกต้อง หรือยังไม่มีบัญชีนี้ใน Supabase Auth');
              } else if (message.toLowerCase().includes('email not confirmed')) {
                setLoginError('บัญชีนี้ยังไม่ได้ยืนยันอีเมลใน Supabase Auth');
              } else {
                setLoginError(message || 'เข้าสู่ระบบไม่สำเร็จ กรุณาตรวจสอบบัญชี Supabase Auth และสิทธิ์ admin_accounts');
              }
            } finally {
              setLoginBusy(false);
            }
          }}
        >
          <Form.Group className="mb-3">
            <Form.Label>Email</Form.Label>
            <Form.Control name="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" placeholder="admin@example.com" />
          </Form.Group>
          <Form.Group className="mb-3">
            <Form.Label>Password</Form.Label>
            <Form.Control name="password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" />
          </Form.Group>
          <Button className="primary-glow w-100 login-button" disabled={!canSubmit} type="submit">
            {loginBusy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
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
        <div className="metric-head">
          <span className="metric-icon">
            <i className={`bi bi-${icon}`} aria-hidden />
          </span>
          <span className="metric-label">{label}</span>
        </div>
        <div className="metric-values">
          <strong>{value}</strong>
          <small>{change}</small>
        </div>
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

function ShopManagement({
  shops,
  onReload,
  fromDate,
  toDate,
  pageSize
}: {
  shops: ShopRow[];
  onReload: () => void;
  fromDate: string;
  toDate: string;
  pageSize: number;
}) {
  const [busyId, setBusyId] = useState('');
  const [selectedShop, setSelectedShop] = useState<ShopRow | null>(null);
  const [checked, setChecked] = useState<Record<string, boolean>>({});
  const [previewDocument, setPreviewDocument] = useState<NonNullable<ShopRow['shop_documents']>[number] | null>(null);

  useEffect(() => {
    if (!selectedShop) return;
    const latestShop = shops.find((shop) => shop.id === selectedShop.id);
    if (latestShop && latestShop !== selectedShop) {
      setSelectedShop(latestShop);
    }
  }, [shops, selectedShop]);
  const [page, setPage] = useState(1);

  const filteredByDate = useMemo(() => {
    const fromTime = fromDate ? new Date(fromDate + 'T00:00:00').getTime() : null;
    const toTime = toDate ? new Date(toDate + 'T23:59:59').getTime() : null;
    return shops.filter((shop) => {
      const created = new Date(shop.created_at).getTime();
      if (fromTime !== null && created < fromTime) return false;
      if (toTime !== null && created > toTime) return false;
      return true;
    }).sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
  }, [fromDate, shops, toDate]);

  const pageCount = Math.max(1, Math.ceil(filteredByDate.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const visibleShops = filteredByDate.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  useEffect(() => {
    setPage(1);
  }, [fromDate, pageSize, toDate]);

  const setCheck = (id: string, value: boolean) => {
    setChecked((current) => ({ ...current, [id]: value }));
  };

  const openDetail = (shop: ShopRow) => {
    setSelectedShop(shop);
    setPreviewDocument(null);
    setChecked({
      pickup: false,
      identity_card: false,
      bank_book: false
    });
  };

  const review = async (shop: ShopRow, status: ShopStatus, note = '') => {
    setBusyId(shop.id);
    try {
      await updateShopReview(shop.id, status, note);
      setSelectedShop(null);
      setPreviewDocument(null);
      await onReload();
    } finally {
      setBusyId('');
    }
  };

  const rejectSelected = async () => {
    if (!selectedShop) return;
    const failed = [
      !checked.pickup && 'ข้อมูลรับสินค้าไม่ผ่าน',
      !checked.identity_card && 'สำเนาบัตรประชาชนไม่ผ่าน',
      !checked.bank_book && 'หน้าสมุดบัญชีไม่ผ่าน'
    ].filter(Boolean);
    await review(selectedShop, 'suspended', failed.length ? failed.join(', ') : 'ไม่อนุมัติคำขอเปิดร้าน');
  };

  return (
    <SectionCard title="ร้านค้า" actionLabel={filteredByDate.length + ' รายการ'}>
      <AdminTable headers={['รูป', 'แอคเคาท์', 'วันที่ส่งคำขอ', 'สถานะ', 'ข้อมูล/เอกสาร']}>
        {visibleShops.map((shop) => (
          <tr key={shop.id}>
            <td>
              <AccountAvatar shop={shop} />
            </td>
            <td>
              <strong>{shop.profiles?.display_name || '-'}</strong>
              <small>{shop.profiles?.email || '-'}</small>
            </td>
            <td>{formatDateTime(shop.created_at)}</td>
            <td>
              <StatusBadge status={shopStatusLabels[shop.status]} />
              {shop.review_note && <small>{shop.review_note}</small>}
            </td>
            <td>
              <Button size="sm" variant="outline-light" onClick={() => openDetail(shop)}>
                ข้อมูล/เอกสาร
              </Button>
            </td>
          </tr>
        ))}
      </AdminTable>
      <div className="table-pagination">
        <Button size="sm" variant="outline-light" disabled={currentPage <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>
          ก่อนหน้า
        </Button>
        <span>{currentPage}/{pageCount}</span>
        <Button size="sm" variant="outline-light" disabled={currentPage >= pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>
          ถัดไป
        </Button>
      </div>
      <Modal show={Boolean(selectedShop)} onHide={() => { setSelectedShop(null); setPreviewDocument(null); }} centered size="lg" contentClassName="document-modal">
        <Modal.Header closeButton>
          <Modal.Title>ข้อมูล/เอกสาร</Modal.Title>
        </Modal.Header>
        {selectedShop && (
          <Modal.Body>
            <div className="review-grid">
              <ReviewCheck id="pickup" label="ข้อมูลร้านค้า" checked={Boolean(checked.pickup)} onChange={setCheck}>
                <strong>{selectedShop.profiles?.display_name || '-'}</strong>
                <small>เบอร์โทร: {selectedShop.phone || selectedShop.profiles?.phone || '-'}</small>
                <small>ชื่อบัญชี: {selectedShop.bank_account_name || '-'}</small>
                <small>เลขบัญชี: {selectedShop.bank_account_number || '-'}</small>
                <small>ธนาคาร: {selectedShop.bank_name || '-'}</small>
                <small>รายละเอียดเพิ่มเติม: {selectedShop.pickup_address || '-'}</small>
                <small>จังหวัด: {selectedShop.pickup_province || '-'}</small>
                <small>เขต/อำเภอ: {selectedShop.pickup_district || '-'}</small>
                <small>แขวง/ตำบล: {selectedShop.pickup_sub_district || '-'}</small>
                <small>รหัสไปรษณีย์: {selectedShop.pickup_postcode || '-'}</small>
              </ReviewCheck>
              <div className="review-document-pair">
                <ReviewCheck id="identity_card" label="สำเนาบัตร" checked={Boolean(checked.identity_card)} onChange={setCheck}>
                  <DocumentPreview documents={selectedShop.shop_documents ?? []} type="identity_card" onPreview={setPreviewDocument} />
                </ReviewCheck>
                <ReviewCheck id="bank_book" label="หน้าสมุดบัญชี" checked={Boolean(checked.bank_book)} onChange={setCheck}>
                  <DocumentPreview documents={selectedShop.shop_documents ?? []} type="bank_book" onPreview={setPreviewDocument} />
                </ReviewCheck>
              </div>
            </div>
          </Modal.Body>
        )}
        <Modal.Footer>
          <Button variant="outline-light" disabled={!selectedShop || busyId === selectedShop.id} onClick={rejectSelected}>
            ไม่อนุมัติ
          </Button>
          <Button className="primary-glow" disabled={!selectedShop || busyId === selectedShop.id} onClick={() => selectedShop && review(selectedShop, 'active')}>
            อนุมัติ
          </Button>
        </Modal.Footer>
      </Modal>
      <Modal show={Boolean(previewDocument)} onHide={() => setPreviewDocument(null)} centered size="xl" contentClassName="image-preview-modal">
        {previewDocument && (
          <>
            <Modal.Header closeButton>
              <Modal.Title>{documentTypeLabel(previewDocument.type)}</Modal.Title>
              <a className="document-download ms-auto me-3" href={previewDocument.signed_url || previewDocument.file_url} download aria-label="ดาวน์โหลดรูป">
                <DownloadSvg />
              </a>
            </Modal.Header>
            <Modal.Body>
              <img src={previewDocument.signed_url || previewDocument.file_url} alt={documentTypeLabel(previewDocument.type)} />
            </Modal.Body>
          </>
        )}
      </Modal>
    </SectionCard>
  );
}

function ReviewCheck({
  id,
  label,
  checked,
  onChange,
  children
}: {
  id: string;
  label: string;
  checked: boolean;
  onChange: (id: string, value: boolean) => void;
  children: ReactNode;
}) {
  return (
    <div className="review-check-row">
      <Form.Check checked={checked} onChange={(event) => onChange(id, event.target.checked)} />
      <div>
        <strong>{label}</strong>
        <div className="review-check-content">{children}</div>
      </div>
    </div>
  );
}

function ShopLogo({ shop }: { shop: ShopRow }) {
  const [failed, setFailed] = useState(false);
  const logoUrl = shop.logo_signed_url || shop.logo_url;
  if (!logoUrl || failed) {
    return (
      <span className="queue-logo">
        {initials(shop.name || shop.profiles?.display_name || 'NP')}
      </span>
    );
  }
  return (
    <img
      className="queue-logo"
      src={logoUrl}
      alt=""
      onError={() => setFailed(true)}
    />
  );
}

function AccountAvatar({ shop }: { shop: ShopRow }) {
  const [failed, setFailed] = useState(false);
  const avatarUrl = shop.profiles?.avatar_url || '';
  if (!avatarUrl || failed) {
    return (
      <span className="queue-logo">
        {initials(shop.profiles?.display_name || shop.profiles?.email || 'NP')}
      </span>
    );
  }
  return (
    <img
      className="queue-logo"
      src={avatarUrl}
      alt=""
      onError={() => setFailed(true)}
    />
  );
}

function DocumentPreview({
  documents,
  type,
  onPreview
}: {
  documents: NonNullable<ShopRow['shop_documents']>;
  type: string;
  onPreview: (document: NonNullable<ShopRow['shop_documents']>[number]) => void;
}) {
  const document = documents
    .filter((item) => item.type === type)
    .sort((a, b) => Date.parse(b.updated_at || b.created_at || '') - Date.parse(a.updated_at || a.created_at || ''))[0];
  if (!document) return <span>-</span>;
  const url = document.signed_url || document.file_url;
  return (
    <div className="document-thumb-row">
      <DocumentThumb url={url} label={documentTypeLabel(type)} onClick={() => onPreview(document)} />
      <div className="document-thumb-copy">
        <strong>{documentTypeLabel(type)}</strong>
        <small>{document.status || 'รอตรวจสอบ'}</small>
      </div>
      <a className="document-download" href={url} download aria-label="ดาวน์โหลดรูป">
        <DownloadSvg />
      </a>
    </div>
  );
}

function DocumentThumb({
  url,
  label,
  onClick
}: {
  url: string;
  label: string;
  onClick: () => void;
}) {
  const [failed, setFailed] = useState(false);
  return (
    <button className="document-thumb" type="button" onClick={onClick}>
      {!failed && url ? (
        <img src={url} alt={label} onError={() => setFailed(true)} />
      ) : (
        <span>
          <i className="bi bi-file-earmark-image" aria-hidden />
          {label}
        </span>
      )}
    </button>
  );
}

function documentTypeLabel(type: string) {
  if (type === 'identity_card') return 'สำเนาบัตร';
  if (type === 'bank_book') return 'หน้าสมุดบัญชี';
  return 'เอกสาร';
}

function DownloadSvg() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3v11m0 0 4-4m-4 4-4-4M5 17v2a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-2" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function DateRangePicker({
  fromDate,
  toDate,
  onChange
}: {
  fromDate: string;
  toDate: string;
  onChange: (fromDate: string, toDate: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [cursor, setCursor] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [draftFrom, setDraftFrom] = useState(fromDate);
  const [draftTo, setDraftTo] = useState(toDate);
  const [selectingStart, setSelectingStart] = useState(true);

  useEffect(() => {
    const latest = toDateInputValue(new Date());
    setDraftFrom(fromDate || latest);
    setDraftTo(toDate || latest);
    if (!fromDate && !toDate) onChange(latest, latest);
  }, [fromDate, toDate]);

  const selectPreset = (days: number | 'latest') => {
    const end = new Date();
    const start = new Date();
    if (days === 'latest') {
      const value = toDateInputValue(end);
      setDraftFrom(value);
      setDraftTo(value);
      setSelectingStart(true);
      onChange(value, value);
      setOpen(false);
      return;
    }
    start.setDate(end.getDate() - days + 1);
    const from = toDateInputValue(start);
    const to = toDateInputValue(end);
    setDraftFrom(from);
    setDraftTo(to);
    setSelectingStart(true);
    onChange(from, to);
    setOpen(false);
  };

  const selectDay = (day: Date) => {
    const value = toDateInputValue(day);
    if (selectingStart) {
      setDraftFrom(value);
      setDraftTo('');
      setSelectingStart(false);
      return;
    }
    const from = draftFrom && value >= draftFrom ? draftFrom : value;
    const to = draftFrom && value >= draftFrom ? value : draftFrom;
    setDraftFrom(from);
    setDraftTo(to);
    setSelectingStart(true);
    onChange(from, to);
    setOpen(false);
  };

  const nextMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
  const displayFrom = draftFrom || toDateInputValue(new Date());
  const displayTo = draftTo || displayFrom;

  return (
    <div className="date-range-picker">
      <button className="date-range-button" type="button" onClick={() => {
        const latest = toDateInputValue(new Date());
        setDraftFrom(fromDate || latest);
        setDraftTo(toDate || latest);
        setSelectingStart(true);
        setOpen((value) => !value);
      }}>
        <i className="bi bi-calendar3" aria-hidden />
        <span className="date-field">{displayFrom}</span>
        {displayTo !== displayFrom && (
          <>
            <span className="date-separator">~</span>
            <span className="date-field">{displayTo}</span>
          </>
        )}
      </button>
      {open && (
        <div className="calendar-popover range">
          <div className="calendar-presets">
            <button type="button" onClick={() => selectPreset('latest')}>วันที่อัปเดตล่าสุด</button>
            <button type="button" onClick={() => selectPreset(7)}>7 วันล่าสุด</button>
            <button type="button" onClick={() => selectPreset(15)}>15 วันล่าสุด</button>
            <button type="button" onClick={() => selectPreset(30)}>30 วันล่าสุด</button>
          </div>
          <div className="calendar-range-panel">
            <CalendarMonth
              month={cursor}
              fromDate={draftFrom}
              toDate={draftTo}
              onSelect={selectDay}
              onPrevious={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() - 1, 1))}
            />
            <CalendarMonth
              month={nextMonth}
              fromDate={draftFrom}
              toDate={draftTo}
              onSelect={selectDay}
              onNext={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1))}
            />
          </div>
        </div>
      )}
    </div>
  );
}

function CalendarMonth({
  month,
  fromDate,
  toDate,
  onSelect,
  onPrevious,
  onNext
}: {
  month: Date;
  fromDate: string;
  toDate: string;
  onSelect: (day: Date) => void;
  onPrevious?: () => void;
  onNext?: () => void;
}) {
  const days = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const start = new Date(first);
    start.setDate(first.getDate() - first.getDay());
    return Array.from({ length: 42 }, (_, dayIndex) => {
      const day = new Date(start);
      day.setDate(start.getDate() + dayIndex);
      return day;
    });
  }, [month]);
  const monthLabel = month.toLocaleDateString('th-TH', { month: 'long', year: 'numeric' });
  return (
    <div className="calendar-month">
      <div className="calendar-head">
        {onPrevious ? <button type="button" onClick={onPrevious}>‹</button> : <span />}
        <strong>{monthLabel}</strong>
        {onNext ? <button type="button" onClick={onNext}>›</button> : <span />}
      </div>
      <div className="calendar-grid calendar-weekdays">
        {['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'].map((day) => <span key={day}>{day}</span>)}
      </div>
      <div className="calendar-grid">
        {days.map((day) => {
          const value = toDateInputValue(day);
          const mutedDay = day.getMonth() !== month.getMonth();
          const selected = value === fromDate || value === toDate;
          const inRange = Boolean(fromDate && toDate && value > fromDate && value < toDate);
          return (
            <button
              key={value}
              className={[mutedDay ? 'muted' : '', selected ? 'selected' : '', inRange ? 'in-range' : ''].join(' ')}
              type="button"
              onClick={() => onSelect(day)}
            >
              {day.getDate()}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function toDateInputValue(value: Date) {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return year + '-' + month + '-' + day;
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
        <div className="section-heading compact">
          <span className="sr-only">{title}</span>
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

function formatDateTime(value: string) {
  return new Date(value).toLocaleString('th-TH', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

function formatExpiry(expiresAt: string | null) {
  if (!expiresAt) return 'ไม่มีวันหมดอายุ';
  return `หมดอายุ ${new Date(expiresAt).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })}`;
}
