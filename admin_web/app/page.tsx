'use client';

import { useMemo, useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';
import {
  Badge,
  Button,
  Card,
  Col,
  Container,
  Form,
  Modal,
  Nav,
  ProgressBar,
  Row,
  Table
} from 'react-bootstrap';
import {
  adminAccounts,
  carriers,
  orders as initialOrders,
  reports,
  shops as initialShops,
  users as initialUsers,
  type AdminAccount,
  type AdminRole,
  type UserAccount,
  type UserStatus,
  type ShopRecord,
  type ShopStatus
} from '../lib/mock-data';

type SectionKey =
  | 'dashboard'
  | 'shops'
  | 'orders'
  | 'shipping'
  | 'appUsers'
  | 'adminUsers'
  | 'reports'
  | 'finance'
  | 'settings';

type AdminUserDraft = {
  username: string;
  name: string;
  role: AdminRole;
  expiresAt: string;
  active: boolean;
};

type UserDraft = {
  name: string;
  role: 'ลูกค้า' | 'ผู้ขาย';
  phone: string;
  email: string;
  status: UserStatus;
  orders: number;
};

const roleLabels: Record<AdminRole, string> = {
  super_admin: 'Super Admin',
  shop_approver: 'Shop Approver',
  order_admin: 'Order Admin',
  content_admin: 'Content Admin',
  support_admin: 'Support Admin'
};

const menuItems: Array<{ key: SectionKey; label: string; icon: string; roles: AdminRole[] }> = [
  { key: 'dashboard', label: 'แดชบอร์ด', icon: 'grid', roles: ['super_admin', 'shop_approver', 'order_admin', 'content_admin', 'support_admin'] },
  { key: 'shops', label: 'ร้านค้า', icon: 'shop', roles: ['super_admin', 'shop_approver', 'support_admin'] },
  { key: 'orders', label: 'ออเดอร์', icon: 'receipt', roles: ['super_admin', 'order_admin', 'support_admin'] },
  { key: 'shipping', label: 'ขนส่ง', icon: 'truck', roles: ['super_admin', 'order_admin'] },
  { key: 'appUsers', label: 'ผู้ใช้ในแอป', icon: 'people', roles: ['super_admin', 'support_admin'] },
  { key: 'adminUsers', label: 'แอดมิน', icon: 'person-gear', roles: ['super_admin'] },
  { key: 'reports', label: 'รายงาน', icon: 'flag', roles: ['super_admin', 'support_admin', 'shop_approver'] },
  { key: 'finance', label: 'การเงิน', icon: 'cash-stack', roles: ['super_admin', 'order_admin'] },
  { key: 'settings', label: 'ตั้งค่าระบบ', icon: 'sliders', roles: ['super_admin'] }
];

const orderStatuses = ['รอชำระเงิน', 'รอร้านยืนยัน', 'รอจัดส่ง', 'กำลังจัดส่ง', 'สำเร็จ', 'ยกเลิก', 'คืนสินค้า/คืนเงิน'];
const appPayments = ['เก็บเงินปลายทาง', 'QR พร้อมเพย์', 'Mobile Banking', 'บัตรเครดิต/เดบิต'];
const categories = ['แฟชั่น', 'กระเป๋า', 'ของใช้บ้าน', 'อุปกรณ์ดิจิทัล', 'สุขภาพและความงาม'];

export default function AdminHome() {
  const [currentAdmin, setCurrentAdmin] = useState<AdminAccount | null>(null);
  const [section, setSection] = useState<SectionKey>('dashboard');
  const [shops, setShops] = useState(initialShops);
  const [adminUsers, setAdminUsers] = useState(adminAccounts);
  const [query, setQuery] = useState('');
  const [documentShop, setDocumentShop] = useState<ShopRecord | null>(null);
  const [loginError, setLoginError] = useState('');

  const visibleMenus = useMemo(() => {
    if (!currentAdmin) return [];
    return menuItems.filter((item) => item.roles.includes(currentAdmin.role));
  }, [currentAdmin]);
  const userMenus = visibleMenus.filter((item) => item.key === 'appUsers' || item.key === 'adminUsers');
  const mainMenus = visibleMenus.filter((item) => item.key !== 'appUsers' && item.key !== 'adminUsers');

  const pageTitle = menuItems.find((item) => item.key === section)?.label ?? 'แดชบอร์ด';
  const pendingShops = shops.filter((shop) => shop.status === 'รอตรวจสอบ');
  const activeShops = shops.filter((shop) => shop.status === 'เปิดขาย');
  const openReports = reports.filter((report) => report.status !== 'ปิดเรื่องแล้ว');
  const problemOrders = initialOrders.filter((order) => ['ยกเลิก', 'คืนสินค้า/คืนเงิน'].includes(order.status));
  const todayRevenue = initialOrders.reduce((sum, order) => sum + order.amount, 0);
  const filteredShops = shops.filter((shop) =>
    [shop.shopName, shop.owner, shop.category, shop.province].join(' ').toLowerCase().includes(query.toLowerCase())
  );

  const signIn = (username: string, password: string) => {
    const admin = adminUsers.find((item) => item.username === username.trim() && item.password === password);
    if (!admin || !admin.active || new Date(admin.expiresAt) < new Date()) {
      setLoginError('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง หรือบัญชีถูกปิดใช้งาน');
      return;
    }
    setCurrentAdmin(admin);
    setSection('dashboard');
    setLoginError('');
  };

  const signOut = () => {
    setCurrentAdmin(null);
    setQuery('');
  };

  const setShopStatus = (id: string, status: ShopStatus) => {
    setShops((current) => current.map((shop) => (shop.id === id ? { ...shop, status } : shop)));
  };

  const createAdminUser = (draft: AdminUserDraft) => {
    setAdminUsers((current) => [
      ...current,
      {
        id: `A-${String(current.length + 1).padStart(3, '0')}`,
        username: draft.username,
        password: 'admin1234',
        name: draft.name,
        role: draft.role,
        active: draft.active,
        expiresAt: draft.expiresAt,
        lastLogin: '-'
      }
    ]);
  };

  const toggleAdminUser = (admin: AdminAccount) => {
    setAdminUsers((current) => current.map((item) => (item.id === admin.id ? { ...item, active: !item.active } : item)));
  };

  if (!currentAdmin) {
    return <LoginScreen error={loginError} onSubmit={signIn} />;
  }

  return (
    <main className="admin-page">
      <Container fluid className="admin-shell">
        <aside className="admin-sidebar">
          <div className="brand-lockup">
            <span className="brand-mark">NP</span>
            <div>
              <strong>NP Admin</strong>
              <small>{roleLabels[currentAdmin.role]}</small>
            </div>
          </div>

          <Nav className="admin-nav">
            {mainMenus.map((item) => (
              <button
                key={item.key}
                className={`nav-pill ${section === item.key ? 'active' : ''}`}
                onClick={() => setSection(item.key)}
                type="button"
              >
                <i className={`bi bi-${item.icon}`} aria-hidden />
                <span>{item.label}</span>
              </button>
            ))}
            {userMenus.length > 0 && (
              <div className="nav-group">
                <div className="nav-group-label">
                  <i className="bi bi-people" aria-hidden />
                  <span>ผู้ใช้</span>
                </div>
                {userMenus.map((item) => (
                  <button
                    key={item.key}
                    className={`nav-pill nav-subpill ${section === item.key ? 'active' : ''}`}
                    onClick={() => setSection(item.key)}
                    type="button"
                  >
                    <i className={`bi bi-${item.icon}`} aria-hidden />
                    <span>{item.label}</span>
                  </button>
                ))}
              </div>
            )}
          </Nav>

          <div className="sidebar-footer">
            <button className="nav-pill" type="button" onClick={signOut}>
              <i className="bi bi-box-arrow-left" aria-hidden />
              <span>ออกจากระบบ</span>
            </button>
          </div>
        </aside>

        <section className="admin-workspace">
          <header className="topbar">
            <div>
              <p className="eyebrow">NP Market Back Office</p>
              <h1>{pageTitle}</h1>
              <span>{currentAdmin.name} • หมดอายุ {formatThaiDate(currentAdmin.expiresAt)}</span>
            </div>
            <div className="topbar-actions">
              <Form.Control
                className="search-input"
                placeholder="ค้นหาร้านค้า ผู้ใช้ สินค้า หรือออเดอร์"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
              <button className="icon-button" aria-label="แจ้งเตือน" type="button">
                <i className="bi bi-bell" aria-hidden />
              </button>
              <div className="admin-avatar">{currentAdmin.name.charAt(0)}</div>
            </div>
          </header>

          {section === 'dashboard' && (
            <Dashboard
              pendingShops={pendingShops.length}
              activeShops={activeShops.length}
              openReports={openReports.length}
              problemOrders={problemOrders.length}
              revenue={todayRevenue}
              shops={shops}
              onOpenShops={() => setSection('shops')}
            />
          )}
          {section === 'shops' && (
            <ShopManagement shops={filteredShops} onStatus={setShopStatus} onOpenDocuments={setDocumentShop} />
          )}
          {section === 'orders' && <OrderManagement />}
          {section === 'shipping' && <ShippingManagement />}
          {section === 'appUsers' && <AppUserManagement />}
          {section === 'adminUsers' && (
            <AdminUserManagement
              adminUsers={adminUsers}
              onCreateAdmin={createAdminUser}
              onToggleAdmin={toggleAdminUser}
            />
          )}
          {section === 'reports' && <ReportManagement />}
          {section === 'finance' && <FinanceManagement revenue={todayRevenue} />}
          {section === 'settings' && <SettingsManagement isSuperAdmin={currentAdmin.role === 'super_admin'} />}
        </section>
      </Container>

      <DocumentReviewModal
        shop={documentShop}
        onHide={() => setDocumentShop(null)}
        onApprove={(shop) => {
          setShopStatus(shop.id, 'เปิดขาย');
          setDocumentShop(null);
        }}
        onRequestFix={(shop) => {
          setShopStatus(shop.id, 'ขอแก้ไขข้อมูล');
          setDocumentShop(null);
        }}
      />
    </main>
  );
}

function LoginScreen({ error, onSubmit }: { error: string; onSubmit: (username: string, password: string) => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  return (
    <main className="login-page">
      <div className="login-scenery" aria-hidden="true">
        <div className="login-orbit login-orbit-one" />
        <div className="login-orbit login-orbit-two" />
        <div className="login-chip login-chip-left">
          <strong>12</strong>
          <span>ระบบดูแลร้านค้า</span>
        </div>
        <div className="login-chip login-chip-right">
          <strong>5</strong>
          <span>ขนส่งในระบบ</span>
        </div>
      </div>
      <section className="login-card" aria-label="เข้าสู่ระบบหลังบ้าน">
        <div className="login-mark">
          <span>NP</span>
        </div>
        <p className="login-eyebrow">Admin Control Center</p>
        <h1>Welcome <span>back!</span></h1>
        <p className="login-copy">เข้าสู่ระบบเพื่ออนุมัติร้านค้า จัดการออเดอร์ และดูแลแพลตฟอร์ม NP Market</p>
        <Form
          onSubmit={(event) => {
            event.preventDefault();
            onSubmit(username, password);
          }}
        >
          <Form.Group className="mb-3">
            <Form.Label>Username</Form.Label>
            <Form.Control
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              autoComplete="username"
              placeholder="กรอกชื่อผู้ใช้"
            />
          </Form.Group>
          <Form.Group className="mb-3">
            <Form.Label>Password</Form.Label>
            <Form.Control
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="current-password"
              placeholder="กรอกรหัสผ่าน"
            />
          </Form.Group>
          <div className="login-row">
            <label className="login-check">
              <input type="checkbox" defaultChecked />
              <span>จดจำอุปกรณ์นี้</span>
            </label>
            <span>บัญชีสร้างโดย Super Admin</span>
          </div>
          {error && <div className="form-error">{error}</div>}
          <Button className="primary-glow w-100 login-button" type="submit">
            เข้าสู่ระบบ
          </Button>
        </Form>
        <div className="login-footnote">ไม่มีสมัครสมาชิกและไม่มี Social Login สำหรับหลังบ้าน</div>
      </section>
    </main>
  );
}

function Dashboard({
  pendingShops,
  activeShops,
  openReports,
  problemOrders,
  revenue,
  shops,
  onOpenShops
}: {
  pendingShops: number;
  activeShops: number;
  openReports: number;
  problemOrders: number;
  revenue: number;
  shops: ShopRecord[];
  onOpenShops: () => void;
}) {
  return (
    <>
      <Row className="g-3 mb-3">
        <Col xl={7}>
          <Card className="hero-card">
            <Card.Body>
              <div className="hero-copy">
                <Badge bg="light" text="dark" className="soft-badge">Admin Console</Badge>
                <h2>ควบคุมร้านค้า ออเดอร์ ผู้ใช้ และความปลอดภัยของตลาด</h2>
                <p>เห็นงานที่ต้องจัดการวันนี้ก่อนเสมอ: ร้านรออนุมัติ รายงานรอตรวจ ออเดอร์มีปัญหา และขนส่งล่าช้า</p>
                <div className="hero-actions">
                  <Button className="primary-glow" onClick={onOpenShops}>ตรวจร้านรออนุมัติ</Button>
                  <Button variant="outline-light">ดูออเดอร์วันนี้</Button>
                </div>
              </div>
              <div className="hero-orbit">
                <span>รออนุมัติ</span>
                <strong>{pendingShops}</strong>
                <small>ร้านค้า</small>
              </div>
            </Card.Body>
          </Card>
        </Col>
        <Col xl={5}>
          <QueueCard title="งานด่วนวันนี้" shops={shops.slice(0, 3)} onOpen={onOpenShops} />
        </Col>
      </Row>
      <Row className="g-3 mb-3">
        <MetricCard label="ยอดขายวันนี้" value={`฿${revenue.toLocaleString('th-TH')}`} change="+18.4%" icon="graph-up-arrow" />
        <MetricCard label="ร้านค้าเปิดขาย" value={`${activeShops}`} change="ใช้งานอยู่" icon="shop" />
        <MetricCard label="รายงานรอตรวจ" value={`${openReports}`} change="ต้องเปิดเคส" icon="flag" />
        <MetricCard label="ออเดอร์มีปัญหา" value={`${problemOrders}`} change="ต้องจัดการ" icon="exclamation-triangle" />
      </Row>
      <Row className="g-3">
        <Col xl={8}><PerformancePanel /></Col>
        <Col xl={4}><TodayChecklist /></Col>
      </Row>
    </>
  );
}

function QueueCard({ title, shops, onOpen }: { title: string; shops: ShopRecord[]; onOpen: () => void }) {
  return (
    <Card className="glass-card h-100">
      <Card.Body>
        <div className="section-heading">
          <div>
            <p className="eyebrow">Approval Queue</p>
            <h3>{title}</h3>
          </div>
          <Button variant="link" onClick={onOpen}>ดูทั้งหมด</Button>
        </div>
        <div className="queue-list">
          {shops.map((shop) => (
            <button className="queue-item" key={shop.id} type="button" onClick={onOpen}>
              <span className="queue-logo">{shop.shopName.slice(0, 2)}</span>
              <span><strong>{shop.shopName}</strong><small>{shop.status} • {shop.documentStatus}</small></span>
              <i className="bi bi-chevron-right" aria-hidden />
            </button>
          ))}
        </div>
      </Card.Body>
    </Card>
  );
}

function MetricCard({ label, value, change, icon }: { label: string; value: string; change: string; icon: string }) {
  return (
    <Col sm={6} xl={3}>
      <Card className="metric-card h-100">
        <Card.Body>
          <div className="metric-icon"><i className={`bi bi-${icon}`} aria-hidden /></div>
          <span>{label}</span>
          <strong>{value}</strong>
          <small>{change}</small>
        </Card.Body>
      </Card>
    </Col>
  );
}

function PerformancePanel() {
  const bars = [42, 58, 36, 74, 62, 82, 55, 69, 91, 72, 78, 64];
  return (
    <Card className="glass-card performance-card">
      <Card.Body>
        <div className="section-heading">
          <div><p className="eyebrow">Commerce Performance</p><h3>ยอดขายและออเดอร์</h3></div>
          <div className="period-tabs"><button type="button">1D</button><button type="button">1W</button><button type="button">1M</button><button className="active" type="button">6M</button></div>
        </div>
        <div className="chart-line">
          {bars.map((height, index) => <span key={index} style={{ '--bar': `${height}%` } as CSSProperties} />)}
        </div>
        <div className="chart-labels">{['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'].map((month) => <span key={month}>{month}</span>)}</div>
      </Card.Body>
    </Card>
  );
}

function TodayChecklist() {
  const tasks = ['ตรวจเอกสารร้านใหม่', 'ตรวจสินค้าถูกรายงาน', 'ติดตามออเดอร์ล่าช้า', 'ตอบเคสคืนสินค้า'];
  return (
    <Card className="glass-card h-100">
      <Card.Body>
        <div className="section-heading"><div><p className="eyebrow">Today</p><h3>งานที่ต้องจัดการ</h3></div></div>
        <div className="task-list">
          {tasks.map((task, index) => <div className="task-row" key={task}><span>{index + 1}</span><strong>{task}</strong><i className="bi bi-chevron-right" /></div>)}
        </div>
      </Card.Body>
    </Card>
  );
}

function ShopManagement({
  shops,
  onStatus,
  onOpenDocuments
}: {
  shops: ShopRecord[];
  onStatus: (id: string, status: ShopStatus) => void;
  onOpenDocuments: (shop: ShopRecord) => void;
}) {
  return (
    <StackedPage>
      <SectionCard eyebrow="Shop Management" title="จัดการร้านค้า" action="ส่งออกรายงาน">
        <SummaryPills items={[
          ['รออนุมัติ', shops.filter((shop) => shop.status === 'รอตรวจสอบ').length],
          ['เปิดขาย', shops.filter((shop) => shop.status === 'เปิดขาย').length],
          ['ขอแก้ไข', shops.filter((shop) => shop.status === 'ขอแก้ไขข้อมูล').length],
          ['ระงับ', shops.filter((shop) => shop.status === 'ระงับร้าน').length]
        ]} />
        <AdminTable headers={['ร้านค้า', 'ผู้ขาย', 'เอกสาร', 'ยอดขายร้าน', 'สถานะ', 'จัดการ']}>
          {shops.map((shop) => (
            <tr key={shop.id}>
              <td><strong>{shop.shopName}</strong><small>{shop.category} • {shop.province}</small></td>
              <td>{shop.owner}<small>{shop.phone}</small></td>
              <td>
                <button className="document-link" type="button" onClick={() => onOpenDocuments(shop)}>
                  <i className="bi bi-file-earmark-lock2" aria-hidden /><span>{shop.documents.length}/2 ไฟล์</span>
                </button>
                <small>{shop.documentStatus}</small>
              </td>
              <td>{shop.orders} ออเดอร์<small>คะแนน {shop.rating}</small></td>
              <td><StatusBadge status={shop.status} /></td>
              <td>
                <div className="row-actions">
                  <Button size="sm" variant="outline-light" onClick={() => onStatus(shop.id, 'ขอแก้ไขข้อมูล')}>ขอแก้ไข</Button>
                  <Button size="sm" className="primary-glow" onClick={() => onStatus(shop.id, 'เปิดขาย')}>อนุมัติ</Button>
                  <Button size="sm" variant="outline-light" onClick={() => onStatus(shop.id, 'ระงับร้าน')}>ระงับ</Button>
                </div>
              </td>
            </tr>
          ))}
        </AdminTable>
      </SectionCard>
    </StackedPage>
  );
}

function OrderManagement() {
  return (
    <SectionCard eyebrow="Orders" title="จัดการออเดอร์" action="ดูประวัติสถานะ">
      <SummaryPills items={orderStatuses.map((status) => [status, initialOrders.filter((order) => order.status === status).length])} />
      <AdminTable headers={['เลขออเดอร์', 'ร้าน/ลูกค้า', 'สินค้า', 'ชำระเงิน', 'ขนส่ง', 'สถานะ']}>
        {initialOrders.map((order) => (
          <tr key={order.id}>
            <td><strong>{order.id}</strong><small>ยอด ฿{order.amount.toLocaleString('th-TH')}</small></td>
            <td>{order.shop}<small>{order.buyer}</small></td>
            <td>{order.product}</td>
            <td>{order.payment}</td>
            <td>{order.carrier}<small>{order.trackingNo}</small></td>
            <td><StatusBadge status={order.status} /></td>
          </tr>
        ))}
      </AdminTable>
    </SectionCard>
  );
}

function ShippingManagement() {
  return (
    <StackedPage>
      <SectionCard eyebrow="Shipping" title="จัดการขนส่ง 5 เจ้า" action="ตั้งค่าค่าขนส่ง">
        <Row className="g-3">
          {carriers.map((carrier) => (
            <Col md={6} xl={4} key={carrier.name}>
              <Card className="mini-card h-100">
                <Card.Body>
                  <div className="mini-card-head"><i className="bi bi-truck" /><StatusBadge status={carrier.active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'} /></div>
                  <h4>{carrier.name}</h4>
                  <p>ค่าขนส่งเริ่มต้น ฿{carrier.baseFee} • SLA {carrier.sla}</p>
                  <div className="mini-stats"><span>รอเลขพัสดุ {carrier.pendingTracking}</span><span>ล่าช้า {carrier.delayedOrders}</span></div>
                </Card.Body>
              </Card>
            </Col>
          ))}
        </Row>
      </SectionCard>
    </StackedPage>
  );
}

function AppUserManagement() {
  const [appUsers, setAppUsers] = useState<UserAccount[]>(initialUsers);
  const [editingUser, setEditingUser] = useState<UserAccount | null>(null);
  const [showUserModal, setShowUserModal] = useState(false);

  const saveUser = (draft: UserDraft) => {
    if (editingUser) {
      setAppUsers((current) => current.map((user) => (user.id === editingUser.id ? { ...user, ...draft } : user)));
      return;
    }
    setAppUsers((current) => [
      ...current,
      {
        id: `U-${String(1001 + current.length).padStart(4, '0')}`,
        ...draft
      }
    ]);
  };

  const openCreate = () => {
    setEditingUser(null);
    setShowUserModal(true);
  };

  const openEdit = (user: UserAccount) => {
    setEditingUser(user);
    setShowUserModal(true);
  };

  const deleteUser = (user: UserAccount) => {
    if (window.confirm(`ลบผู้ใช้ ${user.name} หรือไม่?`)) {
      setAppUsers((current) => current.filter((item) => item.id !== user.id));
    }
  };

  return (
    <StackedPage>
      <SectionCard eyebrow="App Users" title="ผู้ใช้ในแอป" action="+ เพิ่มผู้ใช้" onAction={openCreate}>
        <AdminTable headers={['ผู้ใช้', 'ประเภท', 'ติดต่อ', 'ออเดอร์', 'สถานะ', 'จัดการ']}>
          {appUsers.map((user) => (
            <tr key={user.id}>
              <td><strong>{user.name}</strong><small>{user.id}</small></td>
              <td>{user.role}</td>
              <td>{user.phone}<small>{user.email}</small></td>
              <td>{user.orders}</td>
              <td><StatusBadge status={user.status} /></td>
              <td>
                <div className="row-actions">
                  <Button size="sm" className="primary-glow" onClick={() => openEdit(user)}>แก้ไข</Button>
                  <Button size="sm" variant="outline-light" onClick={() => deleteUser(user)}>ลบ</Button>
                </div>
              </td>
            </tr>
          ))}
        </AdminTable>
      </SectionCard>
      <UserModal
        show={showUserModal}
        user={editingUser}
        onHide={() => setShowUserModal(false)}
        onSave={(draft) => {
          saveUser(draft);
          setShowUserModal(false);
        }}
      />
    </StackedPage>
  );
}

function AdminUserManagement({
  adminUsers,
  onCreateAdmin,
  onToggleAdmin
}: {
  adminUsers: AdminAccount[];
  onCreateAdmin: (draft: AdminUserDraft) => void;
  onToggleAdmin: (admin: AdminAccount) => void;
}) {
  const [showCreate, setShowCreate] = useState(false);
  return (
    <StackedPage>
      <SectionCard eyebrow="Admin Users" title="แอดมินหลังบ้าน" action="+ เพิ่มแอดมิน" onAction={() => setShowCreate(true)}>
        <AdminTable headers={['บัญชี', 'สิทธิ์', 'วันหมดอายุ', 'เข้าใช้ล่าสุด', 'สถานะ', 'จัดการ']}>
          {adminUsers.map((admin) => (
            <tr key={admin.id}>
              <td><strong>{admin.name}</strong><small>{admin.username}</small></td>
              <td>{roleLabels[admin.role]}</td>
              <td>{formatThaiDate(admin.expiresAt)}</td>
              <td>{admin.lastLogin}</td>
              <td><StatusBadge status={admin.active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'} /></td>
              <td><Button size="sm" variant="outline-light" onClick={() => onToggleAdmin(admin)}>{admin.active ? 'ปิดผู้ใช้' : 'เปิดผู้ใช้'}</Button></td>
            </tr>
          ))}
        </AdminTable>
      </SectionCard>
      <CreateAdminModal show={showCreate} onHide={() => setShowCreate(false)} onCreate={onCreateAdmin} />
    </StackedPage>
  );
}

function ReportManagement() {
  const [selectedReport, setSelectedReport] = useState<(typeof reports)[number] | null>(null);
  const visibleReports = reports.filter((report) => !report.type.includes('รีวิว'));

  return (
    <>
      <SectionCard eyebrow="Trust & Safety" title="รายงานปัญหา" action="ดูเคสทั้งหมด">
        <AdminTable headers={['ประเภท', 'รายงานอะไร', 'ข้อมูลที่ถูกรายงาน', 'ผู้แจ้ง', 'สถานะ', 'จัดการ']}>
          {visibleReports.map((report) => (
            <tr key={report.id}>
              <td>{report.type}</td>
              <td><strong>{report.subject}</strong><small>{report.id}</small></td>
              <td>{report.type.includes('สินค้า') ? 'สินค้า P-002' : 'ออเดอร์ NP2026080903'}</td>
              <td>{report.reporter}</td>
              <td><StatusBadge status={report.status} /></td>
              <td><Button size="sm" className="primary-glow" onClick={() => setSelectedReport(report)}>เปิดข้อมูล</Button></td>
            </tr>
          ))}
        </AdminTable>
      </SectionCard>
      <Modal show={Boolean(selectedReport)} onHide={() => setSelectedReport(null)} centered contentClassName="document-modal">
        {selectedReport && (
          <>
            <Modal.Header closeButton><Modal.Title>ข้อมูลที่ถูกรายงาน</Modal.Title></Modal.Header>
            <Modal.Body>
              <div className="report-detail">
                <span className="status-badge warning">{selectedReport.type}</span>
                <h4>{selectedReport.subject}</h4>
                <p>ผู้แจ้ง: {selectedReport.reporter}</p>
                <p>ข้อมูลที่เกี่ยวข้อง: {selectedReport.type.includes('สินค้า') ? 'สินค้า P-002 • Daily Bag Studio' : 'ออเดอร์ NP2026080903 • Home Everyday'}</p>
                <p>สถานะ: {selectedReport.status}</p>
              </div>
            </Modal.Body>
            <Modal.Footer>
              <Button variant="outline-light" onClick={() => setSelectedReport(null)}>ปิด</Button>
              <Button className="primary-glow">รับเรื่องแล้ว</Button>
            </Modal.Footer>
          </>
        )}
      </Modal>
    </>
  );
}

function FinanceManagement({ revenue }: { revenue: number }) {
  return (
    <StackedPage>
      <Row className="g-3">
        <MetricCard label="ยอดขายรวมวันนี้" value={`฿${revenue.toLocaleString('th-TH')}`} change="รวมทุกช่องทาง" icon="cash-stack" />
        <MetricCard label="COD" value="2 ออเดอร์" change="รอโอนยอดร้าน" icon="cash" />
        <MetricCard label="QR พร้อมเพย์" value="1 ออเดอร์" change="ชำระแล้ว" icon="qr-code" />
        <MetricCard label="Mobile Banking" value="1 ออเดอร์" change="ตรวจแล้ว" icon="bank" />
      </Row>
      <SectionCard eyebrow="Payments" title="ช่องทางชำระเงินที่ใช้ในแอป" action="ตั้งค่าช่องทาง">
        <div className="payment-grid">
          {appPayments.map((payment) => <div className="payment-item" key={payment}><i className="bi bi-credit-card" /><strong>{payment}</strong><StatusBadge status="เปิดใช้งาน" /></div>)}
        </div>
      </SectionCard>
    </StackedPage>
  );
}

function SettingsManagement({ isSuperAdmin }: { isSuperAdmin: boolean }) {
  return (
    <StackedPage>
      <SectionCard eyebrow="System Settings" title="ตั้งค่าระบบ" action={isSuperAdmin ? 'บันทึก' : undefined}>
        <Row className="g-3">
          <Col md={6}><SettingsBlock title="หมวดหมู่สินค้า" items={categories} /></Col>
          <Col md={6}><SettingsBlock title="ขนส่ง" items={carriers.map((carrier) => carrier.name)} /></Col>
          <Col md={6}><SettingsBlock title="ช่องทางชำระเงิน" items={appPayments} /></Col>
          <Col md={6}><SettingsBlock title="สิทธิ์แอดมิน" items={Object.values(roleLabels)} /></Col>
        </Row>
      </SectionCard>
      <SectionCard eyebrow="Audit Log" title="ประวัติการทำงานล่าสุด">
        <div className="task-list">
          {['อนุมัติร้าน Daily Bag Studio', 'ขอแก้ไขเอกสาร Home Everyday', 'ปิดสินค้า Tech Corner ที่ถูกรายงาน', 'อัปเดตขนส่ง J&T Express'].map((item, index) => (
            <div className="task-row" key={item}><span>{index + 1}</span><strong>{item}</strong><small>วันนี้</small></div>
          ))}
        </div>
      </SectionCard>
    </StackedPage>
  );
}

function SettingsBlock({ title, items }: { title: string; items: string[] }) {
  return (
    <div className="settings-block">
      <h4>{title}</h4>
      {items.map((item) => <span key={item}>{item}</span>)}
    </div>
  );
}

function UserModal({
  show,
  user,
  onHide,
  onSave
}: {
  show: boolean;
  user: UserAccount | null;
  onHide: () => void;
  onSave: (draft: UserDraft) => void;
}) {
  const [draft, setDraft] = useState<UserDraft>({
    name: '',
    role: 'ลูกค้า',
    phone: '',
    email: '',
    status: 'ใช้งานอยู่',
    orders: 0
  });

  const fillFromUser = () => {
    if (!user) {
      setDraft({ name: '', role: 'ลูกค้า', phone: '', email: '', status: 'ใช้งานอยู่', orders: 0 });
      return;
    }
    setDraft({
      name: user.name,
      role: user.role,
      phone: user.phone,
      email: user.email,
      status: user.status,
      orders: user.orders
    });
  };

  return (
    <Modal show={show} onShow={fillFromUser} onHide={onHide} centered contentClassName="document-modal">
      <Modal.Header closeButton><Modal.Title>{user ? 'แก้ไขผู้ใช้' : 'เพิ่มผู้ใช้'}</Modal.Title></Modal.Header>
      <Modal.Body>
        <Row className="g-3">
          <Col md={6}>
            <Form.Group><Form.Label>ชื่อผู้ใช้</Form.Label><Form.Control value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group><Form.Label>ประเภท</Form.Label><Form.Select value={draft.role} onChange={(event) => setDraft({ ...draft, role: event.target.value as UserDraft['role'] })}><option>ลูกค้า</option><option>ผู้ขาย</option></Form.Select></Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group><Form.Label>เบอร์ติดต่อ</Form.Label><Form.Control value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group><Form.Label>Email</Form.Label><Form.Control value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group><Form.Label>สถานะ</Form.Label><Form.Select value={draft.status} onChange={(event) => setDraft({ ...draft, status: event.target.value as UserStatus })}><option>ใช้งานอยู่</option><option>รอตรวจสอบ</option><option>ระงับชั่วคราว</option></Form.Select></Form.Group>
          </Col>
          <Col md={6}>
            <Form.Group><Form.Label>จำนวนออเดอร์</Form.Label><Form.Control type="number" min={0} value={draft.orders} onChange={(event) => setDraft({ ...draft, orders: Number(event.target.value) })} /></Form.Group>
          </Col>
        </Row>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="outline-light" onClick={onHide}>ยกเลิก</Button>
        <Button className="primary-glow" onClick={() => onSave(draft)} disabled={!draft.name || !draft.phone}>บันทึก</Button>
      </Modal.Footer>
    </Modal>
  );
}

function CreateAdminModal({
  show,
  onHide,
  onCreate
}: {
  show: boolean;
  onHide: () => void;
  onCreate: (draft: AdminUserDraft) => void;
}) {
  const [draft, setDraft] = useState<AdminUserDraft>({
    username: '',
    name: '',
    role: 'shop_approver',
    expiresAt: '2027-12-31',
    active: true
  });

  return (
    <Modal show={show} onHide={onHide} centered contentClassName="document-modal">
      <Modal.Header closeButton><Modal.Title>สร้างผู้ใช้งานแอดมิน</Modal.Title></Modal.Header>
      <Modal.Body>
        <Form.Group className="mb-3"><Form.Label>Username</Form.Label><Form.Control value={draft.username} onChange={(event) => setDraft({ ...draft, username: event.target.value })} /></Form.Group>
        <Form.Group className="mb-3"><Form.Label>ชื่อผู้ใช้งาน</Form.Label><Form.Control value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Form.Group>
        <Form.Group className="mb-3"><Form.Label>สิทธิ์</Form.Label><Form.Select value={draft.role} onChange={(event) => setDraft({ ...draft, role: event.target.value as AdminRole })}>{Object.entries(roleLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</Form.Select></Form.Group>
        <Form.Group className="mb-3"><Form.Label>วันหมดอายุ</Form.Label><Form.Control type="date" value={draft.expiresAt} onChange={(event) => setDraft({ ...draft, expiresAt: event.target.value })} /></Form.Group>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="outline-light" onClick={onHide}>ยกเลิก</Button>
        <Button className="primary-glow" onClick={() => { onCreate(draft); onHide(); }}>สร้างผู้ใช้งาน</Button>
      </Modal.Footer>
    </Modal>
  );
}

function DocumentReviewModal({
  shop,
  onHide,
  onApprove,
  onRequestFix
}: {
  shop: ShopRecord | null;
  onHide: () => void;
  onApprove: (shop: ShopRecord) => void;
  onRequestFix: (shop: ShopRecord) => void;
}) {
  return (
    <Modal show={Boolean(shop)} onHide={onHide} centered size="xl" contentClassName="document-modal">
      {shop && (
        <>
          <Modal.Header closeButton><Modal.Title>ตรวจเอกสารเปิดร้าน</Modal.Title></Modal.Header>
          <Modal.Body>
            <Row className="g-3">
              <Col lg={4}>
                <div className="identity-panel">
                  <span className="queue-logo">{shop.shopName.slice(0, 2)}</span>
                  <h4>{shop.shopName}</h4>
                  <p>{shop.category} • {shop.province}</p>
                  <dl>
                    <div><dt>ผู้ขอเปิดร้าน</dt><dd>{shop.owner}</dd></div>
                    <div><dt>เบอร์ติดต่อ</dt><dd>{shop.phone}</dd></div>
                    <div><dt>เลขบัตร 4 ตัวท้าย</dt><dd>**** {shop.identityLast4}</dd></div>
                    <div><dt>บัญชีรับเงิน</dt><dd>{shop.bankName} • **** {shop.bankAccountLast4}</dd></div>
                  </dl>
                  <p className="security-note">ข้อมูลนี้เปิดดูได้เฉพาะผู้มีสิทธิ์อนุมัติร้านค้าเท่านั้น</p>
                </div>
              </Col>
              <Col lg={8}>
                <div className="document-grid">
                  {shop.documents.map((document) => (
                    <article className="document-card" key={document.type}>
                      <div className="document-preview"><i className="bi bi-file-earmark-image" aria-hidden /><span>{document.type}</span></div>
                      <div className="document-copy"><div><h5>{document.type}</h5><p>{document.fileName}</p></div><StatusBadge status={document.status} /></div>
                      <dl className="document-meta"><div><dt>อัปโหลด</dt><dd>{document.uploadedAt}</dd></div><div><dt>หมายเหตุ</dt><dd>{document.note}</dd></div></dl>
                      <div className="document-actions"><Button variant="outline-light" size="sm">เปิดดูไฟล์</Button><Button variant="outline-light" size="sm">ดาวน์โหลด</Button></div>
                    </article>
                  ))}
                </div>
              </Col>
            </Row>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="outline-light" onClick={() => onRequestFix(shop)}>ขอให้แก้ไขเอกสาร</Button>
            <Button className="primary-glow" onClick={() => onApprove(shop)}>เอกสารครบ อนุมัติร้าน</Button>
          </Modal.Footer>
        </>
      )}
    </Modal>
  );
}

function SectionCard({
  eyebrow,
  title,
  action,
  onAction,
  children
}: {
  eyebrow: string;
  title: string;
  action?: string;
  onAction?: () => void;
  children: ReactNode;
}) {
  return (
    <Card className="glass-card table-card">
      <Card.Body>
        <div className="section-heading">
          <div><p className="eyebrow">{eyebrow}</p><h3>{title}</h3></div>
          {action && <Button className="primary-glow" onClick={onAction}>{action}</Button>}
        </div>
        {children}
      </Card.Body>
    </Card>
  );
}

function StackedPage({ children }: { children: ReactNode }) {
  return <div className="stacked-page">{children}</div>;
}

function SummaryPills({ items }: { items: Array<[string, number]> }) {
  return (
    <div className="summary-pills">
      {items.map(([label, value]) => <div key={label}><strong>{value}</strong><span>{label}</span></div>)}
    </div>
  );
}

function AdminTable({ headers, children }: { headers: string[]; children: ReactNode }) {
  return (
    <Table responsive borderless className="admin-table">
      <thead><tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr></thead>
      <tbody>{children}</tbody>
    </Table>
  );
}

function StatusBadge({ status }: { status: string }) {
  const className = status.includes('เปิด') || status.includes('ครบ') || status.includes('สำเร็จ') || status.includes('แสดงผล') || status.includes('ใช้งาน')
    ? 'success'
    : status.includes('รอ') || status.includes('กำลัง') || status.includes('ต้องตรวจ')
      ? 'warning'
      : 'danger';
  return <span className={`status-badge ${className}`}>{status}</span>;
}

function formatThaiDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' });
}
