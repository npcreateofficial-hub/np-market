// ignore_for_file: prefer_const_literals_to_create_immutables, unnecessary_const

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'supabase_market_api.dart';

const appBg = Color(0xFFFFFFFF);
const surface = Colors.white;
const ink = Color(0xFF26191B);
const muted = Color(0xFF826B70);
const line = Color(0xFFF0C9CE);
const accent = Color(0xFF9F1118);
const accentDark = Color(0xFF7F090E);
const softAccent = Color(0xFFFFEEF0);

void main() {
  runApp(const NpMarketApp());
}

final appStore = AppStore();

const shopeeProductCategories = [
  'ความงามและของใช้ส่วนตัว',
  'กลุ่มผลิตภัณฑ์เพื่อสุขภาพ',
  'เสื้อผ้าแฟชั่นผู้ชาย',
  'เสื้อผ้าแฟชั่นผู้หญิง',
  'กระเป๋า',
  'รองเท้าผู้ชาย',
  'รองเท้าผู้หญิง',
  'เครื่องประดับ',
  'นาฬิกาและแว่นตา',
  'เครื่องใช้ในบ้าน',
  'อุปกรณ์อิเล็กทรอนิกส์',
  'มือถือ และ แท็บเล็ต',
  'เครื่องใช้ไฟฟ้าภายในบ้าน',
  'คอมพิวเตอร์และแล็ปท็อป',
  'กล้องและอุปกรณ์ถ่ายภาพ',
  'อาหารและเครื่องดื่ม',
  'ของเล่น สินค้าแม่และเด็ก',
  'กีฬาและกิจกรรมกลางแจ้ง',
  'สัตว์เลี้ยง',
  'เกมและอุปกรณ์เสริม',
  'ยานยนต์',
  'เครื่องเขียน หนังสือ และงานอดิเรก',
  'ตั๋วและบัตรกำนัล',
  'ช้อปปี้เพย์ใกล้ตัว',
];

List<Product> get marketplaceProducts => [
      ...appStore.sellerProducts,
      ...appStore.remoteProducts,
    ];

class AppStore extends ChangeNotifier {
  final List<CartItem> _cartItems = [];
  final List<Order> _orders = [];
  final List<Product> _remoteProducts = [];
  final List<Product> _sellerProducts = [];
  final Map<String, String> _sellerProductStatuses = {};
  final Set<String> _reviewedOrderIds = {};
  CustomerAccount? _customerAccount;
  CustomerSession? _customerSession;
  bool _isAuthBusy = false;
  bool _isSellerWorkspaceLoading = false;
  SellerProfile? _sellerProfile;
  final List<Address> _addresses = [];
  String _selectedAddressId = '';

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  List<Order> get orders => List.unmodifiable(_orders);
  List<Product> get remoteProducts => List.unmodifiable(_remoteProducts);
  List<Product> get sellerProducts => List.unmodifiable(_sellerProducts);
  CustomerAccount? get customerAccount => _customerAccount;
  CustomerSession? get customerSession => _customerSession;
  bool get isSignedIn => _customerSession != null;
  bool get isAuthenticated => _customerSession != null;
  bool get isAuthBusy => _isAuthBusy;
  bool isOrderReviewed(Order order) => _reviewedOrderIds.contains(order.id);
  String sellerProductStatus(Product product) =>
      _sellerProductStatuses[product.id] ??
      (product.stock <= 0 ? 'หมดสต๊อก' : 'กำลังขาย');
  SellerProfile? get sellerProfile => _sellerProfile;
  bool get hasSellerShop => _sellerProfile != null;
  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress {
    if (_addresses.isEmpty) return null;
    return _addresses.firstWhere(
      (address) => address.id == _selectedAddressId,
      orElse: () => _addresses.first,
    );
  }

  int get cartCount =>
      _cartItems.fold(0, (total, item) => total + item.quantity);

  int get notificationCount {
    var count = _orders.length;
    final shop = _sellerProfile;
    if (shop != null) count += 1;
    return count;
  }

  double get cartTotal =>
      _cartItems.fold(0, (total, item) => total + item.total);

  Future<void> signInCustomer({
    required String email,
    required String password,
  }) async {
    _setAuthBusy(true);
    try {
      final api = const SupabaseMarketApi();
      final session = await api.signInCustomer(
        email: email,
        password: password,
      );
      var profile = await api.fetchCustomerProfile(
        session: session,
        email: session.email.isEmpty ? email : session.email,
      );
      if (!profile.hasProfile) {
        final fallbackName = email.trim().split('@').first;
        await api.upsertCustomerProfile(
          session: session,
          email: email,
          displayName: fallbackName,
          phone: '',
        );
        profile = CustomerAccount(
          id: session.userId,
          email: session.email.isEmpty ? email : session.email,
          displayName: fallbackName,
          phone: '',
        );
      }
      var orders = const <Order>[];
      try {
        orders = await api.fetchOrders(accessToken: session.accessToken);
      } catch (_) {
        orders = const <Order>[];
      }
      _customerSession = session;
      _customerAccount = profile;
      _orders
        ..clear()
        ..addAll(orders);
      await loadSellerWorkspace();
      notifyListeners();
    } finally {
      _setAuthBusy(false);
    }
  }

  Future<void> registerCustomer({
    required String displayName,
    required String phone,
    required String email,
    required String password,
  }) async {
    _setAuthBusy(true);
    try {
      final api = const SupabaseMarketApi();
      final session = await api.registerCustomer(
        displayName: displayName,
        phone: phone,
        email: email,
        password: password,
      );
      _customerSession = session;
      _customerAccount = CustomerAccount(
        id: session.userId,
        email: session.email.isEmpty ? email : session.email,
        displayName:
            displayName.trim().isEmpty ? email.trim() : displayName.trim(),
        phone: phone.trim(),
      );
      _orders.clear();
      await loadSellerWorkspace();
      notifyListeners();
    } finally {
      _setAuthBusy(false);
    }
  }

  void signOutCustomer() {
    _customerSession = null;
    _customerAccount = null;
    _cartItems.clear();
    _orders.clear();
    _sellerProfile = null;
    _sellerProducts.clear();
    _sellerProductStatuses.clear();
    notifyListeners();
  }

  void _setAuthBusy(bool value) {
    _isAuthBusy = value;
    notifyListeners();
  }

  Future<void> loadRemoteCatalog() async {
    if (!isSupabaseEnabled || _remoteProducts.isNotEmpty) return;
    try {
      final products = await const SupabaseMarketApi().fetchProducts();
      if (products.isEmpty) return;
      _remoteProducts
        ..clear()
        ..addAll(products);
      notifyListeners();
    } catch (_) {
      // Remote catalog stays empty when Supabase is unavailable.
    }
  }

  void addToCart(CartItem item) {
    final index = _cartItems.indexWhere(
      (cartItem) =>
          cartItem.product.id == item.product.id &&
          cartItem.color == item.color &&
          cartItem.size == item.size,
    );
    if (index >= 0) {
      _cartItems[index] = _cartItems[index].copyWith(
        quantity: _cartItems[index].quantity + item.quantity,
      );
    } else {
      _cartItems.add(item);
    }
    notifyListeners();
  }

  void updateQuantity(CartItem item, int quantity) {
    final index = _cartItems.indexOf(item);
    if (index < 0) return;
    if (quantity <= 0) {
      _cartItems.removeAt(index);
    } else {
      _cartItems[index] =
          item.copyWith(quantity: quantity.clamp(1, item.product.stock));
    }
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void selectAddress(Address address) {
    _selectedAddressId = address.id;
    notifyListeners();
  }

  void addAddress(Address address, {bool makeDefault = false}) {
    if (makeDefault) {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
    _addresses.add(address.copyWith(isDefault: makeDefault));
    _selectedAddressId = address.id;
    notifyListeners();
  }

  void updateAddress(Address address, {bool makeDefault = false}) {
    final index = _addresses.indexWhere((item) => item.id == address.id);
    if (index < 0) return;
    if (makeDefault) {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
    _addresses[index] = address.copyWith(
      isDefault: makeDefault || _addresses[index].isDefault,
    );
    _selectedAddressId = address.id;
    notifyListeners();
  }

  Future<void> loadSellerWorkspace() async {
    if (!isSupabaseEnabled || _customerSession == null) return;
    if (_isSellerWorkspaceLoading) return;
    _isSellerWorkspaceLoading = true;
    try {
      final api = const SupabaseMarketApi();
      final shop = await api.fetchMyShop(session: _customerSession!);
      _sellerProfile = shop;
      _sellerProducts.clear();
      notifyListeners();
      if (shop != null) {
        try {
          final products =
              await api.fetchSellerProducts(session: _customerSession!);
          _sellerProducts.addAll(products);
        } catch (_) {
          // Shop status is still the source of truth even if product loading fails.
        }
        try {
          final sellerOrders =
              await api.fetchSellerOrders(session: _customerSession!);
          for (final sellerOrder in sellerOrders) {
            final index =
                _orders.indexWhere((order) => order.id == sellerOrder.id);
            if (index >= 0) {
              _orders[index] = sellerOrder;
            } else {
              _orders.add(sellerOrder);
            }
          }
        } catch (_) {
          // Seller center can open before order tables are ready.
        }
      }
      notifyListeners();
    } catch (_) {
      // Keep local seller state usable when Supabase is not ready yet.
    } finally {
      _isSellerWorkspaceLoading = false;
    }
  }

  Future<void> openSellerShop(
    SellerProfile profile, {
    String identityCardUrl = '',
    String bankBookUrl = '',
    String identityCardPath = '',
    String bankBookPath = '',
  }) async {
    if (isSupabaseEnabled && _customerSession != null) {
      _sellerProfile = await const SupabaseMarketApi().createOrUpdateShop(
        session: _customerSession!,
        profile: profile,
        identityCardUrl: identityCardUrl,
        bankBookUrl: bankBookUrl,
        identityCardPath: identityCardPath,
        bankBookPath: bankBookPath,
      );
    } else {
      _sellerProfile = profile;
    }
    notifyListeners();
  }

  Future<UploadedShopFile> uploadSellerFile({
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled || _customerSession == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนแนบไฟล์');
    }
    return const SupabaseMarketApi().uploadShopFile(
      session: _customerSession!,
      kind: kind,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadProductMedia({
    required String shopId,
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled || _customerSession == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนแนบไฟล์สินค้า');
    }
    return const SupabaseMarketApi().uploadProductMedia(
      session: _customerSession!,
      shopId: shopId,
      kind: kind,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<void> updateCustomerAvatar({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled || _customerSession == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนเพิ่มรูปโปรไฟล์');
    }
    final updated = await const SupabaseMarketApi().updateCustomerAvatar(
      session: _customerSession!,
      email: _customerAccount?.email ?? _customerSession!.email,
      fileName: fileName,
      bytes: bytes,
    );
    _customerAccount = updated;
    notifyListeners();
  }

  Future<void> addSellerProduct(
    Product product, {
    String description = '',
    String sku = '',
    double weightKg = 0,
    String parcelSize = '',
  }) async {
    var savedProduct = product;
    if (isSupabaseEnabled &&
        _customerSession != null &&
        _sellerProfile != null &&
        _sellerProfile!.id.isNotEmpty) {
      savedProduct = await const SupabaseMarketApi().createSellerProduct(
        session: _customerSession!,
        shop: _sellerProfile!,
        product: product,
        description: description,
        sku: sku,
        weightKg: weightKg,
        parcelSize: parcelSize,
      );
      _remoteProducts.clear();
      await loadRemoteCatalog();
    }
    _sellerProducts.insert(0, savedProduct);
    _sellerProductStatuses[savedProduct.id] =
        product.stock <= 0 ? 'หมดสต๊อก' : 'กำลังขาย';
    notifyListeners();
  }

  Future<void> updateSellerProduct(
    Product product, {
    String description = '',
    String sku = '',
    double weightKg = 0,
    String parcelSize = '',
  }) async {
    var savedProduct = product;
    if (isSupabaseEnabled &&
        _customerSession != null &&
        _sellerProfile != null &&
        _sellerProfile!.id.isNotEmpty) {
      savedProduct = await const SupabaseMarketApi().updateSellerProduct(
        session: _customerSession!,
        shop: _sellerProfile!,
        product: product,
        description: description,
        sku: sku,
        weightKg: weightKg,
        parcelSize: parcelSize,
      );
      _remoteProducts.clear();
      await loadRemoteCatalog();
    }
    final index = _sellerProducts.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _sellerProducts[index] = savedProduct;
    } else {
      _sellerProducts.insert(0, savedProduct);
    }
    _sellerProductStatuses[savedProduct.id] =
        savedProduct.stock <= 0 ? 'หมดสต็อก' : 'กำลังขาย';
    notifyListeners();
  }

  Future<void> deleteSellerProduct(Product product) async {
    if (isSupabaseEnabled &&
        _customerSession != null &&
        product.id.isNotEmpty) {
      await const SupabaseMarketApi().deleteSellerProduct(
        session: _customerSession!,
        productId: product.id,
      );
      _remoteProducts.clear();
      await loadRemoteCatalog();
    }
    _sellerProducts.removeWhere((item) => item.id == product.id);
    _sellerProductStatuses.remove(product.id);
    notifyListeners();
  }

  void updateSellerProductStatus(Product product, String status) {
    _sellerProductStatuses[product.id] = status;
    notifyListeners();
  }

  Future<void> updateOrderShipping({
    required String orderId,
    required String status,
    String? carrier,
    String? trackingNumber,
  }) async {
    if (isSupabaseEnabled && _customerSession != null) {
      try {
        final updated =
            await const SupabaseMarketApi().updateSellerOrderShipment(
          session: _customerSession!,
          orderNo: orderId,
          carrier: carrier ?? '',
          trackingNumber: trackingNumber ?? '',
          status: status,
        );
        if (updated != null) {
          final updatedIndex =
              _orders.indexWhere((order) => order.id == updated.id);
          if (updatedIndex >= 0) {
            _orders[updatedIndex] = updated;
          }
          notifyListeners();
          return;
        }
      } catch (_) {
        // Fall back to local update so the seller can keep moving in demo mode.
      }
    }
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return;
    _orders[index] = _orders[index].copyWith(
      status: status,
      carrier: carrier,
      trackingNumber: trackingNumber,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void markOrderReviewed(Order order) {
    _reviewedOrderIds.add(order.id);
    notifyListeners();
  }

  Future<Order> createOrder(List<CartItem> items, String paymentMethod) async {
    final checkoutAddress = selectedAddress;
    if (checkoutAddress == null) {
      throw StateError('กรุณาเพิ่มที่อยู่จัดส่งก่อนสั่งซื้อ');
    }
    if (isSupabaseEnabled &&
        items.every((item) => item.product.shopId.isNotEmpty)) {
      final session = _customerSession;
      if (session == null) {
        throw StateError('กรุณาเข้าสู่ระบบก่อนสั่งซื้อ');
      }
      final orders = await const SupabaseMarketApi().createCheckoutOrders(
        items: items,
        address: checkoutAddress,
        paymentMethod: paymentMethod,
        session: session,
      );
      if (orders.isNotEmpty) {
        _orders.insertAll(0, orders);
        for (final item in items) {
          _cartItems.remove(item);
        }
        notifyListeners();
        return orders.first;
      }
    }

    final order = Order(
      id: 'NP${DateTime.now().millisecondsSinceEpoch}',
      items: List.unmodifiable(items),
      address: checkoutAddress.fullAddress,
      paymentMethod: paymentMethod,
      status: 'รอร้านยืนยัน',
      createdAt: DateTime.now(),
      carrier: 'ยังไม่ได้เลือกขนส่ง',
      trackingNumber: '',
    );
    _orders.insert(0, order);
    for (final item in items) {
      _cartItems.remove(item);
    }
    notifyListeners();
    return order;
  }
}

class NpMarketApp extends StatelessWidget {
  const NpMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NP Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          primary: accent,
          surface: surface,
          secondary: accentDark,
        ),
        scaffoldBackgroundColor: appBg,
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          backgroundColor: surface,
          indicatorColor: softAccent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? accent : muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accent : muted,
            ),
          ),
        ),
      ),
      home: const MarketplaceShell(),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/home': (_) => const MarketplaceShell(),
        '/search': (_) => const SearchScreen(),
        '/cart': (_) => const CartScreen(),
        '/orders': (_) => const AuthRequiredScreen(child: OrdersScreen()),
        '/seller': (_) => const AuthRequiredScreen(child: SellerCenterScreen()),
        '/seller/add-product': (_) =>
            const AuthRequiredScreen(child: SellerProductFormScreen()),
        '/seller/orders': (_) =>
            const AuthRequiredScreen(child: SellerOrdersScreen()),
        '/seller/products': (_) =>
            const AuthRequiredScreen(child: SellerProductsScreen()),
        '/seller/settings': (_) =>
            const AuthRequiredScreen(child: OpenShopScreen()),
        '/seller/shipping': (_) =>
            const AuthRequiredScreen(child: SellerShippingSettingsScreen()),
        '/seller/delivery': (_) =>
            const AuthRequiredScreen(child: SellerDeliveryScreen()),
        '/seller/balance': (_) =>
            const AuthRequiredScreen(child: SellerBalanceScreen()),
        '/seller/income': (_) => const SellerSimpleScreen(
              title: 'รายรับของฉัน',
              icon: Icons.account_balance_outlined,
              message:
                  'สรุปรายรับจากออเดอร์สำเร็จ รายการรอโอน และประวัติถอนเงินของร้าน',
            ),
        '/seller/rating': (_) => const SellerSimpleScreen(
              title: 'คะแนนร้านค้า',
              icon: Icons.star_border,
              message:
                  'ดูคะแนนร้าน รีวิวสินค้า อัตราการตอบแชท และคุณภาพบริการหลังการขาย',
            ),
        '/seller/stats': (_) => const SellerSimpleScreen(
              title: 'สถิติร้านค้าของฉัน',
              icon: Icons.trending_up_outlined,
              message:
                  'ดูยอดเข้าชมสินค้า ยอดขาย อัตราการสั่งซื้อ และสินค้าที่ทำผลงานดีที่สุด',
            ),
        '/seller/assistant': (_) => const SellerSimpleScreen(
              title: 'ผู้ช่วยการขาย',
              icon: Icons.sell_outlined,
              message:
                  'รวมคำแนะนำการเพิ่มสินค้า โปรโมชัน การตอบแชท และงานที่ร้านควรทำต่อ',
            ),
        '/seller/help': (_) => const SellerSimpleScreen(
              title: 'ศูนย์ช่วยเหลือร้านค้า',
              icon: Icons.help_outline,
              message:
                  'คู่มือเปิดร้าน ลงสินค้า จัดส่งสินค้า คืนเงิน และการใช้งานระบบร้านค้า',
            ),
        '/me/addresses': (_) =>
            const AuthRequiredScreen(child: AddressSelectionScreen()),
        '/payment-methods': (_) =>
            const AuthRequiredScreen(child: PaymentMethodsScreen()),
        '/me/vouchers': (_) => const MeSubPage(
              title: 'คูปองของฉัน',
              icon: Icons.confirmation_number_outlined,
              message:
                  'รวมคูปองร้านค้า คูปองส่วนลด และโค้ดส่งฟรีที่ผู้ใช้เก็บไว้',
            ),
        '/me/favorites': (_) => const MeSubPage(
              title: 'สินค้าที่ถูกใจ',
              icon: Icons.favorite_border,
              message:
                  'รายการสินค้าที่ผู้ใช้กดถูกใจ เพื่อกลับมาดูหรือซื้อภายหลัง',
            ),
        '/me/reviews': (_) => const MeSubPage(
              title: 'รีวิวของฉัน',
              icon: Icons.rate_review_outlined,
              message:
                  'สินค้าที่รอให้คะแนน รีวิวที่เขียนแล้ว และรูปภาพ/วิดีโอรีวิว',
            ),
        '/me/chat': (_) => const MeSubPage(
              title: 'แชท',
              icon: Icons.chat_bubble_outline,
              message:
                  'กล่องข้อความระหว่างผู้ซื้อกับร้านค้า สำหรับถามสินค้าและติดตามคำสั่งซื้อ',
            ),
        '/me/notifications': (_) =>
            const AuthRequiredScreen(child: NotificationsScreen()),
        '/me/profile': (_) =>
            const AuthRequiredScreen(child: AccountProfileScreen()),
        '/me/returns': (_) => const MeSubPage(
              title: 'คืนสินค้า/คืนเงิน',
              icon: Icons.assignment_return_outlined,
              message: 'ติดตามคำขอคืนสินค้า คืนเงิน และหลักฐานประกอบรายการ',
            ),
        '/me/help': (_) => const MeSubPage(
              title: 'ศูนย์ช่วยเหลือ',
              icon: Icons.support_agent,
              message:
                  'คำถามที่พบบ่อย วิธีสั่งซื้อ การชำระเงิน การจัดส่ง และการติดต่อทีมช่วยเหลือ',
            ),
        '/me/settings': (_) => const AccountSettingsScreen(),
        '/me/campaigns': (_) => const MeSubPage(
              title: 'โปรโมชันและแคมเปญ',
              icon: Icons.campaign_outlined,
              message: 'รวมแคมเปญ ส่วนลด และกิจกรรมพิเศษของ NP Market',
            ),
        '/me/e-service': (_) => const MeSubPage(
              title: 'E-Service / E-Voucher',
              icon: Icons.phone_android_outlined,
              message: 'บริการดิจิทัล คูปองอิเล็กทรอนิกส์ และรายการบริการเสริม',
            ),
        '/me/affiliate': (_) => const MeSubPage(
              title: 'โปรแกรม Affiliate',
              icon: Icons.card_giftcard_outlined,
              message: 'พื้นที่สำหรับระบบแนะนำสินค้าและค่าคอมมิชชันในอนาคต',
            ),
        '/me/recent': (_) => const MeSubPage(
              title: 'ดูล่าสุด',
              icon: Icons.history_outlined,
              message:
                  'สินค้าที่ผู้ใช้เคยเปิดดู เพื่อกลับมาซื้อหรือตรวจสอบภายหลัง',
            ),
      },
    );
  }
}

Future<bool> requireCustomerLogin(BuildContext context) async {
  if (appStore.isAuthenticated) return true;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const AuthScreen(popOnSuccess: true)),
  );
  return result == true || appStore.isAuthenticated;
}

class AuthRequiredScreen extends StatelessWidget {
  const AuthRequiredScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        if (appStore.isAuthenticated) return child;
        return Scaffold(
          backgroundColor: const Color(0xFFF6F6F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: ink,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: ink),
                  const SizedBox(height: 18),
                  const Text(
                    'เข้าสู่ระบบเพื่อใช้งาน',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ดูออเดอร์ ชำระเงิน และเปิดร้านได้หลังเข้าสู่ระบบ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => requireCustomerLogin(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('เข้าสู่ระบบ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        return appStore.isSignedIn
            ? const MarketplaceShell()
            : const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.popOnSuccess = false});

  final bool popOnSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegister = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!isSupabaseEnabled) {
      _showError('ยังไม่สามารถเชื่อมต่อได้');
      return;
    }

    try {
      if (_isRegister) {
        await appStore.registerCustomer(
          displayName: _nameController.text,
          phone: '',
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await appStore.signInCustomer(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      if (widget.popOnSuccess) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyAuthError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: accent),
    );
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString().replaceFirst('Bad state: ', '');
    if (raw.contains('Invalid login credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (raw.contains('User already registered')) {
      return 'อีเมลนี้สมัครไว้แล้ว ลองกดเข้าสู่ระบบ';
    }
    if (raw.contains('email confirmation')) {
      return 'สมัครแล้ว กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(34, 12, 34, 26),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(false);
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home',
                          (route) => false,
                        );
                      }
                    },
                    child: const Text(
                      'ข้าม',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NP Market',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  _isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegister ? 'สร้างบัญชีใหม่' : 'ยินดีต้อนรับกลับ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA8A8A8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                if (_isRegister) ...[
                  AuthTextField(
                    controller: _nameController,
                    icon: Icons.person_outline,
                    label: 'ชื่อ',
                    hint: '',
                    autofillHints: const [AutofillHints.name],
                    validator: (value) =>
                        value.trim().isEmpty ? 'กรุณาใส่ชื่อ' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                AuthTextField(
                  controller: _emailController,
                  icon: Icons.mail_outline,
                  label: 'อีเมล',
                  hint: '',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    final text = value.trim();
                    if (text.isEmpty) return 'กรุณาใส่อีเมล';
                    if (!text.contains('@')) return 'อีเมลไม่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  label: 'รหัสผ่าน',
                  hint: '',
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF8C8C8C),
                    ),
                  ),
                  validator: (value) =>
                      value.length < 8 ? 'รหัสผ่านอย่างน้อย 8 ตัวอักษร' : null,
                ),
                if (_isRegister) ...[
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    icon: Icons.lock_outline,
                    label: 'ยืนยันรหัสผ่าน',
                    hint: '',
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8C8C8C),
                      ),
                    ),
                    validator: (value) =>
                        value != _passwordController.text.trim()
                            ? 'รหัสผ่านไม่ตรงกัน'
                            : null,
                  ),
                ],
                if (!_isRegister) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: appStore.isAuthBusy ? null : () {},
                    child: const Text(
                      'ลืมรหัสผ่าน?',
                      style: TextStyle(
                        color: Color(0xFFB7B7B7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: appStore,
                  builder: (context, _) {
                    final busy = appStore.isAuthBusy;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFF262626),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                _isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                Center(
                  child: TextButton(
                    onPressed: appStore.isAuthBusy
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                          : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                      style: const TextStyle(
                        color: Color(0xFFB7B7B7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.autofillHints,
    this.validator,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final String? Function(String value)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      cursorColor: Colors.white,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFFBDBDBD), size: 21),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 58,
        ),
        suffixIcon: suffixIcon,
        hintText: label,
        labelText: null,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: Colors.black,
        isDense: true,
        constraints: const BoxConstraints(minHeight: 58),
        hintStyle: const TextStyle(
          color: Color(0xFF8D8688),
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 19, 14, 19),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF3D3D3D), width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.white70, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: accent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
      validator: (value) => validator?.call(value?.trim() ?? ''),
    );
  }
}

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key});

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell>
    with WidgetsBindingObserver {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appStore.addListener(_onStoreChanged);
    appStore.loadRemoteCatalog();
    appStore.loadSellerWorkspace();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && appStore.isSignedIn) {
      appStore.loadSellerWorkspace();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationCount = appStore.notificationCount;
    final pages = const [
      HomeScreen(),
      PlaceholderPage(
        title: 'ดีลพิเศษ',
        message: 'รวมแคมเปญ คูปอง และส่วนลดประจำวัน',
        icon: Icons.local_offer_outlined,
      ),
      PlaceholderPage(
        title: 'Mall',
        message: 'ร้านค้าแนะนำและร้านที่ผ่านการตรวจสอบ',
        icon: Icons.store_mall_directory_outlined,
      ),
      PlaceholderPage(
        title: 'Video',
        message: 'วิดีโอสินค้า รีวิวสินค้า และฟีดสั้นจากร้านค้า',
        icon: Icons.play_circle_outline,
      ),
      NotificationsScreen(),
      MeScreen(),
    ];
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) async {
          if (index == 4 && !await requireCustomerLogin(context)) return;
          if (index == 4 || index == 5) {
            appStore.loadSellerWorkspace();
          }
          setState(() => selectedIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'หน้าแรก',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'ดีลพิเศษ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.store_mall_directory_outlined),
            selectedIcon: Icon(Icons.store_mall_directory),
            label: 'Mall',
          ),
          const NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Video',
          ),
          NavigationDestination(
            icon: NotificationNavIcon(count: notificationCount),
            selectedIcon:
                NotificationNavIcon(count: notificationCount, selected: true),
            label: 'แจ้งเตือน',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'ฉัน',
          ),
        ],
      ),
    );
  }
}

class NotificationNavIcon extends StatelessWidget {
  const NotificationNavIcon({
    super.key,
    required this.count,
    this.selected = false,
  });

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      isLabelVisible: count > 0,
      count: count > 99 ? 99 : count,
      backgroundColor: accent,
      child: Icon(selected ? Icons.notifications : Icons.notifications_none),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: StickySearchHeader(),
          ),
          const SliverToBoxAdapter(child: HomeHeader()),
          SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: QuickMenuGrid()),
          SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: SectionHeader(
                title: 'โปรโมชันวันนี้', actionLabel: 'ดูทั้งหมด'),
          ),
          SliverToBoxAdapter(child: TwinFeatureBlocks()),
          SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child:
                SectionHeader(title: 'ร้านค้าแนะนำ', actionLabel: 'ดูร้านค้า'),
          ),
          SliverToBoxAdapter(child: ShopStrip(shops: recommendedShops)),
          SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: SectionHeader(title: 'สินค้าแนะนำ', actionLabel: 'ดูเพิ่ม'),
          ),
          ProductGrid(products: marketplaceProducts),
          SliverPadding(padding: EdgeInsets.only(bottom: 18)),
        ],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: const BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: const HeaderShortcutStrip(),
    );
  }
}

class StickySearchHeader extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: accent,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: const HeaderToolbar(),
    );
  }

  @override
  bool shouldRebuild(covariant StickySearchHeader oldDelegate) {
    return false;
  }
}

class HeaderToolbar extends StatelessWidget {
  const HeaderToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SearchBarButton()),
        const SizedBox(width: 10),
        HeaderIconButton(
          icon: Icons.shopping_cart_outlined,
          tooltip: 'ตะกร้า',
          inverted: true,
          onTap: () => Navigator.of(context).pushNamed('/cart'),
        ),
        const SizedBox(width: 8),
        const HeaderIconButton(
          icon: Icons.chat_bubble_outline,
          tooltip: 'แชท',
          inverted: true,
        ),
      ],
    );
  }
}

class HeaderShortcutStrip extends StatelessWidget {
  const HeaderShortcutStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: const [
          HeaderShortcut(
              icon: Icons.confirmation_number_outlined,
              title: 'คูปอง',
              subtitle: 'เก็บก่อนซื้อ'),
          HeaderShortcut(
              icon: Icons.local_shipping_outlined,
              title: 'ส่งฟรี',
              subtitle: 'โค้ดส่งฟรี'),
          HeaderShortcut(
              icon: Icons.storefront_outlined,
              title: 'เปิดร้าน',
              subtitle: 'เริ่มขาย'),
        ],
      ),
    );
  }
}

class HeaderShortcut extends StatelessWidget {
  const HeaderShortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: accent, size: 17),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.inverted = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool inverted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: inverted ? Colors.white : surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: inverted ? Colors.white.withValues(alpha: 0.72) : line,
            ),
          ),
          child: Icon(icon, color: inverted ? accent : ink),
        ),
      ),
    );
  }
}

class SearchBarButton extends StatelessWidget {
  const SearchBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/search'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                searchSuggestions[0],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 14),
              ),
            ),
            const Icon(Icons.qr_code_scanner, color: muted),
          ],
        ),
      ),
    );
  }
}

class SellerEntryCard extends StatelessWidget {
  const SellerEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          const IconBox(icon: Icons.storefront_outlined),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'มีสินค้าอยากขาย?',
                  style: TextStyle(
                      color: ink, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'เปิดร้าน ลงสินค้า และรับออเดอร์ได้ที่นี่',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (!await requireCustomerLogin(context)) return;
              if (appStore.hasSellerShop) {
                Navigator.of(context).pushNamed('/seller');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpenShopScreen()),
              );
            },
            child: const Text('เปิดร้าน'),
          ),
        ],
      ),
    );
  }
}

class QuickMenuGrid extends StatelessWidget {
  const QuickMenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: quickMenus.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = quickMenus[index];
          return SizedBox(
            width: 72,
            child: ActionTile(icon: item.icon, label: item.label),
          );
        },
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBox(icon: icon, compact: true),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: ink, fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              actionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CampaignStrip extends StatelessWidget {
  const CampaignStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: campaigns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            CampaignCard(campaign: campaigns[index]),
      ),
    );
  }
}

class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 278,
      child: Panel(
        backgroundColor: accent,
        borderColor: accent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    campaign.label,
                    style: const TextStyle(
                      color: Color(0xFFFFC8CE),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    campaign.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    campaign.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE4E7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const IconBox(
              icon: Icons.local_mall_outlined,
              large: true,
              inverted: true,
            ),
          ],
        ),
      ),
    );
  }
}

class TwinFeatureBlocks extends StatelessWidget {
  const TwinFeatureBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: VideoFeatureBlock()),
          SizedBox(width: 6),
          Expanded(child: FlashSaleFeatureBlock()),
        ],
      ),
    );
  }
}

class FeaturePanelTitle extends StatelessWidget {
  const FeaturePanelTitle({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 17),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: muted, size: 16),
      ],
    );
  }
}

class VideoFeatureBlock extends StatelessWidget {
  const VideoFeatureBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final videos = marketplaceProducts
        .where((product) => product.isVideo)
        .take(2)
        .toList();

    return SizedBox(
      height: 178,
      child: Panel(
        padding: const EdgeInsets.all(7),
        child: Column(
          children: [
            const FeaturePanelTitle(
                title: 'NP VIDEO', icon: Icons.play_circle_outline),
            const SizedBox(height: 7),
            Expanded(
              child: Row(
                children: [
                  for (final product in videos) ...[
                    Expanded(child: SmallVideoTile(product: product)),
                    if (product != videos.last) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmallVideoTile extends StatelessWidget {
  const SmallVideoTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProductPhoto(url: product.imageUrl, height: double.infinity),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
              left: 5, top: 5, child: VideoBadge(views: product.videoViews)),
          Positioned(
            left: 5,
            right: 5,
            bottom: 5,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FlashSaleFeatureBlock extends StatelessWidget {
  const FlashSaleFeatureBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final deals = [...marketplaceProducts]
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final topDeals = deals.take(2).toList();

    return SizedBox(
      height: 178,
      child: Panel(
        padding: const EdgeInsets.all(7),
        child: Column(
          children: [
            const FeaturePanelTitle(
                title: 'FLASH SALE', icon: Icons.local_fire_department),
            const SizedBox(height: 7),
            Expanded(
              child: Row(
                children: [
                  for (final product in topDeals) ...[
                    Expanded(child: FlashMiniDeal(product: product)),
                    if (product != topDeals.last) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlashMiniDeal extends StatelessWidget {
  const FlashMiniDeal({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                ProductPhoto(url: product.imageUrl, height: double.infinity),
                Positioned(
                  right: 0,
                  top: 0,
                  child: DiscountCorner(percent: product.discountPercent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            formatBaht(product.price),
            style: const TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const SaleProgressBar(),
      ],
    );
  }
}

class SaleProgressBar extends StatelessWidget {
  const SaleProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFFF5CEC8),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.68,
        child: Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class ShopStrip extends StatelessWidget {
  const ShopStrip({super.key, required this.shops});

  final List<Shop> shops;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: shops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ShopCard(shop: shops[index]),
      ),
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 228,
      child: Panel(
        child: Row(
          children: [
            const IconBox(icon: Icons.storefront_outlined, large: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shop.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${shop.productCount} สินค้า',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.53,
        ),
        itemBuilder: (context, index) => ProductCard(product: products[index]),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Panel(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductPhoto(url: product.imageUrl, height: 144),
                if (product.isVideo)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: VideoBadge(views: product.videoViews),
                  ),
                if (product.discountPercent > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: DiscountCorner(percent: product.discountPercent),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: ProductBadge(
                      label: product.isVideo ? 'วิดีโอสินค้า' : product.badge),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        ProductMiniTag(
                            label: product.serviceLabel, filled: true),
                        ProductMiniTag(label: product.shippingLabel),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ProductPromoLine(label: product.promoLabel),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatBaht(product.price),
                          style: const TextStyle(
                            color: accent,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.confirmation_number,
                            size: 13, color: accent),
                        const Spacer(),
                        Text(
                          'ขายแล้ว ${compactCount(product.soldCount)}',
                          maxLines: 1,
                          style: const TextStyle(color: muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined,
                            size: 13, color: Color(0xFF12A675)),
                        const SizedBox(width: 2),
                        Text(
                          product.shippingLabel,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF0B9A72),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: muted),
                        Flexible(
                          child: Text(
                            product.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: muted, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late String selectedColor;
  late String selectedSize;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.product.colorOptions.isNotEmpty
        ? widget.product.colorOptions.first
        : '';
    selectedSize = widget.product.sizeOptions.isNotEmpty
        ? widget.product.sizeOptions.first
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            title: const Text(
              'รายละเอียดสินค้า',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.share_outlined)),
              IconButton(
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline)),
            ],
          ),
          SliverToBoxAdapter(child: DetailMediaGallery(product: product)),
          SliverToBoxAdapter(child: ProductPromoBand(product: product)),
          SliverToBoxAdapter(child: DetailPriceBlock(product: product)),
          SliverToBoxAdapter(
            child: DetailVariantBlock(
              product: product,
              selectedColor: selectedColor,
              selectedSize: selectedSize,
              onColorSelected: (value) => setState(() => selectedColor = value),
              onSizeSelected: (value) => setState(() => selectedSize = value),
            ),
          ),
          SliverToBoxAdapter(child: DetailSizeChartBlock(product: product)),
          SliverToBoxAdapter(child: DetailVoucherBlock(product: product)),
          SliverToBoxAdapter(child: DetailShippingBlock(product: product)),
          const SliverToBoxAdapter(child: ShopeeGuaranteeBlock()),
          SliverToBoxAdapter(child: ShopeeReviewBlock(product: product)),
          SliverToBoxAdapter(child: ShopeeShopBlock(product: product)),
          SliverToBoxAdapter(child: ShopeeSpecificationBlock(product: product)),
          const SliverToBoxAdapter(child: DetailSimilarHeader()),
          ProductGrid(products: marketplaceProducts),
          const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
        ],
      ),
      bottomNavigationBar: ProductActionBar(
        product: product,
        selectedColor: selectedColor,
        selectedSize: selectedSize,
      ),
    );
  }
}

class DetailMediaGallery extends StatelessWidget {
  const DetailMediaGallery({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 240,
          width: double.infinity,
          color: Colors.white,
          child: Image.network(
            product.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFEDEFF4),
              child:
                  const Icon(Icons.image_not_supported_outlined, color: muted),
            ),
          ),
        ),
        if (product.isVideo)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
          ),
        if (product.discountPercent > 0)
          Positioned(
              right: 0,
              top: 0,
              child: DiscountCorner(percent: product.discountPercent)),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              product.isVideo ? '1/13' : '1/5',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class ProductPromoBand extends StatelessWidget {
  const ProductPromoBand({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 60,
            color: const Color(0xFFFF5A3D),
            alignment: Alignment.center,
            child: const Text('8.8',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF19B79A),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_shipping_outlined,
                      color: Colors.white, size: 19),
                  SizedBox(width: 5),
                  Text('ส่งฟรี ร้านโค้ดคืน',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFFFD32A),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.percent, color: accent, size: 18),
                  SizedBox(width: 5),
                  Text('ส่วนลดร้านโค้ด',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPriceBlock extends StatelessWidget {
  const DetailPriceBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBaht(product.price),
                style: const TextStyle(
                    color: accent,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.confirmation_number, color: accent, size: 15),
              const SizedBox(width: 6),
              Text(
                formatBaht(product.originalPrice),
                style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 8),
              const Text('ราคาหลังโค้ดส่วนลด',
                  style: TextStyle(color: accent, fontSize: 12)),
              const Spacer(),
              Text('ขายแล้ว ${compactCount(product.soldCount)}',
                  style: const TextStyle(
                      color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              const Icon(Icons.favorite_border, color: muted, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          ProductPromoLine(label: product.promoLabel),
          const SizedBox(height: 7),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.25),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 16),
              const SizedBox(width: 4),
              Text(product.rating.toStringAsFixed(1),
                  style:
                      const TextStyle(color: ink, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Text('คะแนนสินค้า (128)',
                  style: TextStyle(color: muted, fontSize: 12)),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.share_outlined, color: accent),
                tooltip: 'แชร์',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailVariantBlock extends StatelessWidget {
  const DetailVariantBlock({
    super.key,
    required this.product,
    required this.selectedColor,
    required this.selectedSize,
    required this.onColorSelected,
    required this.onSizeSelected,
  });

  final Product product;
  final String selectedColor;
  final String selectedSize;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String> onSizeSelected;

  @override
  Widget build(BuildContext context) {
    final colorOptions = product.colorOptions;
    final sizeOptions = product.sizeOptions;
    if (colorOptions.isEmpty && sizeOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colorOptions.isNotEmpty) ...[
            const Text('สี',
                style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            VariantPreviewStrip(
              product: product,
              selectedColor: selectedColor,
              onColorSelected: onColorSelected,
            ),
          ],
          if (sizeOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('ไซส์',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (product.sizeChartImageUrl != null)
                  const Row(
                    children: [
                      Text('ตารางขนาดสินค้า',
                          style: TextStyle(color: muted, fontSize: 12)),
                      Icon(Icons.keyboard_arrow_down, color: muted, size: 18),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: sizeOptions
                  .map((size) => GestureDetector(
                        onTap: () => onSizeSelected(size),
                        child: OptionChip(
                          label: size,
                          selected: size == selectedSize,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class VariantPreviewStrip extends StatelessWidget {
  const VariantPreviewStrip({
    super.key,
    required this.product,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Product product;
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final labels = product.colorOptions;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final selected = label == selectedColor;
          return GestureDetector(
            onTap: () => onColorSelected(label),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(
                    color: selected ? accent : line, width: selected ? 1.4 : 1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFEDEFF4)),
                    ),
                    if (selected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          width: 14,
                          height: 14,
                          color: accent,
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool hasSizeOptionsFor(Product product) => product.sizeOptions.isNotEmpty;

class DetailSizeChartBlock extends StatelessWidget {
  const DetailSizeChartBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.sizeChartImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('ตารางขนาดสินค้า',
                  style: TextStyle(
                      color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
              Spacer(),
              Icon(Icons.keyboard_arrow_up, color: muted, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF4F4F4),
                child: const Text('ไม่สามารถโหลดตารางขนาดสินค้าได้',
                    style: TextStyle(color: muted, fontSize: 12)),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop('จังหวัดขอนแก่น'),
              child: const Text('ดูเพิ่มเติม >'),
            ),
          ),
        ],
      ),
    );
  }
}

class SizeCell extends StatelessWidget {
  const SizeCell(this.text, {super.key, this.header = false});

  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: header ? muted : ink,
          fontSize: header ? 11 : 12,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

class DetailVoucherBlock extends StatelessWidget {
  const DetailVoucherBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailRowTitle(
              icon: Icons.confirmation_number_outlined,
              title: 'คูปองและส่วนลด'),
          const SizedBox(height: 10),
          Row(
            children: [
              ProductPromoLine(label: product.promoLabel),
              const SizedBox(width: 8),
              const ProductPromoLine(label: 'โค้ดส่งฟรี'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('เก็บ'))
            ],
          ),
        ],
      ),
    );
  }
}

class DetailShippingBlock extends StatelessWidget {
  const DetailShippingBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          DetailListRow(
              icon: Icons.local_shipping_outlined,
              title: 'ส่งฟรี',
              subtitle: 'ขั้นต่ำ ฿0  เงื่อนไข',
              action: 'เก็บ'),
          const Divider(height: 1),
          DetailListRow(
              icon: Icons.delivery_dining,
              title: '9 ส.ค. - 11 ส.ค.',
              subtitle: product.shippingLabel,
              action: ''),
        ],
      ),
    );
  }
}

class DetailListRow extends StatelessWidget {
  const DetailListRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.action});

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10A884), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          if (action.isNotEmpty)
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF26B99A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(58, 34)),
              child: Text(action),
            )
          else
            const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class ShopeeShopBlock extends StatelessWidget {
  const ShopeeShopBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final shopProducts = marketplaceProducts
        .where((item) => item.shopName == product.shopName)
        .take(5)
        .toList();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: softAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD8DA), width: 2),
                ),
                child: const Icon(Icons.storefront_outlined,
                    color: accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${product.serviceLabel} ยท ${product.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: const BorderSide(color: accent),
                  minimumSize: const Size(74, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('ดูร้านค้า'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: ShopMetric(value: '4.9', label: 'ให้คะแนน')),
              Expanded(child: ShopMetric(value: '128', label: 'รายการสินค้า')),
              Expanded(child: ShopMetric(value: '95%', label: 'ตอบกลับแชท')),
            ],
          ),
          if (shopProducts.isNotEmpty) ...[
            const Divider(height: 22),
            Row(
              children: const [
                Text('สินค้าขายดีประจำร้าน',
                    style: TextStyle(
                        color: ink, fontWeight: FontWeight.w900, fontSize: 14)),
                Spacer(),
                Icon(Icons.chevron_right, color: muted, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shopProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    ShopeeShopProductTile(product: shopProducts[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ShopeeShopProductTile extends StatelessWidget {
  const ShopeeShopProductTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product)));
      },
      child: SizedBox(
        width: 104,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                child: ProductPhoto(url: product.imageUrl, height: 96),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15)),
                    const SizedBox(height: 4),
                    Text(formatBaht(product.price),
                        style: const TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFFFB300), size: 12),
                        const SizedBox(width: 2),
                        Text(product.rating.toStringAsFixed(1),
                            style: const TextStyle(color: ink, fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailShopBlock extends StatelessWidget {
  const DetailShopBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      child: Column(
        children: [
          Row(
            children: [
              const IconBox(icon: Icons.storefront_outlined, large: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${product.serviceLabel} ยท ${product.category}',
                        style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        OutlinedButton.icon(
                            onPressed: () {},
                            icon:
                                const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('แชท')),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: () {}, child: const Text('ดูร้านค้า')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShopMetric(value: '4.9', label: 'ให้คะแนน')),
              Expanded(child: ShopMetric(value: '128', label: 'รายการสินค้า')),
              Expanded(child: ShopMetric(value: '95%', label: 'ตอบกลับแชท')),
            ],
          ),
        ],
      ),
    );
  }
}

class ShopeeSpecificationBlock extends StatelessWidget {
  const ShopeeSpecificationBlock({super.key, required this.product});

  final Product product;

  String get description =>
      '${product.name} เหมาะสำหรับการใช้งานประจำวัน สินค้าพร้อมจัดส่งจากร้านค้า '
      'มีระบบติดตามคำสั่งซื้อ รองรับการชำระเงินปกติของ NP Market และมีบริการหลังการขายจากร้านค้า '
      'รายละเอียดสินค้าอาจแตกต่างตามตัวเลือกสี ไซส์ หรือรุ่นที่ผู้ซื้อเลือก';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.list_alt_outlined, color: accent, size: 18),
              SizedBox(width: 6),
              Text('รายละเอียดสินค้า',
                  style: TextStyle(
                      color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          DetailLine(label: 'หมวดหมู่', value: product.category),
          DetailLine(label: 'ร้านค้า', value: product.shopName),
          DetailLine(label: 'บริการ', value: product.serviceLabel),
          DetailLine(label: 'โปรโมชั่น', value: product.promoLabel),
          DetailLine(
              label: 'คุณลักษณะ',
              value: hasSizeOptionsFor(product)
                  ? 'สี, ไซส์, คลัง, ปริมาณ, น้ำหนัก'
                  : 'คลัง, ปริมาณ, น้ำหนัก, รุ่นสินค้า'),
          const SizedBox(height: 5),
          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontSize: 13, height: 1.38),
          ),
          Center(
            child: TextButton(
              onPressed: () => showProductDescriptionSheet(context, product),
              child: const Text('เพิ่มเติม'),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopeeSpecCollapseBlock extends StatelessWidget {
  const ShopeeSpecCollapseBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => showProductDescriptionSheet(context, product),
            child:
                const ShopeeCollapseRow(title: 'คุณสมบัติและรายละเอียดสินค้า'),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

void showProductDescriptionSheet(BuildContext context, Product product) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('รายละเอียดสินค้า',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: muted)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  DetailLine(label: 'หมวดหมู่', value: product.category),
                  DetailLine(label: 'ร้านค้า', value: product.shopName),
                  DetailLine(label: 'บริการ', value: product.serviceLabel),
                  DetailLine(label: 'โปรโมชั่น', value: product.promoLabel),
                  const SizedBox(height: 12),
                  Text(
                    ' สินค้าพร้อมจัดส่งจากร้านค้า มีระบบติดตามคำสั่งซื้อ และรองรับการชำระเงินปกติของ NP Market',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: ink, fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ShopeeReviewBlock extends StatelessWidget {
  const ShopeeReviewBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(product.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      color: ink, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(width: 2),
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 4),
              const Text('คะแนนสินค้า (128)',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('ดูทั้งหมด'))
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              ReviewFilterChip(label: 'ทั้งหมด'),
              ReviewFilterChip(label: 'มีรูปภาพ/วิดีโอ'),
              ReviewFilterChip(label: '5 ดาว'),
              ReviewFilterChip(label: 'ตรงปก'),
            ],
          ),
          const SizedBox(height: 12),
          const ReviewSnippet(
              name: 'puyk.pomwong',
              variant: 'สีพื้นฐาน, L',
              text:
                  'สินค้าตรงปก จัดส่งไว แพ็กสินค้าดี ใส่แล้วสบาย คุณภาพเหมาะกับราคา'),
          const SizedBox(height: 12),
          const ReviewSnippet(
              name: 'k*****p',
              variant: 'สีพิเศษ, XL',
              text:
                  'ร้านตอบแชทเร็ว สินค้าคุณภาพดี รายละเอียดครบ เลือกตัวเลือกได้ตรงตามที่สั่ง'),
        ],
      ),
    );
  }
}

class ShopeeGuaranteeBlock extends StatelessWidget {
  const ShopeeGuaranteeBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      child: Column(
        children: const [
          ShopeeCollapseRow(title: 'ข้อปี้การันตี'),
          Divider(height: 1),
        ],
      ),
    );
  }
}

class ShopeeCollapseRow extends StatelessWidget {
  const ShopeeCollapseRow({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          const Icon(Icons.keyboard_arrow_down, color: muted, size: 20),
        ],
      ),
    );
  }
}

class ReviewFilterChip extends StatelessWidget {
  const ReviewFilterChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: softAccent,
        border: Border.all(color: const Color(0xFFFFD8DA)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class DetailSpecificationBlock extends StatelessWidget {
  const DetailSpecificationBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailRowTitle(
              icon: Icons.list_alt_outlined, title: 'รายละเอียดสินค้า'),
          const SizedBox(height: 10),
          DetailLine(label: 'หมวดหมู่', value: product.category),
          DetailLine(label: 'ร้านค้า', value: product.shopName),
          DetailLine(label: 'บริการ', value: product.serviceLabel),
          DetailLine(label: 'โปรโมชั่น', value: product.promoLabel),
          const DetailLine(
              label: 'คุณลักษณะ', value: 'คลัง, ปริมาณ, น้ำหนัก, สี, ไซซ์'),
          const SizedBox(height: 8),
          Text(
            '${product.name} เหมาะสำหรับการใช้งานประจำวัน สินค้าพร้อมจัดส่งจากร้านค้า มีระบบติดตามคำสั่งซื้อ และรองรับการชำระเงินปกติของ NP Market',
            style: const TextStyle(color: ink, fontSize: 13, height: 1.35),
          ),
          Center(
              child:
                  TextButton(onPressed: () {}, child: const Text('เพิ่มเติม'))),
        ],
      ),
    );
  }
}

class DetailReviewBlock extends StatelessWidget {
  const DetailReviewBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DetailRowTitle(
                  icon: Icons.rate_review_outlined, title: 'รีวิวสินค้า'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('ดูทั้งหมด'))
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 4),
              Text('${product.rating.toStringAsFixed(1)}/5',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Text('มีรูปภาพ · มีวิดีโอ',
                  style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          const ReviewSnippet(
              name: 'puyk.pomwong',
              variant: 'สีพื้นฐาน, L',
              text: 'สินค้าตรงปก จัดส่งไว แพ็กสินค้าดี ใส่แล้วสบาย'),
          const SizedBox(height: 10),
          const ReviewSnippet(
              name: 'k*****p',
              variant: 'สีพิเศษ, XL',
              text: 'คุณภาพดี ราคาเหมาะสม ร้านตอบแชทเร็ว'),
        ],
      ),
    );
  }
}

class StoreVideoBlock extends StatelessWidget {
  const StoreVideoBlock({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final videos =
        marketplaceProducts.where((item) => item.isVideo).take(3).toList();
    if (videos.isEmpty) return const SizedBox.shrink();

    return DetailSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailRowTitle(
              icon: Icons.play_circle_outline, title: 'วิดีโอรีวิวสินค้า'),
          const SizedBox(height: 10),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                  width: 104, child: SmallVideoTile(product: videos[index])),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailSimilarHeader extends StatelessWidget {
  const DetailSimilarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionHeader(title: 'สินค้าแนะนำ', actionLabel: 'ดูเพิ่ม');
  }
}

class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Panel(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class DetailRowTitle extends StatelessWidget {
  const DetailRowTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 84,
              child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class DetailInfoTile extends StatelessWidget {
  const DetailInfoTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10A884), size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style:
                    const TextStyle(color: ink, fontWeight: FontWeight.w800))),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        const Icon(Icons.chevron_right, color: muted, size: 18),
      ],
    );
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip(
      {super.key,
      required this.label,
      this.selected = false,
      this.disabled = false});

  final String label;
  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF4F4F4) : Colors.white,
        border: Border.all(color: selected ? accent : line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color:
                disabled ? const Color(0xFFC8C8C8) : (selected ? accent : ink),
            fontSize: 12,
            fontWeight: FontWeight.w800),
      ),
    );
  }
}

class ShopMetric extends StatelessWidget {
  const ShopMetric({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }
}

class ReviewSnippet extends StatelessWidget {
  const ReviewSnippet(
      {super.key,
      required this.name,
      required this.variant,
      required this.text});

  final String name;
  final String variant;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: softAccent,
                child: Text(name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: accent, fontSize: 11))),
            const SizedBox(width: 8),
            Text(name,
                style:
                    const TextStyle(color: ink, fontWeight: FontWeight.w900)),
            const Spacer(),
            const Text('มีประโยชน์',
                style: TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 5),
        const Text('★★★★★',
            style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
        const SizedBox(height: 4),
        Text('ตัวเลือกสินค้า: $variant',
            style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontSize: 13, height: 1.32)),
      ],
    );
  }
}

class ProductActionBar extends StatelessWidget {
  const ProductActionBar({
    super.key,
    required this.product,
    required this.selectedColor,
    required this.selectedSize,
  });

  final Product product;
  final String selectedColor;
  final String selectedSize;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
            color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 44,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Icon(Icons.chat_bubble_outline, color: accent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => showProductOptionSheet(
                    context, product, ProductOptionAction.cart,
                    initialColor: selectedColor, initialSize: selectedSize),
                style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: const BorderSide(color: accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('ใส่ตะกร้า'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => showProductOptionSheet(
                    context, product, ProductOptionAction.buy,
                    initialColor: selectedColor, initialSize: selectedSize),
                style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('ซื้อเลย'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ProductOptionAction { cart, buy }

void showProductOptionSheet(
  BuildContext context,
  Product product,
  ProductOptionAction action, {
  String? initialColor,
  String? initialSize,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (context) => ProductOptionSheet(
      product: product,
      action: action,
      initialColor: initialColor,
      initialSize: initialSize,
    ),
  );
}

class ProductOptionSheet extends StatefulWidget {
  const ProductOptionSheet({
    super.key,
    required this.product,
    required this.action,
    this.initialColor,
    this.initialSize,
  });

  final Product product;
  final ProductOptionAction action;
  final String? initialColor;
  final String? initialSize;

  @override
  State<ProductOptionSheet> createState() => _ProductOptionSheetState();
}

class _ProductOptionSheetState extends State<ProductOptionSheet> {
  late String selectedColor;
  late String selectedSize;
  int quantity = 1;

  List<String> get colorOptions => widget.product.colorOptions;
  List<String> get sizeOptions => widget.product.sizeOptions;
  int get stock => widget.product.stock;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor != null &&
            colorOptions.contains(widget.initialColor)
        ? widget.initialColor!
        : (colorOptions.isNotEmpty ? colorOptions.first : '');
    selectedSize =
        widget.initialSize != null && sizeOptions.contains(widget.initialSize)
            ? widget.initialSize!
            : (sizeOptions.isNotEmpty ? sizeOptions.first : '');
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = widget.action == ProductOptionAction.cart
        ? 'เพิ่มไปยังรถเข็น'
        : 'ซื้อเลย';
    final selectedSummary = [
      if (selectedColor.isNotEmpty) selectedColor,
      if (selectedSize.isNotEmpty) selectedSize,
    ].join(', ');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 108,
                    height: 108,
                    child: Image.network(
                      widget.product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEDEFF4),
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: muted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatBaht(widget.product.price),
                          style: const TextStyle(
                              color: accent,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      const SizedBox(height: 6),
                      Text('คลัง: $stock',
                          style: const TextStyle(color: muted, fontSize: 12.5)),
                      if (selectedSummary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('เลือกแล้ว: $selectedSummary',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: muted)),
              ],
            ),
            if (colorOptions.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('สี',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colorOptions
                    .map((color) => ChoicePill(
                        label: color,
                        selected: selectedColor == color,
                        onTap: () => setState(() => selectedColor = color)))
                    .toList(),
              ),
            ],
            if (sizeOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Text('ไซส์',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (widget.product.sizeChartImageUrl != null)
                  const Text('ตารางขนาดสินค้า',
                      style: TextStyle(color: muted, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sizeOptions
                    .map((size) => ChoicePill(
                        label: size,
                        selected: selectedSize == size,
                        onTap: () => setState(() => selectedSize = size)))
                    .toList(),
              ),
            ],
            const Divider(height: 26),
            Row(
              children: [
                const Text('จำนวน',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
                const Spacer(),
                StepperButton(
                    icon: Icons.remove,
                    onTap:
                        quantity > 1 ? () => setState(() => quantity--) : null),
                Container(
                    width: 44,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: line)),
                    child: Text('$quantity',
                        style: const TextStyle(
                            color: accent, fontWeight: FontWeight.w900))),
                StepperButton(
                    icon: Icons.add,
                    onTap: quantity < stock
                        ? () => setState(() => quantity++)
                        : null),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: stock <= 0 ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: line,
                    disabledForegroundColor: muted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6))),
                child: Text(stock <= 0 ? 'สินค้าหมด' : actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final item = CartItem(
      product: widget.product,
      color: selectedColor.isNotEmpty ? selectedColor : 'มาตรฐาน',
      size: selectedSize,
      quantity: quantity,
    );
    if (widget.action == ProductOptionAction.cart) {
      Navigator.pop(context);
      appStore.addToCart(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มสินค้าในตะกร้าแล้ว')),
      );
    } else {
      if (!await requireCustomerLogin(context)) return;
      Navigator.pop(context);
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CheckoutScreen(items: [item])));
    }
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.disabled = false});

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: OptionChip(label: label, selected: selected, disabled: disabled),
    );
  }
}

class StepperButton extends StatelessWidget {
  const StepperButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 30,
        height: 30,
        child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999))),
            child: Icon(icon, size: 15)));
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<CartItem> items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String shippingMethod = 'Flash Express - ส่งฟรี';
  String paymentMethod = 'เก็บเงินปลายทาง';

  double get subtotal =>
      widget.items.fold(0, (total, item) => total + item.total);
  double get platformDiscount => subtotal > 0 ? 48 : 0;
  int get itemCount =>
      widget.items.fold(0, (total, item) => total + item.quantity);

  Map<String, List<CartItem>> get groupedItems {
    final grouped = <String, List<CartItem>>{};
    for (final item in widget.items) {
      grouped.putIfAbsent(item.product.shopName, () => []).add(item);
    }
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final address = appStore.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ทำการสั่งซื้อ'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 92),
        children: [
          CheckoutAddressCard(address: address),
          for (final entry in groupedItems.entries)
            CheckoutShopCard(
              shopName: entry.key,
              items: entry.value,
              shippingMethod: shippingMethod,
              onShippingTap: _openShipping,
            ),
          CheckoutPlatformVoucherCard(subtotal: subtotal),
          CheckoutPaymentCard(
            paymentMethod: paymentMethod,
            onTap: _openPayment,
          ),
          CheckoutSummaryCard(
            itemCount: itemCount,
            subtotal: subtotal,
            shippingFee: 0,
            shippingDiscount: 0,
            discount: platformDiscount,
          ),
        ],
      ),
      bottomNavigationBar: CheckoutBottomBar(
        total: subtotal - platformDiscount,
        savings: platformDiscount,
        onPressed: () async {
          if (!await requireCustomerLogin(context)) return;
          if (appStore.selectedAddress == null) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddressFormScreen()),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentMockScreen(items: widget.items),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openShipping() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ShippingSelectionScreen(selected: shippingMethod),
      ),
    );
    if (value != null) setState(() => shippingMethod = value);
  }

  Future<void> _openPayment() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(selected: paymentMethod),
      ),
    );
    if (value != null) setState(() => paymentMethod = value);
  }
}

class CheckoutShopCard extends StatelessWidget {
  const CheckoutShopCard({
    super.key,
    required this.shopName,
    required this.items,
    required this.shippingMethod,
    required this.onShippingTap,
  });

  final String shopName;
  final List<CartItem> items;
  final String shippingMethod;
  final VoidCallback onShippingTap;

  double get subtotal => items.fold(0, (total, item) => total + item.total);
  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, color: ink, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: muted, size: 18),
              ],
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: CheckoutItemRow(item: item),
            ),
          const Divider(height: 1),
          const CheckoutStoreLine(
            icon: Icons.confirmation_number_outlined,
            title: 'โค้ดส่วนลดร้านค้า',
            value: 'ยังไม่มีส่วนลดที่ใช้',
          ),
          const Divider(height: 1),
          const CheckoutStoreLine(
            icon: Icons.chat_bubble_outline,
            title: 'หมายเหตุ',
            value: 'ฝากข้อความถึงผู้ขายหรือบริษัทขนส่ง',
          ),
          const Divider(height: 1),
          CheckoutStoreLine(
            icon: Icons.local_shipping_outlined,
            title: 'การจัดส่งของร้านนี้',
            value: shippingMethod,
            onTap: onShippingTap,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'สินค้ารวม $itemCount ชิ้น',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                Text(
                  formatBaht(subtotal),
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutStoreLine extends StatelessWidget {
  const CheckoutStoreLine({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF10A884), size: 18),
            const SizedBox(width: 9),
            SizedBox(
              width: 142,
              child: Text(
                title,
                softWrap: true,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                softWrap: true,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: muted,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class CheckoutPlatformVoucherCard extends StatelessWidget {
  const CheckoutPlatformVoucherCard({super.key, required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          CheckoutStoreLine(
            icon: Icons.confirmation_number_outlined,
            title: 'โค้ดส่วนลด NP Market',
            value: '-${formatBaht(subtotal > 0 ? 48 : 0)}',
          ),
        ],
      ),
    );
  }
}

class CheckoutPaymentCard extends StatelessWidget {
  const CheckoutPaymentCard({
    super.key,
    required this.paymentMethod,
    required this.onTap,
  });

  final String paymentMethod;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: EdgeInsets.zero,
      child: CheckoutStoreLine(
        icon: Icons.payments_outlined,
        title: 'ช่องทางการชำระเงิน',
        value: paymentMethod,
        onTap: onTap,
      ),
    );
  }
}

class CheckoutSummaryCard extends StatelessWidget {
  const CheckoutSummaryCard({
    super.key,
    required this.itemCount,
    required this.subtotal,
    required this.shippingFee,
    required this.shippingDiscount,
    required this.discount,
  });

  final int itemCount;
  final double subtotal;
  final double shippingFee;
  final double shippingDiscount;
  final double discount;

  double get total => subtotal + shippingFee - shippingDiscount - discount;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลการชำระเงิน',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          CheckoutLine(label: 'รวมการสั่งซื้อ', value: formatBaht(subtotal)),
          CheckoutLine(label: 'การจัดส่ง', value: formatBaht(shippingFee)),
          CheckoutLine(
            label: 'ส่วนลดค่าจัดส่ง',
            value: '-${formatBaht(shippingDiscount)}',
          ),
          CheckoutLine(label: 'ส่วนลด', value: '-${formatBaht(discount)}'),
          const Divider(height: 18),
          CheckoutLine(
            label: 'ยอดชำระเงินทั้งหมด',
            value: formatBaht(total),
            strong: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'โดยการกดสั่งสินค้า คุณได้อ่านและยอมรับเงื่อนไขการให้บริการของ NP Market แล้ว',
            style: TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({
    super.key,
    required this.total,
    required this.savings,
    required this.onPressed,
  });

  final double total;
  final double savings;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'รวมยอดสั่งซื้อ ',
                      children: [
                        TextSpan(
                          text: formatBaht(total),
                          style: const TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(color: ink, fontSize: 12),
                  ),
                  Text(
                    'ประหยัดไป ${formatBaht(savings)}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 138,
              height: 46,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'สั่งสินค้า',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShippingSelectionScreen extends StatelessWidget {
  const ShippingSelectionScreen({super.key, required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final options = [
      const ShippingOption(
        carrier: 'Flash Express',
        title: 'Flash Express - ส่งถึงบ้าน',
        date: '11 ส.ค. - 12 ส.ค.',
        price: 'ส่งฟรี',
        subtitle: 'ขนส่งเอกชนยอดนิยม ติดตามพัสดุได้ในแอป',
        selectedLabel: 'Flash Express - ส่งฟรี',
      ),
      const ShippingOption(
        carrier: 'KEX',
        title: 'KEX - ส่งถึงบ้าน',
        date: '11 ส.ค. - 13 ส.ค.',
        price: 'ส่งฟรี',
        subtitle: 'เหมาะกับสินค้าทั่วไปและพื้นที่ครอบคลุมทั่วประเทศ',
        selectedLabel: 'KEX - ส่งฟรี',
      ),
      const ShippingOption(
        carrier: 'Express',
        title: 'Express - ส่งถึงบ้าน',
        date: '10 ส.ค. - 12 ส.ค.',
        price: '฿18',
        subtitle: 'จัดส่งเร็วสำหรับพื้นที่ที่รองรับ',
        selectedLabel: 'Express - ฿18',
      ),
      const ShippingOption(
        carrier: 'ไปรษณีย์ไทย',
        title: 'ไปรษณีย์ไทย - ส่งถึงบ้าน',
        date: '12 ส.ค. - 14 ส.ค.',
        price: 'ส่งฟรี',
        subtitle: 'ครอบคลุมปลายทางทั่วประเทศ เหมาะกับพื้นที่ห่างไกล',
        selectedLabel: 'ไปรษณีย์ไทย - ส่งฟรี',
      ),
      const ShippingOption(
        carrier: 'J&T Express',
        title: 'J&T Express - ส่งถึงบ้าน',
        date: '11 ส.ค. - 12 ส.ค.',
        price: 'ส่งฟรี',
        subtitle: 'ติดตามสถานะพัสดุและรับการแจ้งเตือนในแอป',
        selectedLabel: 'J&T Express - ส่งฟรี',
      ),
    ];
    final selectedOption = options.firstWhere(
      (option) => selected == option.selectedLabel,
      orElse: () => options.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ตัวเลือกการจัดส่ง'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 92),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: ShippingModeCard(
                    selected: true,
                    icon: Icons.local_shipping,
                    title: 'ส่งสินค้าถึงบ้าน',
                    subtitle: selectedOption.carrier,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: ShippingModeCard(
                    selected: false,
                    icon: Icons.store_mall_directory,
                    title: 'รับสินค้าด้วยตนเอง',
                    subtitle: 'ยังไม่เปิดใช้',
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'เลือกบริษัทขนส่งที่ต้องการ',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 3),
            child: Row(
              children: [
                Text(
                  'การันตีวันจัดส่งสินค้า',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                ),
                SizedBox(width: 5),
                Icon(Icons.update, color: Color(0xFF10A884), size: 17),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'ลูกค้าสามารถเลือกขนส่งที่ชอบได้จาก 5 บริษัทที่ NP Market รองรับ',
              style: TextStyle(color: muted, fontSize: 12.5),
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                for (final option in options) ...[
                  ShippingOptionTile(
                    option: option,
                    selected: selected == option.selectedLabel,
                  ),
                  if (option != options.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(selectedOption.selectedLabel),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('ยืนยัน'),
          ),
        ),
      ),
    );
  }
}

class ShippingModeCard extends StatelessWidget {
  const ShippingModeCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: selected ? accent : line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? accent : muted, size: 25),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    color: selected ? accent : ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    color: selected ? accent : muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShippingOption {
  const ShippingOption({
    required this.carrier,
    required this.title,
    required this.date,
    required this.price,
    required this.subtitle,
    required this.selectedLabel,
  });

  final String carrier;
  final String title;
  final String date;
  final String price;
  final String subtitle;
  final String selectedLabel;
}

class ShippingOptionTile extends StatelessWidget {
  const ShippingOptionTile({
    super.key,
    required this.option,
    required this.selected,
  });

  final ShippingOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(option.selectedLabel),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_shipping_outlined,
                color: selected ? const Color(0xFF10A884) : muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          option.date,
                          softWrap: true,
                          style: const TextStyle(
                            color: Color(0xFF10A884),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        option.price,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    option.carrier,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.title,
                    softWrap: true,
                    style: const TextStyle(color: muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    softWrap: true,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected) const Icon(Icons.check, color: accent),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key, required this.selected});

  final String selected;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late String selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final methods = [
      const PaymentMethodOption(
        title: 'QR พร้อมเพย์',
        icon: Icons.qr_code_2,
        badges: ['ส่งฟรี', 'ลด ฿56.00', 'ลด ฿34.00'],
      ),
      const PaymentMethodOption(
        title: 'เก็บเงินปลายทาง',
        icon: Icons.payments_outlined,
        badges: ['ส่งฟรี', 'ลด ฿56.00', 'ลด ฿34.00'],
      ),
      const PaymentMethodOption(
        title: 'Mobile Banking',
        icon: Icons.account_balance,
        badges: ['ส่งฟรี', 'ลด ฿13.00', 'ลด ฿22.00'],
      ),
      const PaymentMethodOption(
        title: 'บัตรเครดิต/เดบิต',
        icon: Icons.credit_card,
        badges: ['ส่งฟรี', 'ลด ฿13.00', 'ลด ฿22.00'],
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ช่องทางการชำระเงิน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 92),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Text(
                    'ช่องทางการชำระเงินอื่น',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                  ),
                ),
                for (final method in methods)
                  PaymentMethodTile(
                    method: method,
                    selected: selected == method.title,
                    onTap: () => setState(() => selected = method.title),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('ยืนยัน'),
          ),
        ),
      ),
    );
  }
}

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.title,
    required this.icon,
    required this.badges,
  });

  final String title;
  final IconData icon;
  final List<String> badges;
}

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(method.icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: method.badges
                        .map((badge) => PaymentDiscountTag(label: badge))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? accent : muted,
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentDiscountTag extends StatelessWidget {
  const PaymentDiscountTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: softAccent,
        border: Border.all(color: const Color(0xFFFFC9CE)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CheckoutAddressCard extends StatelessWidget {
  const CheckoutAddressCard({super.key, required this.address});

  final Address? address;

  @override
  Widget build(BuildContext context) {
    final currentAddress = address;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => currentAddress == null
              ? const AddressFormScreen()
              : const AddressSelectionScreen(),
        ),
      ),
      child: CheckoutCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: currentAddress == null
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เพิ่มที่อยู่จัดส่ง',
                            style: TextStyle(
                                color: ink, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('กรอกที่อยู่จริงก่อนทำรายการสั่งซื้อ',
                            style: TextStyle(
                                color: muted, fontSize: 12.5, height: 1.35)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  '${currentAddress.name}  ${currentAddress.phone}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: ink, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(currentAddress.fullAddress,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: muted, fontSize: 12.5, height: 1.35)),
                        if (currentAddress.isDefault) ...[
                          const SizedBox(height: 6),
                          const ProductMiniTag(label: 'ค่าเริ่มต้น'),
                        ],
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selected = appStore.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('เลือกที่อยู่'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text('พื้นที่จัดส่ง', style: TextStyle(color: muted)),
          ),
          for (final address in appStore.addresses)
            AddressChoiceTile(
              address: address,
              selected: selected != null && address.id == selected.id,
              onTap: () {
                appStore.selectAddress(address);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddressFormScreen()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: const BorderSide(color: accent),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มที่อยู่ใหม่'),
          ),
        ),
      ),
    );
  }
}

class AddressChoiceTile extends StatelessWidget {
  const AddressChoiceTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? accent : muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${address.name}   ${address.phone}',
                      style: const TextStyle(
                          color: ink, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(address.fullAddress,
                      style: const TextStyle(
                          color: muted, fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (address.isDefault)
                        const ProductMiniTag(label: 'ค่าเริ่มต้น'),
                      if (address.label.isNotEmpty)
                        ProductMiniTag(label: address.label),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddressFormScreen(address: address),
                ),
              ),
              child: const Text('แก้ไข'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final Address? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final detailController = TextEditingController();
  AddressArea? selectedArea;
  bool makeDefault = false;
  String label = 'บ้าน';

  bool get isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      nameController.text = address.name;
      phoneController.text = address.phone;
      detailController.text = address.detail;
      selectedArea = AddressArea(
        province: address.province,
        district: address.district,
        subDistrict: address.subDistrict,
        postcode: address.postcode,
      );
      makeDefault = address.isDefault;
      label = address.label.isNotEmpty ? address.label : label;
    }
  }

  bool get canSubmit =>
      nameController.text.trim().isNotEmpty &&
      phoneController.text.trim().isNotEmpty &&
      detailController.text.trim().isNotEmpty &&
      selectedArea != null;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(isEditing ? 'แก้ไขที่อยู่' : 'ที่อยู่ใหม่'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: softAccent,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: accent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ระบบช่วยค้นหาจังหวัด อำเภอ ตำบล และรหัสไปรษณีย์ให้เลือก ผู้ใช้ยังต้องเลือก/กรอกรายละเอียดเอง',
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AddressFormCard(
            children: [
              const Text('ที่อยู่',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
              AddressTextField(
                  controller: nameController,
                  hint: 'ชื่อ นามสกุล',
                  onChanged: _onChanged),
              AddressTextField(
                  controller: phoneController,
                  hint: 'หมายเลขโทรศัพท์',
                  keyboardType: TextInputType.phone,
                  onChanged: _onChanged),
              InkWell(
                onTap: () async {
                  final value = await Navigator.of(context).push<AddressArea>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AreaSelectionScreen(selectedArea: selectedArea),
                    ),
                  );
                  if (value != null) setState(() => selectedArea = value);
                },
                child: AddressPickerRow(
                  text: selectedArea == null
                      ? 'จังหวัด, เขต/อำเภอ, แขวง/ตำบล, รหัสไปรษณีย์'
                      : selectedArea!.displayText,
                  active: selectedArea != null,
                ),
              ),
              AddressTextField(
                  controller: detailController,
                  hint: 'บ้านเลขที่, ซอย, หมู่, ถนน',
                  onChanged: _onChanged),
            ],
          ),
          const SizedBox(height: 12),
          AddressFormCard(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เลือกเป็นที่อยู่ตั้งต้น'),
                value: makeDefault,
                onChanged: (value) => setState(() => makeDefault = value),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Text('ติดป้ายเป็น:'),
                    const Spacer(),
                    ChoicePill(
                        label: 'ที่ทำงาน',
                        selected: label == 'ที่ทำงาน',
                        onTap: () => setState(() => label = 'ที่ทำงาน')),
                    const SizedBox(width: 8),
                    ChoicePill(
                        label: 'บ้าน',
                        selected: label == 'บ้าน',
                        onTap: () => setState(() => label = 'บ้าน')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E5E5),
              disabledForegroundColor: muted,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('ยืนยัน'),
          ),
        ),
      ),
    );
  }

  void _onChanged(String _) => setState(() {});

  void _submit() {
    final area = selectedArea!;
    final address = Address(
      id: widget.address?.id ?? 'addr-${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      detail: detailController.text.trim(),
      province: area.province,
      district: area.district,
      subDistrict: area.subDistrict,
      postcode: area.postcode,
      label: label,
    );
    if (isEditing) {
      appStore.updateAddress(address, makeDefault: makeDefault);
    } else {
      appStore.addAddress(address, makeDefault: makeDefault);
    }
    Navigator.of(context).pop();
  }
}

class AddressFormCard extends StatelessWidget {
  const AddressFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class AddressTextField extends StatelessWidget {
  const AddressTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB8B8B8)),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: line)),
        enabledBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: line)),
      ),
    );
  }
}

class AddressPickerRow extends StatelessWidget {
  const AddressPickerRow({super.key, required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? ink : const Color(0xFFB8B8B8),
                    fontSize: 14)),
          ),
          const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class AddressArea {
  const AddressArea({
    required this.province,
    required this.district,
    required this.subDistrict,
    required this.postcode,
  });

  final String province;
  final String district;
  final String subDistrict;
  final String postcode;

  String get displayText => '$province, $district, $subDistrict, $postcode';
}

String cleanPickupDetail(String detail, AddressArea area) {
  var cleaned = detail.trim();
  final tokens = [
    area.subDistrict,
    area.district,
    area.province,
    area.postcode,
    'ตำบล${area.subDistrict}',
    'แขวง${area.subDistrict}',
    'อำเภอ${area.district}',
    'เขต${area.district}',
    'จังหวัด${area.province}',
  ].where((token) => token.trim().isNotEmpty);
  for (final token in tokens) {
    cleaned = cleaned.replaceAll(token, ' ');
  }
  cleaned = cleaned
      .replaceAll(RegExp(r'(ตำบล|แขวง)\s*\S+'), ' ')
      .replaceAll(RegExp(r'(อำเภอ|เขต)\s*\S+'), ' ')
      .replaceAll(RegExp(r'จังหวัด\s*\S+'), ' ')
      .replaceAll(RegExp(r'\s\d{5}(\s|$)'), ' ');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class AreaSelectionScreen extends StatefulWidget {
  const AreaSelectionScreen({super.key, required this.selectedArea});

  final AddressArea? selectedArea;

  @override
  State<AreaSelectionScreen> createState() => _AreaSelectionScreenState();
}

class _AreaSelectionScreenState extends State<AreaSelectionScreen> {
  String keyword = '';
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedSubDistrict;
  List<AddressArea> areas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAddressAreas();
  }

  Future<void> loadAddressAreas() async {
    final raw =
        await rootBundle.loadString('assets/data/thai_address_areas.json');
    final provinces = jsonDecode(raw) as List<dynamic>;
    final loaded = <AddressArea>[];

    for (final province in provinces.cast<Map<String, dynamic>>()) {
      final provinceName = 'จังหวัด${province['name_th']}';
      final districts = province['districts'] as List<dynamic>? ?? const [];
      for (final district in districts.cast<Map<String, dynamic>>()) {
        final rawDistrictName = district['name_th'] as String;
        final districtName = rawDistrictName.startsWith('เขต')
            ? rawDistrictName
            : 'อำเภอ$rawDistrictName';
        final subDistricts =
            district['sub_districts'] as List<dynamic>? ?? const [];
        for (final subDistrict in subDistricts.cast<Map<String, dynamic>>()) {
          final rawSubDistrictName = subDistrict['name_th'] as String;
          final subDistrictName = districtName.startsWith('เขต')
              ? 'แขวง$rawSubDistrictName'
              : 'ตำบล$rawSubDistrictName';
          loaded.add(AddressArea(
            province: provinceName,
            district: districtName,
            subDistrict: subDistrictName,
            postcode: '${subDistrict['zip_code']}',
          ));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      areas = loaded;
      loading = false;
    });
  }

  int get step {
    if (selectedProvince == null) return 0;
    if (selectedDistrict == null) return 1;
    if (selectedSubDistrict == null) return 2;
    return 3;
  }

  String get searchHint {
    switch (step) {
      case 0:
        return 'ค้นหา จังหวัด';
      case 1:
        return 'ค้นหา อำเภอ/เขต';
      case 2:
        return 'ค้นหา ตำบล/แขวง';
      default:
        return 'ค้นหา รหัสไปรษณีย์';
    }
  }

  String get sectionTitle {
    switch (step) {
      case 0:
        return 'จังหวัด';
      case 1:
        return selectedProvince ?? 'อำเภอ/เขต';
      case 2:
        return selectedDistrict ?? 'ตำบล/แขวง';
      default:
        return selectedSubDistrict ?? 'รหัสไปรษณีย์';
    }
  }

  List<String> get currentOptions {
    Iterable<AddressArea> filteredAreas = areas;
    if (selectedProvince != null) {
      filteredAreas =
          filteredAreas.where((area) => area.province == selectedProvince);
    }
    if (selectedDistrict != null) {
      filteredAreas =
          filteredAreas.where((area) => area.district == selectedDistrict);
    }
    if (selectedSubDistrict != null) {
      filteredAreas = filteredAreas
          .where((area) => area.subDistrict == selectedSubDistrict);
    }

    final values = filteredAreas
        .map((area) {
          switch (step) {
            case 0:
              return area.province;
            case 1:
              return area.district;
            case 2:
              return area.subDistrict;
            default:
              return area.postcode;
          }
        })
        .toSet()
        .toList(growable: false)
      ..sort();

    final query = keyword.trim();
    if (query.isEmpty) return values;
    return values
        .where((value) => value.contains(query))
        .toList(growable: false);
  }

  void goBackStep() {
    if (step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      keyword = '';
      if (step == 3) {
        selectedSubDistrict = null;
      } else if (step == 2) {
        selectedDistrict = null;
      } else {
        selectedProvince = null;
      }
    });
  }

  void selectOption(String value) {
    setState(() => keyword = '');
    if (step == 0) {
      setState(() => selectedProvince = value);
      return;
    }
    if (step == 1) {
      setState(() => selectedDistrict = value);
      return;
    }
    if (step == 2) {
      setState(() => selectedSubDistrict = value);
      return;
    }

    final area = areas.firstWhere(
      (area) =>
          area.province == selectedProvince &&
          area.district == selectedDistrict &&
          area.subDistrict == selectedSubDistrict &&
          area.postcode == value,
    );
    Navigator.of(context).pop(area);
  }

  @override
  Widget build(BuildContext context) {
    final options = currentOptions;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: goBackStep,
        ),
        title: TextField(
          autofocus: false,
          onChanged: (value) => setState(() => keyword = value),
          decoration: InputDecoration(
            hintText: searchHint,
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
            filled: true,
            fillColor: const Color(0xFFF4F4F4),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                  child:
                      Text(sectionTitle, style: const TextStyle(color: muted)),
                ),
                if (selectedProvince != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Text(
                      [
                        selectedProvince,
                        selectedDistrict,
                        selectedSubDistrict,
                      ].whereType<String>().join(' > '),
                      style: const TextStyle(
                          color: ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                for (final option in options)
                  ListTile(
                    title: Text(option),
                    trailing: const Icon(Icons.chevron_right, color: muted),
                    onTap: () => selectOption(option),
                  ),
              ],
            ),
    );
  }
}

class CheckoutItemRow extends StatelessWidget {
  const CheckoutItemRow({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ProductThumb(url: item.product.imageUrl, size: 76),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${item.color}, ${item.size}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 5),
                Text(formatBaht(item.product.price),
                    style: const TextStyle(
                        color: accent, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Text('x${item.quantity}'),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String keyword = '';

  @override
  Widget build(BuildContext context) {
    final results = marketplaceProducts
        .where((product) =>
            keyword.isEmpty ||
            product.name.toLowerCase().contains(keyword.toLowerCase()) ||
            product.category.toLowerCase().contains(keyword.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: TextField(
          autofocus: true,
          onChanged: (value) => setState(() => keyword = value),
          decoration: const InputDecoration(
            hintText: 'ค้นหาสินค้า ร้านค้า หรือหมวดหมู่',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searchSuggestions
                    .map((item) => ActionChip(
                        label: Text(item),
                        onPressed: () => setState(() => keyword = item)))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: SectionHeader(
                  title: 'ผลการค้นหา',
                  actionLabel: '${results.length} รายการ')),
          ProductGrid(products: results),
        ],
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<CartItem> selectedItems = {};

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    selectedItems.removeWhere((item) => !appStore.cartItems.contains(item));
    setState(() {});
  }

  List<CartItem> get selectedList => appStore.cartItems
      .where((item) => selectedItems.contains(item))
      .toList(growable: false);

  double get selectedTotal =>
      selectedList.fold(0, (total, item) => total + item.total);

  int get selectedQuantity =>
      selectedList.fold(0, (total, item) => total + item.quantity);

  Map<String, List<CartItem>> _groupByShop(List<CartItem> items) {
    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.product.shopName, () => []).add(item);
    }
    return grouped;
  }

  bool _isShopSelected(List<CartItem> items) =>
      items.isNotEmpty && items.every(selectedItems.contains);

  void _toggleItem(CartItem item, bool selected) {
    setState(() {
      if (selected) {
        selectedItems.add(item);
      } else {
        selectedItems.remove(item);
      }
    });
  }

  void _toggleShop(List<CartItem> items, bool selected) {
    setState(() {
      if (selected) {
        selectedItems.addAll(items);
      } else {
        selectedItems.removeAll(items);
      }
    });
  }

  void _toggleAll(bool selected) {
    setState(() {
      if (selected) {
        selectedItems
          ..clear()
          ..addAll(appStore.cartItems);
      } else {
        selectedItems.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = appStore.cartItems;
    final grouped = _groupByShop(items);
    final allSelected =
        items.isNotEmpty && selectedItems.length == items.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text('ตะกร้า (${appStore.cartCount})'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        actions: [
          if (selectedItems.isNotEmpty)
            TextButton(
              onPressed: () {
                for (final item in selectedList) {
                  appStore.removeFromCart(item);
                }
                selectedItems.clear();
              },
              child: const Text('ลบ'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'ยังไม่มีสินค้าในตะกร้า',
              message: 'เลือกสินค้าแล้วกดใส่ตะกร้าเพื่อเริ่มซื้อ')
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 92),
              children: [
                for (final entry in grouped.entries)
                  CartShopGroup(
                    shopName: entry.key,
                    items: entry.value,
                    shopSelected: _isShopSelected(entry.value),
                    selectedItems: selectedItems,
                    onShopChanged: (selected) =>
                        _toggleShop(entry.value, selected),
                    onItemChanged: _toggleItem,
                  ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : CartSummaryBar(
              allSelected: allSelected,
              selectedQuantity: selectedQuantity,
              selectedTotal: selectedTotal,
              onSelectAll: _toggleAll,
              onCheckout: selectedItems.isEmpty
                  ? null
                  : () async {
                      if (!await requireCustomerLogin(context)) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(items: selectedList),
                        ),
                      );
                    },
            ),
    );
  }
}

class CartShopGroup extends StatelessWidget {
  const CartShopGroup({
    super.key,
    required this.shopName,
    required this.items,
    required this.shopSelected,
    required this.selectedItems,
    required this.onShopChanged,
    required this.onItemChanged,
  });

  final String shopName;
  final List<CartItem> items;
  final bool shopSelected;
  final Set<CartItem> selectedItems;
  final ValueChanged<bool> onShopChanged;
  final void Function(CartItem item, bool selected) onItemChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
            child: Row(
              children: [
                CartCheckBox(
                    value: shopSelected,
                    onChanged: (value) => onShopChanged(value)),
                const Icon(Icons.storefront_outlined, color: accent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.chevron_right, color: muted, size: 18),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final item in items)
            CartItemTile(
              item: item,
              selected: selectedItems.contains(item),
              onSelected: (selected) => onItemChanged(item, selected),
            ),
        ],
      ),
    );
  }
}

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onSelected,
  });

  final CartItem item;
  final bool selected;
  final ValueChanged<bool> onSelected;

  String get optionText {
    final options = [
      if (item.color.isNotEmpty && item.color != 'มาตรฐาน') item.color,
      if (item.size.isNotEmpty) item.size,
    ];
    return options.isEmpty ? 'ตัวเลือกมาตรฐาน' : options.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: CartCheckBox(value: selected, onChanged: onSelected),
          ),
          ProductThumb(url: item.product.imageUrl, size: 82),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(optionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: muted, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatBaht(item.product.price),
                        style: const TextStyle(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    CartQuantityStepper(item: item),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    ProductMiniTag(label: item.product.shippingLabel),
                    const Spacer(),
                    Text('คลัง ${item.product.stock}',
                        style: const TextStyle(color: muted, fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CartStepperIcon(
            icon: Icons.remove,
            onTap: () {
              if (item.quantity <= 1) {
                showCartRemoveDialog(context, item);
              } else {
                appStore.updateQuantity(item, item.quantity - 1);
              }
            },
          ),
          Container(
            width: 34,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: line)),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                  color: ink, fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ),
          CartStepperIcon(
            icon: Icons.add,
            onTap: item.quantity < item.product.stock
                ? () => appStore.updateQuantity(item, item.quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class CartStepperIcon extends StatelessWidget {
  const CartStepperIcon({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 31,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        color: onTap == null ? const Color(0xFFD7C2C5) : accent,
      ),
    );
  }
}

void showCartRemoveDialog(BuildContext context, CartItem item) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
      content: const Text(
        'คุณแน่ใจว่าต้องการลบหรือไม่?',
        textAlign: TextAlign.center,
        style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('ไม่'),
              ),
            ),
            Container(width: 1, height: 48, color: line),
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  appStore.removeFromCart(item);
                },
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('ใช่'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    super.key,
    required this.allSelected,
    required this.selectedQuantity,
    required this.selectedTotal,
    required this.onSelectAll,
    required this.onCheckout,
  });

  final bool allSelected;
  final int selectedQuantity;
  final double selectedTotal;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: const BoxDecoration(
            color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: Row(
          children: [
            CartCheckBox(value: allSelected, onChanged: onSelectAll),
            const Text('ทั้งหมด',
                style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('รวม ${formatBaht(selectedTotal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                  const Text('ประหยัด ฿0',
                      style: TextStyle(color: accent, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: line,
                    disabledForegroundColor: muted,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4))),
                child: Text('ชำระเงิน ($selectedQuantity)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartCheckBox extends StatelessWidget {
  const CartCheckBox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => onChanged(!value),
        icon: Icon(
          value ? Icons.check_circle : Icons.radio_button_unchecked,
          color: value ? accent : muted,
          size: 22,
        ),
      ),
    );
  }
}

class PaymentMockScreen extends StatefulWidget {
  const PaymentMockScreen({super.key, required this.items});

  final List<CartItem> items;

  @override
  State<PaymentMockScreen> createState() => _PaymentMockScreenState();
}

class _PaymentMockScreenState extends State<PaymentMockScreen> {
  bool isSubmitting = false;

  Future<void> _submitOrder() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);
    try {
      final order = await appStore.createOrder(
        widget.items,
        'เก็บเงินปลายทาง',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้างออเดอร์ไม่สำเร็จ: $error'),
          backgroundColor: accent,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal =
        widget.items.fold<double>(0, (total, item) => total + item.total);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('ชำระเงิน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          const CheckoutCard(
            child: DetailInfoTile(
              icon: Icons.payments_outlined,
              title: 'วิธีชำระเงิน',
              value: 'เก็บเงินปลายทาง',
            ),
          ),
          CheckoutCard(
            child: Column(
              children: [
                CheckoutLine(label: 'ยอดสินค้า', value: formatBaht(subtotal)),
                const CheckoutLine(label: 'ค่าส่ง', value: '฿0'),
                const Divider(),
                CheckoutLine(
                  label: 'ยอดชำระ',
                  value: formatBaht(subtotal),
                  strong: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: isSubmitting ? null : _submitOrder,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('ยืนยันชำระเงิน'),
          ),
        ),
      ),
    );
  }
}

class SellerCenterScreen extends StatefulWidget {
  const SellerCenterScreen({super.key});

  @override
  State<SellerCenterScreen> createState() => _SellerCenterScreenState();
}

class _SellerCenterScreenState extends State<SellerCenterScreen> {
  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appStore.loadSellerWorkspace();
    });
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final seller = appStore.sellerProfile;
    final products = appStore.sellerProducts;
    final orders = appStore.orders;
    final hasShop = seller != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ศูนย์ผู้ขาย'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'แชทร้านค้า',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
        children: [
          SellerHeroCard(seller: seller),
          if (!hasShop)
            SellerStartCard(
              onTap: () async {
                if (!await requireCustomerLogin(context)) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OpenShopScreen()),
                );
              },
            )
          else if (!seller.isVerified)
            SellerApprovalPendingCard(seller: seller)
          else ...[
            SellerOrderStatusPanel(orders: orders),
            SellerToolGrid(
              onAddProduct: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerProductFormScreen()),
              ),
              onOrders: () => Navigator.of(context).pushNamed('/seller/orders'),
              onProducts: () =>
                  Navigator.of(context).pushNamed('/seller/products'),
              onSettings: () =>
                  Navigator.of(context).pushNamed('/seller/settings'),
              onShipping: () =>
                  Navigator.of(context).pushNamed('/seller/shipping'),
              onBalance: () =>
                  Navigator.of(context).pushNamed('/seller/balance'),
            ),
            SellerProductList(products: products),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          child: FilledButton.icon(
            onPressed: hasShop && !seller.isVerified
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OpenShopScreen()),
                    )
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => hasShop
                            ? const SellerProductFormScreen()
                            : const OpenShopScreen(),
                      ),
                    ),
            icon: Icon(hasShop
                ? (seller.isVerified ? Icons.add_box_outlined : Icons.edit_note)
                : Icons.storefront),
            label: Text(hasShop
                ? (seller.isVerified ? 'เพิ่มสินค้า' : 'แก้ไขคำขอเปิดร้าน')
                : 'เปิดร้านค้า'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SellerHeroCard extends StatelessWidget {
  const SellerHeroCard({super.key, required this.seller});

  final SellerProfile? seller;

  @override
  Widget build(BuildContext context) {
    final hasShop = seller != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasShop ? seller!.shopName : 'เริ่มขายบน NP Market',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasShop
                      ? '${seller!.category} · พร้อมลงสินค้าและรับออเดอร์'
                      : 'เปิดร้าน ลงสินค้า และให้สินค้าไหลไปหน้าลูกค้า',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showSellerApprovalPending(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('ร้านค้ากำลังรออนุมัติ หลังอนุมัติแล้วจึงเพิ่มสินค้าได้'),
    ),
  );
}

class SellerApprovalPendingCard extends StatelessWidget {
  const SellerApprovalPendingCard({super.key, required this.seller});

  final SellerProfile seller;

  @override
  Widget build(BuildContext context) {
    final isRejected =
        seller.status == 'suspended' || seller.status == 'paused';
    final message = isRejected
        ? (seller.reviewNote.isEmpty
            ? 'คำขอเปิดร้านยังไม่ผ่าน กรุณาตรวจสอบข้อมูลและส่งคำขอใหม่'
            : 'คำขอเปิดร้านยังไม่ผ่าน: \${seller.reviewNote}')
        : 'ร้านค้าส่งคำขอแล้วและกำลังรออนุมัติ เมื่ออนุมัติแล้วจะเพิ่มสินค้าและแสดงในหน้าหลักได้';
    return CheckoutCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline : Icons.hourglass_top,
            color: isRejected ? accent : const Color(0xFFE0A300),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ink, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerStartCard extends StatelessWidget {
  const SellerStartCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เปิดร้านให้พร้อมก่อนลงสินค้า',
            style: TextStyle(
                color: ink, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'ขั้นแรกให้ตั้งค่าร้าน ชื่อร้าน หมวดหมู่ เบอร์ติดต่อ และที่อยู่ร้าน จากนั้นจึงเพิ่มสินค้าเพื่อให้ลูกค้าเห็นในหน้าแอป',
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: const Text('เปิดร้านค้า'),
          ),
        ],
      ),
    );
  }
}

class SellerStatsGrid extends StatelessWidget {
  const SellerStatsGrid({super.key, required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SellerStatTile(label: 'สินค้า', value: '$productCount'),
          const SizedBox(width: 8),
          const SellerStatTile(label: 'ออเดอร์ใหม่', value: '0'),
          const SizedBox(width: 8),
          const SellerStatTile(label: 'รอจัดส่ง', value: '0'),
        ],
      ),
    );
  }
}

class SellerStatTile extends StatelessWidget {
  const SellerStatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class SellerTaskCard extends StatelessWidget {
  const SellerTaskCard({super.key, required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('งานที่ต้องทำ',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SellerTaskRow(
            icon: Icons.inventory_2_outlined,
            title:
                productCount == 0 ? 'ยังไม่มีสินค้าเปิดขาย' : 'สินค้าพร้อมขาย',
            value:
                productCount == 0 ? 'เพิ่มสินค้าแรก' : '$productCount รายการ',
          ),
          const Divider(height: 18),
          const SellerTaskRow(
            icon: Icons.local_shipping_outlined,
            title: 'ขนส่งที่ร้านรองรับ',
            value: '5 บริษัท',
          ),
        ],
      ),
    );
  }
}

class SellerTaskRow extends StatelessWidget {
  const SellerTaskRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(title,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
        ),
        Text(value, style: const TextStyle(color: muted, fontSize: 12.5)),
      ],
    );
  }
}

class SellerOrderStatusPanel extends StatelessWidget {
  const SellerOrderStatusPanel({super.key, required this.orders});

  final List<Order> orders;

  int countWhere(String value) =>
      orders.where((order) => order.status.contains(value)).length;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(
            title: 'สถานะคำสั่งซื้อ',
            action: 'ดูประวัติการขาย',
            onTap: () => Navigator.of(context).pushNamed('/seller/orders'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 13),
            child: Row(
              children: [
                Expanded(
                  child: SellerStatusIcon(
                    icon: Icons.local_shipping_outlined,
                    label: 'ที่ต้องจัดส่ง',
                    count: countWhere('รอจัดส่ง'),
                    route: '/seller/orders',
                  ),
                ),
                Expanded(
                  child: SellerStatusIcon(
                    icon: Icons.cancel_presentation_outlined,
                    label: 'ยกเลิก',
                    count: countWhere('ยกเลิก'),
                    route: '/seller/orders',
                  ),
                ),
                Expanded(
                  child: SellerStatusIcon(
                    icon: Icons.sync_alt_outlined,
                    label: 'คืนสินค้า/คืนเงิน',
                    count: countWhere('คืน'),
                    route: '/seller/orders',
                  ),
                ),
                Expanded(
                  child: SellerStatusIcon(
                    icon: Icons.more_horiz,
                    label: 'เพิ่มเติม',
                    count: orders.length,
                    route: '/seller/orders',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SellerStatusIcon extends StatelessWidget {
  const SellerStatusIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.route,
  });

  final IconData icon;
  final String label;
  final int count;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: ink, size: 30),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerQuickActions extends StatelessWidget {
  const SellerQuickActions({
    super.key,
    required this.onProducts,
    required this.onOrders,
    required this.onDelivery,
    required this.onStats,
  });

  final VoidCallback onProducts;
  final VoidCallback onOrders;
  final VoidCallback onDelivery;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: Row(
        children: [
          SellerRoundAction(
            icon: Icons.inventory_2_outlined,
            label: 'สินค้าของฉัน',
            onTap: onProducts,
          ),
          SellerRoundAction(
            icon: Icons.receipt_long_outlined,
            label: 'การขาย',
            onTap: onOrders,
          ),
          SellerRoundAction(
            icon: Icons.local_shipping_outlined,
            label: 'ส่งสินค้า',
            onTap: onDelivery,
          ),
          SellerRoundAction(
            icon: Icons.bar_chart_outlined,
            label: 'สถิติร้าน',
            onTap: onStats,
          ),
        ],
      ),
    );
  }
}

class SellerRoundAction extends StatelessWidget {
  const SellerRoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDEF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerMissionPanel extends StatelessWidget {
  const SellerMissionPanel({
    super.key,
    required this.productCount,
    required this.orderCount,
  });

  final int productCount;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(title: 'ภารกิจ', action: 'View More Missions'),
          const Divider(height: 1),
          SellerMissionRow(
            title: productCount == 0
                ? 'เพิ่มสินค้าแรกเพื่อเปิดหน้าร้าน'
                : 'เพิ่มสินค้าใหม่ให้ร้านมีตัวเลือกมากขึ้น',
            progress: productCount == 0 ? '0/1' : '$productCount รายการ',
            button: productCount == 0 ? 'เริ่มต้น' : 'เพิ่มสินค้า',
            route: '/seller/products',
          ),
          const Divider(height: 1),
          SellerMissionRow(
            title: orderCount == 0
                ? 'รอออเดอร์แรกจากลูกค้า'
                : 'อัปเดตสถานะออเดอร์ให้ครบ',
            progress: '$orderCount ออเดอร์',
            button: 'ดูออเดอร์',
            route: '/seller/orders',
          ),
        ],
      ),
    );
  }
}

class SellerMissionRow extends StatelessWidget {
  const SellerMissionRow({
    super.key,
    required this.title,
    required this.progress,
    required this.button,
    required this.route,
  });

  final String title;
  final String progress;
  final String button;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, color: Color(0xFF10A884), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 3),
                Text(progress,
                    style: const TextStyle(color: muted, fontSize: 11.5)),
              ],
            ),
          ),
          SizedBox(
            height: 30,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(route),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: const BorderSide(color: accent),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerToolGrid extends StatelessWidget {
  const SellerToolGrid({
    super.key,
    required this.onAddProduct,
    required this.onOrders,
    required this.onProducts,
    required this.onSettings,
    required this.onShipping,
    required this.onBalance,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onOrders;
  final VoidCallback onProducts;
  final VoidCallback onSettings;
  final VoidCallback onShipping;
  final VoidCallback onBalance;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เครื่องมือร้านค้า',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(
            children: [
              SellerToolTile(
                icon: Icons.storefront_outlined,
                label: 'รายละเอียดร้านค้า',
                onTap: onSettings,
              ),
              const SizedBox(width: 8),
              SellerToolTile(
                icon: Icons.add_photo_alternate_outlined,
                label: 'เพิ่มสินค้า',
                onTap: onAddProduct,
              ),
              const SizedBox(width: 8),
              SellerToolTile(
                icon: Icons.inventory_2_outlined,
                label: 'สินค้าของฉัน',
                onTap: onProducts,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SellerToolTile(
                icon: Icons.receipt_long_outlined,
                label: 'ออเดอร์ร้านค้า',
                onTap: onOrders,
              ),
              const SizedBox(width: 8),
              SellerToolTile(
                icon: Icons.local_shipping_outlined,
                label: 'ช่องทางขนส่ง',
                onTap: onShipping,
              ),
              const SizedBox(width: 8),
              SellerToolTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'ยอดเงินร้าน',
                onTap: onBalance,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SellerToolTile extends StatelessWidget {
  const SellerToolTile(
      {super.key, required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: ink, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerMenuEntry {
  const SellerMenuEntry(this.icon, this.title, this.route);

  final IconData icon;
  final String title;
  final String route;
}

class SellerMenuList extends StatelessWidget {
  const SellerMenuList({super.key, required this.entries});

  final List<SellerMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            InkWell(
              onTap: () => Navigator.of(context).pushNamed(entries[i].route),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(
                  children: [
                    Icon(entries[i].icon, color: accent, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        entries[i].title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
            ),
            if (i != entries.length - 1) const Divider(height: 1, indent: 52),
          ],
        ],
      ),
    );
  }
}

class SellerDeliveryScreen extends StatefulWidget {
  const SellerDeliveryScreen({super.key});

  @override
  State<SellerDeliveryScreen> createState() => _SellerDeliveryScreenState();
}

class _SellerDeliveryScreenState extends State<SellerDeliveryScreen> {
  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final orders = appStore.orders;
    final waitingOrders = orders
        .where((order) =>
            order.status.contains('รอ') || order.status.contains('จัดส่ง'))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('การจัดส่งของฉัน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MeSectionRow(
                  title: 'ช่องทางขนส่งที่เปิดใช้',
                  action: 'ตั้งค่า',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/seller/shipping'),
                ),
                const Divider(height: 1),
                const SellerCarrierRow(name: 'Flash Express', enabled: true),
                const SellerCarrierRow(name: 'KEX', enabled: true),
                const SellerCarrierRow(name: 'Express', enabled: true),
                const SellerCarrierRow(name: 'ไปรษณีย์ไทย', enabled: true),
                const SellerCarrierRow(name: 'J&T Express', enabled: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CheckoutCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeSectionRow(
                  title: 'ออเดอร์ที่ต้องจัดส่ง',
                  action: 'ดูทั้งหมด',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/seller/orders'),
                ),
                const Divider(height: 1),
                if (waitingOrders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'ยังไม่มีออเดอร์ที่ต้องจัดส่ง เมื่อร้านได้รับคำสั่งซื้อ รายการจะมาแสดงที่นี่',
                      style: TextStyle(color: muted, height: 1.35),
                    ),
                  )
                else
                  for (final order in waitingOrders)
                    SellerDeliveryOrderRow(order: order),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SellerCarrierRow extends StatelessWidget {
  const SellerCarrierRow(
      {super.key, required this.name, required this.enabled});

  final String name;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              color: enabled ? const Color(0xFF10A884) : muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            enabled ? 'เปิดใช้' : 'ปิด',
            style: TextStyle(
              color: enabled ? const Color(0xFF10A884) : muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerDeliveryOrderRow extends StatelessWidget {
  const SellerDeliveryOrderRow({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final item = order.items.first;
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/seller/orders'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            ProductThumb(url: item.product.imageUrl, size: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.status} · ${order.carrier}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class SellerSimpleScreen extends StatelessWidget {
  const SellerSimpleScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(icon, color: accent, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final query = TextEditingController();
  String selectedTab = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
    query.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    query.removeListener(_refresh);
    query.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final products = appStore.sellerProducts;
    final filteredProducts = products.where((product) {
      final status = appStore.sellerProductStatus(product);
      final matchesTab = selectedTab == 'ทั้งหมด' || status == selectedTab;
      final keyword = query.text.trim().toLowerCase();
      final matchesQuery = keyword.isEmpty ||
          product.name.toLowerCase().contains(keyword) ||
          product.category.toLowerCase().contains(keyword) ||
          product.id.toLowerCase().contains(keyword);
      return matchesTab && matchesQuery;
    }).toList();
    final tabs = ['ทั้งหมด', 'กำลังขาย', 'หมดสต๊อก', 'ปิดการขาย', 'แบบร่าง'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('สินค้าของฉัน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'สินค้าของร้าน ${products.length} รายการ',
                        style: const TextStyle(
                            color: ink, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SellerProductFormScreen()),
                      ),
                      child: const Text('เพิ่มสินค้า'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: query,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อสินค้า, หมวดหมู่, SKU',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tab),
                            selected: selectedTab == tab,
                            selectedColor: softAccent,
                            labelStyle: TextStyle(
                              color: selectedTab == tab ? accent : muted,
                              fontWeight: FontWeight.w800,
                            ),
                            side: BorderSide(
                              color: selectedTab == tab ? accent : line,
                            ),
                            onSelected: (_) =>
                                setState(() => selectedTab = tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const SellerProductEmptyCard()
          else if (filteredProducts.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'ไม่พบสินค้า',
              message: 'ลองเปลี่ยนคำค้นหาหรือเลือกแท็บสินค้าอื่น',
            )
          else
            for (final product in filteredProducts)
              CheckoutCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: SellerProductManageRow(product: product),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SellerProductFormScreen()),
            ),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('เพิ่มสินค้าใหม่'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
          ),
        ),
      ),
    );
  }
}

class SellerProductEmptyCard extends StatelessWidget {
  const SellerProductEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CheckoutCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(Icons.add_box_outlined, color: muted, size: 52),
          SizedBox(height: 10),
          Text(
            'ยังไม่มีสินค้า',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'เพิ่มสินค้าแรกเพื่อให้ลูกค้าเห็นในหน้าแรก ค้นหา และหน้าร้านของคุณ',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  String selectedTab = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final orders = appStore.orders;
    final filteredOrders = orders
        .where((order) =>
            selectedTab == 'ทั้งหมด' ||
            sellerOrderTabForStatus(order.status) == selectedTab)
        .toList();
    final seller = appStore.sellerProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ออเดอร์ร้านค้า'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          seller?.shopName ?? 'ร้านค้าของฉัน',
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SellerOrderTabs(
                  orders: orders,
                  selectedTab: selectedTab,
                  onChanged: (tab) => setState(() => selectedTab = tab),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (filteredOrders.isEmpty)
            const SellerEmptyOrderCard()
          else
            for (final order in filteredOrders) SellerOrderCard(order: order),
        ],
      ),
    );
  }
}

class SellerOrderTabs extends StatelessWidget {
  const SellerOrderTabs({
    super.key,
    required this.orders,
    required this.selectedTab,
    required this.onChanged,
  });

  final List<Order> orders;
  final String selectedTab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabLabels = [
      'ทั้งหมด',
      'รอยืนยัน',
      'รอจัดส่ง',
      'กำลังจัดส่ง',
      'สำเร็จ',
      'ยกเลิก',
      'คืนสินค้า',
    ];
    int countFor(String tab) => tab == 'ทั้งหมด'
        ? orders.length
        : orders
            .where((order) => sellerOrderTabForStatus(order.status) == tab)
            .length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            for (final tab in tabLabels)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selectedTab == tab,
                  showCheckmark: false,
                  label: Text('$tab (${countFor(tab)})'),
                  labelStyle: TextStyle(
                    color: selectedTab == tab ? Colors.white : ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  selectedColor: accent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selectedTab == tab ? accent : line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onSelected: (_) => onChanged(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SellerEmptyOrderCard extends StatelessWidget {
  const SellerEmptyOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: muted.withValues(alpha: 0.7), size: 54),
          const SizedBox(height: 10),
          const Text(
            'ยังไม่มีออเดอร์ร้านค้า',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'เมื่อลูกค้าสั่งซื้อสินค้าของร้าน ออเดอร์จะเข้ามาที่หน้านี้เพื่อเตรียมจัดส่งและอัปเดตสถานะ',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({super.key, required this.order});

  final Order order;

  String get nextStatus {
    if (order.status == 'รอร้านยืนยัน') return 'รอจัดส่ง';
    if (order.status == 'รอจัดส่ง') return 'ส่งแล้ว';
    if (order.status == 'ส่งแล้ว') return 'สำเร็จ';
    return order.status;
  }

  String get actionLabel {
    if (order.status == 'รอร้านยืนยัน') return 'ยืนยันออเดอร์';
    if (order.status == 'รอจัดส่ง') return 'ส่งสินค้า';
    if (order.status == 'ส่งแล้ว') return 'ปิดงานสำเร็จ';
    return 'สำเร็จแล้ว';
  }

  Future<void> _advanceOrder(BuildContext context) async {
    if (order.status == 'รอจัดส่ง') {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SellerOrderStatusSheet(order: order),
      );
      return;
    }

    await appStore.updateOrderShipping(
      orderId: order.id,
      status: nextStatus,
      carrier: order.carrier == 'ยังไม่ได้เลือกขนส่ง'
          ? 'Flash Express'
          : order.carrier,
      trackingNumber: order.trackingNumber.isEmpty
          ? 'NP${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}'
          : order.trackingNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.id,
                  style:
                      const TextStyle(color: ink, fontWeight: FontWeight.w900),
                ),
              ),
              ProductMiniTag(label: order.status, filled: true),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ProductThumb(url: item.product.imageUrl, size: 54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.color}, ${item.size} x${item.quantity}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatBaht(item.total),
                    style: const TextStyle(
                        color: accent, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'รวม ${order.items.length} รายการ',
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
              ),
              Text(
                formatBaht(order.grandTotal),
                style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SellerOrderDetailScreen(order: order),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: const BorderSide(color: accent),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('รายละเอียดออเดอร์'),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: order.status == 'สำเร็จ'
                  ? null
                  : () => _advanceOrder(context),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerOrderDetailScreen extends StatelessWidget {
  const SellerOrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final liveOrder = appStore.orders.firstWhere(
          (item) => item.id == order.id,
          orElse: () => order,
        );
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('รายละเอียดออเดอร์'),
            backgroundColor: Colors.white,
            foregroundColor: ink,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              CheckoutCard(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveOrder.id,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'สร้างเมื่อ ${formatDate(liveOrder.createdAt)}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ProductMiniTag(label: liveOrder.status, filled: true),
                  ],
                ),
              ),
              CheckoutCard(
                child: DetailInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'ข้อมูลลูกค้าและที่อยู่จัดส่ง',
                  value: liveOrder.address,
                ),
              ),
              CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'รายการสินค้า',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    for (final item in liveOrder.items)
                      CheckoutItemRow(item: item),
                  ],
                ),
              ),
              CheckoutCard(
                child: Column(
                  children: [
                    CheckoutLine(
                      label: 'วิธีชำระเงิน',
                      value: liveOrder.paymentMethod,
                    ),
                    CheckoutLine(label: 'ขนส่ง', value: liveOrder.carrier),
                    CheckoutLine(
                      label: 'เลขพัสดุ',
                      value: liveOrder.trackingNumber.isEmpty
                          ? 'ยังไม่ได้กรอก'
                          : liveOrder.trackingNumber,
                    ),
                    CheckoutLine(
                      label: 'ยอดชำระ',
                      value: formatBaht(liveOrder.grandTotal),
                      strong: true,
                    ),
                  ],
                ),
              ),
              CheckoutCard(child: OrderTrackingBlock(order: liveOrder)),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: FilledButton(
                onPressed: liveOrder.status == 'สำเร็จ'
                    ? null
                    : () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (_) =>
                              SellerOrderStatusSheet(order: liveOrder),
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                child: const Text('อัปเดตสถานะออเดอร์'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SellerOrderStatusSheet extends StatefulWidget {
  const SellerOrderStatusSheet({super.key, required this.order});

  final Order order;

  @override
  State<SellerOrderStatusSheet> createState() => _SellerOrderStatusSheetState();
}

class _SellerOrderStatusSheetState extends State<SellerOrderStatusSheet> {
  static const carriers = [
    'Flash Express',
    'KEX',
    'Express',
    'ไปรษณีย์ไทย',
    'J&T Express',
  ];

  late String selectedCarrier;
  late final TextEditingController trackingController;

  @override
  void initState() {
    super.initState();
    selectedCarrier = carriers.contains(widget.order.carrier)
        ? widget.order.carrier
        : carriers.first;
    trackingController = TextEditingController(
      text: widget.order.trackingNumber.isEmpty
          ? 'NP${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}'
          : widget.order.trackingNumber,
    );
  }

  @override
  void dispose() {
    trackingController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (widget.order.status == 'รอร้านยืนยัน') {
      await appStore.updateOrderShipping(
        orderId: widget.order.id,
        status: 'รอจัดส่ง',
        carrier: 'ยังไม่ได้เลือกขนส่ง',
        trackingNumber: '',
      );
    } else if (widget.order.status == 'รอจัดส่ง') {
      await appStore.updateOrderShipping(
        orderId: widget.order.id,
        status: 'ส่งแล้ว',
        carrier: selectedCarrier,
        trackingNumber: trackingController.text.trim(),
      );
    } else if (widget.order.status == 'ส่งแล้ว') {
      await appStore.updateOrderShipping(
        orderId: widget.order.id,
        status: 'สำเร็จ',
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final order = widget.order;
    final isReadyToShip = order.status == 'รอจัดส่ง';
    final title = order.status == 'รอร้านยืนยัน'
        ? 'ยืนยันออเดอร์'
        : isReadyToShip
            ? 'จัดส่งสินค้า'
            : 'ปิดงานสำเร็จ';
    final buttonLabel = order.status == 'รอร้านยืนยัน'
        ? 'ยืนยันออเดอร์'
        : isReadyToShip
            ? 'ยืนยันจัดส่ง'
            : 'ยืนยันสำเร็จ';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, 14 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CheckoutCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    CheckoutLine(label: 'เลขคำสั่งซื้อ', value: order.id),
                    CheckoutLine(label: 'สถานะปัจจุบัน', value: order.status),
                    CheckoutLine(
                      label: 'ยอดชำระ',
                      value: formatBaht(order.grandTotal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (order.status == 'รอร้านยืนยัน')
                const Text(
                  'ยืนยันแล้วออเดอร์จะย้ายไปสถานะรอจัดส่ง เพื่อให้ร้านเลือกขนส่งและกรอกเลขพัสดุในขั้นตอนถัดไป',
                  style: TextStyle(color: muted, height: 1.35),
                )
              else if (isReadyToShip) ...[
                const Text(
                  'เลือกขนส่ง',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final carrier in carriers)
                      ChoiceChip(
                        selected: selectedCarrier == carrier,
                        showCheckmark: false,
                        label: Text(carrier),
                        selectedColor: accent,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selectedCarrier == carrier ? accent : line,
                        ),
                        labelStyle: TextStyle(
                          color:
                              selectedCarrier == carrier ? Colors.white : ink,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) =>
                            setState(() => selectedCarrier = carrier),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackingController,
                  decoration: InputDecoration(
                    labelText: 'เลขพัสดุ',
                    hintText: 'กรอกเลขพัสดุจากขนส่ง',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: accent),
                    ),
                  ),
                ),
              ] else if (order.status == 'ส่งแล้ว')
                const Text(
                  'ตรวจสอบการจัดส่งแล้วปิดงานสำเร็จ ลูกค้าจะเห็นสถานะได้รับสินค้าและสามารถให้คะแนนได้',
                  style: TextStyle(color: muted, height: 1.35),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerProductList extends StatelessWidget {
  const SellerProductList({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สินค้าของร้าน',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Text('ยังไม่มีสินค้า เพิ่มสินค้าแรกเพื่อเปิดขาย',
                style: TextStyle(color: muted, fontSize: 13))
          else
            for (final product in products) SellerProductRow(product: product),
        ],
      ),
    );
  }
}

class SellerProductRow extends StatelessWidget {
  const SellerProductRow({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ProductThumb(url: product.imageUrl, size: 58),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${formatBaht(product.price)} · คลัง ${product.stock}',
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          const ProductMiniTag(label: 'เปิดขาย', filled: true),
        ],
      ),
    );
  }
}

class SellerProductManageRow extends StatelessWidget {
  const SellerProductManageRow({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final status = appStore.sellerProductStatus(product);
    final active = status == 'กำลังขาย';
    return Column(
      children: [
        Row(
          children: [
            ProductThumb(url: product.imageUrl, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatBaht(product.price)} · คลัง ${product.stock}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ขายแล้ว ${product.soldCount} · ${product.location}',
                    style: const TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            ProductMiniTag(label: status, filled: active),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SellerProductFormScreen(product: product),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: const BorderSide(color: line),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('แก้ไข'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => appStore.updateSellerProductStatus(
                  product,
                  active ? 'ปิดการขาย' : 'กำลังขาย',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: const BorderSide(color: line),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(active ? 'ปิดการขาย' : 'เปิดขาย'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await appStore.deleteSellerProduct(product);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: muted,
                  side: const BorderSide(color: line),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('ลบ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SellerShippingSettingsScreen extends StatefulWidget {
  const SellerShippingSettingsScreen({super.key});

  @override
  State<SellerShippingSettingsScreen> createState() =>
      _SellerShippingSettingsScreenState();
}

class _SellerShippingSettingsScreenState
    extends State<SellerShippingSettingsScreen> {
  static const carrierNames = [
    'Flash Express',
    'KEX',
    'Express',
    'ไปรษณีย์ไทย',
    'J&T Express',
  ];

  late final Set<String> enabled;
  String preferred = 'Flash Express';

  @override
  void initState() {
    super.initState();
    final seller = appStore.sellerProfile;
    enabled = {
      ...(seller?.enabledCarriers.isNotEmpty == true
          ? seller!.enabledCarriers
          : carrierNames),
    };
    preferred = seller != null &&
            seller.enabledCarriers.isNotEmpty &&
            enabled.contains(seller.enabledCarriers.first)
        ? seller.enabledCarriers.first
        : enabled.first;
  }

  void _save() {
    final seller = appStore.sellerProfile;
    if (seller == null) {
      Navigator.of(context).pop();
      return;
    }
    final carriers = [
      if (enabled.contains(preferred)) preferred,
      ...enabled.where((item) => item != preferred),
    ];
    appStore.openSellerShop(SellerProfile(
      shopName: seller.shopName,
      category: seller.category,
      ownerName: seller.ownerName,
      phone: seller.phone,
      address: seller.address,
      description: seller.description,
      pickupProvince: seller.pickupProvince,
      enabledCarriers: carriers,
      logoUrl: seller.logoUrl,
      isVerified: seller.isVerified,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ตั้งค่าการจัดส่ง'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
        children: [
          CheckoutCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                ShippingChannelHeader(
                  title: 'ช่องทางขนส่งที่ร้านเปิดใช้',
                  subtitle:
                      'ลูกค้าจะเลือกขนส่งจากรายการที่ร้านเปิดไว้ในขั้นตอน Checkout',
                ),
                for (final carrier in carrierNames)
                  SellerCarrierTile(
                    carrier: carrier,
                    enabled: enabled.contains(carrier),
                    preferred: preferred == carrier,
                    onEnabledChanged: (value) {
                      setState(() {
                        if (value) {
                          enabled.add(carrier);
                          preferred = carrier;
                        } else if (enabled.length > 1) {
                          enabled.remove(carrier);
                          if (preferred == carrier) preferred = enabled.first;
                        }
                      });
                    },
                    onPreferred: () {
                      if (!enabled.contains(carrier)) return;
                      setState(() => preferred = carrier);
                    },
                  ),
              ],
            ),
          ),
          CheckoutCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'หลังลูกค้าสั่งซื้อ ร้านสามารถเลือกขนส่งและใส่เลขพัสดุในหน้าออเดอร์ร้านค้า สถานะจะไปแสดงให้ลูกค้าดูในรายละเอียดคำสั่งซื้อ',
                    style:
                        TextStyle(color: muted, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: const Text('บันทึก'),
          ),
        ),
      ),
    );
  }
}

class ShippingChannelHeader extends StatelessWidget {
  const ShippingChannelHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping_outlined, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: ink, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: muted, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SellerCarrierTile extends StatelessWidget {
  const SellerCarrierTile({
    super.key,
    required this.carrier,
    required this.enabled,
    required this.preferred,
    required this.onEnabledChanged,
    required this.onPreferred,
  });

  final String carrier;
  final bool enabled;
  final bool preferred;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onPreferred;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              preferred ? Icons.check_circle : Icons.local_shipping_outlined,
              color: preferred ? accent : muted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onPreferred,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            carrier,
                            style: const TextStyle(
                                color: ink, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (preferred) ...[
                          const SizedBox(width: 6),
                          const ProductMiniTag(label: 'Preferred'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text('ส่งธรรมดาในประเทศ · รองรับเลขพัสดุ',
                        style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: const Color(0xFF22B573),
              onChanged: onEnabledChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class SellerBalanceScreen extends StatelessWidget {
  const SellerBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completedOrders =
        appStore.orders.where((order) => order.status == 'สำเร็จ').toList();
    final pendingOrders = appStore.orders
        .where((order) => order.status != 'สำเร็จ' && order.status != 'ยกเลิก')
        .toList();
    final available = completedOrders.fold<double>(
        0, (total, order) => total + order.grandTotal);
    final pending = pendingOrders.fold<double>(
        0, (total, order) => total + order.grandTotal);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ยอดเงินร้าน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่ายอดเงิน',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                const Text('ยอดเงินที่ถอนได้',
                    style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 8),
                Text(formatBaht(available),
                    style: const TextStyle(
                        color: accent,
                        fontSize: 34,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.account_balance_outlined),
                        label: const Text('ถอนเงิน'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('รายการเงิน'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CheckoutCard(
            child: Column(
              children: [
                SellerBalanceLine(
                    label: 'รอโอนเข้ายอดเงินร้าน', value: pending),
                const Divider(height: 20),
                SellerBalanceLine(
                    label: 'ออเดอร์สำเร็จ', value: available, highlight: true),
              ],
            ),
          ),
          const CheckoutCard(
            child: Text(
              'เมื่อออเดอร์สำเร็จ ระบบจะย้ายยอดขายมายังยอดเงินร้าน จากนั้นร้านจึงกดถอนเงินได้ ภายหลังสามารถเชื่อมบัญชีธนาคารจริงกับ Supabase ได้',
              style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class SellerBalanceLine extends StatelessWidget {
  const SellerBalanceLine({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: highlight ? ink : muted,
                  fontWeight: highlight ? FontWeight.w900 : FontWeight.w600)),
        ),
        Text(formatBaht(value),
            style: TextStyle(
                color: highlight ? accent : ink,
                fontWeight: FontWeight.w900,
                fontSize: highlight ? 18 : 14)),
      ],
    );
  }
}

class OpenShopScreen extends StatefulWidget {
  const OpenShopScreen({super.key});

  @override
  State<OpenShopScreen> createState() => _OpenShopScreenState();
}

class _OpenShopScreenState extends State<OpenShopScreen> {
  late final TextEditingController ownerName;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController bankAccountName;
  late final TextEditingController bankAccountNumber;
  late final TextEditingController bankName;
  AddressArea? pickupArea;
  UploadedShopFile? identityCardFile;
  UploadedShopFile? bankBookFile;
  Uint8List? identityCardPreview;
  Uint8List? bankBookPreview;
  bool isUploadingShopFile = false;
  final carriers = <String>{
    'Flash Express',
    'KEX',
    'Express',
    'ไปรษณีย์ไทย',
    'J&T Express',
  };

  @override
  void initState() {
    super.initState();
    final seller = appStore.sellerProfile;
    ownerName = TextEditingController(text: seller?.ownerName ?? '');
    phone = TextEditingController(text: seller?.phone ?? '');
    address = TextEditingController(text: seller?.address ?? '');
    bankAccountName = TextEditingController(
      text: seller?.bankAccountName.isNotEmpty == true
          ? seller!.bankAccountName
          : seller?.ownerName ?? '',
    );
    bankAccountNumber =
        TextEditingController(text: seller?.bankAccountNumber ?? '');
    bankName = TextEditingController(text: seller?.bankName ?? '');
    if (seller != null &&
        seller.pickupProvince.isNotEmpty &&
        seller.pickupDistrict.isNotEmpty &&
        seller.pickupSubDistrict.isNotEmpty &&
        seller.pickupPostcode.isNotEmpty) {
      pickupArea = AddressArea(
        province: seller.pickupProvince,
        district: seller.pickupDistrict,
        subDistrict: seller.pickupSubDistrict,
        postcode: seller.pickupPostcode,
      );
      address.text = cleanPickupDetail(address.text, pickupArea!);
    }
  }

  @override
  void dispose() {
    ownerName.dispose();
    phone.dispose();
    address.dispose();
    bankAccountName.dispose();
    bankAccountNumber.dispose();
    bankName.dispose();
    super.dispose();
  }

  Future<void> _pickShopFile(String kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถอ่านไฟล์นี้ได้')),
      );
      return;
    }
    setState(() => isUploadingShopFile = true);
    try {
      final uploaded = await appStore.uploadSellerFile(
        kind: kind,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        if (kind == 'identity-card') {
          identityCardFile = uploaded;
          identityCardPreview = Uint8List.fromList(bytes);
        }
        if (kind == 'bank-book') {
          bankBookFile = uploaded;
          bankBookPreview = Uint8List.fromList(bytes);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => isUploadingShopFile = false);
    }
  }

  Future<void> _saveShop() async {
    final existingSeller = appStore.sellerProfile;
    final isEditingShop = existingSeller?.id.isNotEmpty ?? false;
    final missingRequired = [
      ownerName,
      phone,
      address,
      bankAccountName,
      bankAccountNumber,
      bankName,
    ].any((controller) => controller.text.trim().isEmpty);
    if (missingRequired ||
        pickupArea == null ||
        (!isEditingShop && identityCardFile == null) ||
        (!isEditingShop && bankBookFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลร้านค้าที่จำเป็นให้ครบ')),
      );
      return;
    }
    final area = pickupArea!;
    final pickupDetail = cleanPickupDetail(address.text, area);
    final accountName = appStore.customerAccount?.nameOrEmail ?? '';
    final requestDisplayName = ownerName.text.trim().isNotEmpty
        ? ownerName.text.trim()
        : (accountName.isNotEmpty ? accountName : 'ผู้ขอเปิดร้าน');
    await appStore.openSellerShop(
        SellerProfile(
          id: existingSeller?.id ?? '',
          shopName: existingSeller?.shopName.isNotEmpty == true
              ? existingSeller!.shopName
              : requestDisplayName,
          category: existingSeller?.category.isNotEmpty == true
              ? existingSeller!.category
              : 'รอตั้งค่าหลังอนุมัติ',
          ownerName: requestDisplayName,
          phone: phone.text.trim(),
          address: pickupDetail,
          description: existingSeller?.description ?? '',
          pickupProvince: area.province,
          pickupDistrict: area.district,
          pickupSubDistrict: area.subDistrict,
          pickupPostcode: area.postcode,
          enabledCarriers: carriers.toList(),
          logoUrl: existingSeller?.logoUrl ?? '',
          identityCardUrl:
              identityCardFile?.url ?? existingSeller?.identityCardUrl ?? '',
          bankBookUrl: bankBookFile?.url ?? existingSeller?.bankBookUrl ?? '',
          bankAccountName: bankAccountName.text.trim(),
          bankAccountNumber: bankAccountNumber.text.trim(),
          bankName: bankName.text.trim(),
          isVerified: existingSeller?.isVerified ?? false,
        ),
        identityCardUrl: identityCardFile?.url ?? '',
        bankBookUrl: bankBookFile?.url ?? '',
        identityCardPath: identityCardFile?.path ?? '',
        bankBookPath: bankBookFile?.path ?? '');
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasShop = appStore.hasSellerShop;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(hasShop ? 'การตั้งค่าร้านค้า' : 'ข้อมูลร้านค้า'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveShop,
            child: const Text('บันทึก'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
        children: [
          SellerSetupStepper(currentStep: hasShop ? 2 : 1),
          if (!hasShop)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              color: const Color(0xFFFFF7DF),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFE0A300), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กรอกข้อมูลร้านค้าให้ครบก่อนเริ่มลงสินค้า หลังจากเปิดร้านแล้วสามารถแก้ไขรายละเอียดร้านค้าได้',
                      style:
                          TextStyle(color: ink, fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          SellerEditSection(
            children: [
              SellerPickupAddressBlock(
                ownerName: ownerName,
                phone: phone,
                detail: address,
                bankAccountName: bankAccountName,
                bankAccountNumber: bankAccountNumber,
                bankName: bankName,
                identityDocument: SellerDocumentUploadCard(
                    icon: Icons.badge_outlined,
                    title: 'สำเนาบัตรประชาชน',
                    value: identityCardFile == null &&
                            (appStore.sellerProfile?.identityCardUrl ?? '')
                                .isEmpty
                        ? 'เพิ่มไฟล์'
                        : 'แนบแล้ว',
                    previewBytes: identityCardPreview,
                    previewUrl: appStore.sellerProfile?.identityCardUrl ?? '',
                    onTap: isUploadingShopFile
                        ? null
                        : () => _pickShopFile('identity-card')),
                bankBookDocument: SellerDocumentUploadCard(
                    icon: Icons.account_balance_outlined,
                    title: 'หน้าสมุดบัญชี',
                    value: bankBookFile == null &&
                            (appStore.sellerProfile?.bankBookUrl ?? '').isEmpty
                        ? 'เพิ่มไฟล์'
                        : 'แนบแล้ว',
                    previewBytes: bankBookPreview,
                    previewUrl: appStore.sellerProfile?.bankBookUrl ?? '',
                    onTap: isUploadingShopFile
                        ? null
                        : () => _pickShopFile('bank-book')),
                area: pickupArea,
                areaText: pickupArea == null
                    ? 'จังหวัด, เขต/อำเภอ, แขวง/ตำบล, รหัสไปรษณีย์'
                    : pickupArea!.displayText,
                hasArea: pickupArea != null,
                onSelectArea: () async {
                  final value = await Navigator.of(context).push<AddressArea>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AreaSelectionScreen(selectedArea: pickupArea),
                    ),
                  );
                  if (value != null) {
                    setState(() {
                      pickupArea = value;
                      address.text = cleanPickupDetail(address.text, value);
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton(
            onPressed: _saveShop,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: Text(hasShop ? 'บันทึกข้อมูลร้านค้า' : 'บันทึกและเปิดร้าน'),
          ),
        ),
      ),
    );
  }
}

class SellerSetupStepper extends StatelessWidget {
  const SellerSetupStepper({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              SellerStepDot(active: currentStep >= 1),
              Expanded(
                child: Container(
                  height: 1.5,
                  color: currentStep >= 2 ? accent : line,
                ),
              ),
              SellerStepDot(active: currentStep >= 2),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Shop Information',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: accent, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Identity Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SellerStepDot extends StatelessWidget {
  const SellerStepDot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: active ? accent : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: accent),
      ),
      child: active
          ? const Icon(Icons.check, color: Colors.white, size: 13)
          : null,
    );
  }
}

class SellerShopLogoRow extends StatelessWidget {
  const SellerShopLogoRow({super.key, required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDEF),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.storefront_outlined, color: accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop Logo',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  shopName.trim().isEmpty ? 'เพิ่มโลโก้ร้านค้า' : shopName,
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class SellerProductFormScreen extends StatefulWidget {
  const SellerProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  final name = TextEditingController();
  final category = TextEditingController();
  final price = TextEditingController();
  final originalPrice = TextEditingController();
  final stock = TextEditingController();
  final imageUrl = TextEditingController();
  final videoUrl = TextEditingController();
  final sizeChartUrl = TextEditingController();
  final sku = TextEditingController();
  final weight = TextEditingController();
  final parcelSize = TextEditingController();
  final shipFrom = TextEditingController();
  final colors = TextEditingController();
  final sizes = TextEditingController();
  final description = TextEditingController();
  String imageFileName = '';
  String videoFileName = '';
  bool isSaving = false;
  bool isUploadingImage = false;
  bool isUploadingVideo = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    name.text = product.name;
    category.text = product.category;
    price.text = product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2);
    originalPrice.text = product.originalPrice
        .toStringAsFixed(product.originalPrice % 1 == 0 ? 0 : 2);
    stock.text = product.stock.toString();
    imageUrl.text = product.imageUrl;
    videoUrl.text = product.videoUrl;
    sizeChartUrl.text = product.sizeChartImageUrl ?? '';
    shipFrom.text = product.location;
    colors.text = product.colorOptions.join(', ');
    sizes.text = product.sizeOptions.join(', ');
  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    price.dispose();
    originalPrice.dispose();
    stock.dispose();
    imageUrl.dispose();
    videoUrl.dispose();
    sizeChartUrl.dispose();
    sku.dispose();
    weight.dispose();
    parcelSize.dispose();
    shipFrom.dispose();
    colors.dispose();
    sizes.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _pickProductMedia(String kind) async {
    final seller = appStore.sellerProfile;
    if (seller == null || !seller.isVerified) {
      showSellerApprovalPending(context);
      return;
    }
    final isVideo = kind == 'video';
    setState(() {
      if (isVideo) {
        isUploadingVideo = true;
      } else {
        isUploadingImage = true;
      }
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isVideo
            ? const ['mp4', 'mov', 'webm']
            : const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final url = await appStore.uploadProductMedia(
        shopId: seller.id,
        kind: kind,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        if (isVideo) {
          videoUrl.text = url;
          videoFileName = file.name;
        } else {
          imageUrl.text = url;
          imageFileName = file.name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('แนบไฟล์ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isVideo) {
            isUploadingVideo = false;
          } else {
            isUploadingImage = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seller = appStore.sellerProfile;
    Future<void> saveProduct() async {
      if (isSaving) return;
      if (seller == null) return;
      if (!seller.isVerified) {
        showSellerApprovalPending(context);
        return;
      }
      final parsedPrice = double.tryParse(price.text.trim()) ?? 0;
      final parsedOriginal =
          double.tryParse(originalPrice.text.trim()) ?? parsedPrice;
      final parsedStock = int.tryParse(stock.text.trim()) ?? 0;
      final missingRequired = name.text.trim().isEmpty ||
          category.text.trim().isEmpty ||
          parsedPrice <= 0 ||
          parsedStock <= 0 ||
          imageUrl.text.trim().isEmpty ||
          shipFrom.text.trim().isEmpty;
      if (missingRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกข้อมูลสินค้าที่จำเป็นให้ครบ')),
        );
        return;
      }
      final discount = parsedOriginal > parsedPrice && parsedOriginal > 0
          ? (((parsedOriginal - parsedPrice) / parsedOriginal) * 100).round()
          : 0;
      setState(() => isSaving = true);
      final product = Product(
        id: widget.product?.id ??
            'seller-${DateTime.now().millisecondsSinceEpoch}',
        shopId: seller.id,
        name: name.text.trim(),
        shopName: seller.shopName,
        category: category.text.trim(),
        price: parsedPrice,
        originalPrice: parsedOriginal <= 0 ? parsedPrice : parsedOriginal,
        rating: widget.product?.rating ?? 0,
        soldCount: widget.product?.soldCount ?? 0,
        imageUrl: imageUrl.text.trim(),
        badge: '',
        location: shipFrom.text.trim(),
        shippingLabel: 'ส่งฟรี',
        serviceLabel: seller.shopName,
        promoLabel: '',
        discountPercent: discount,
        isVideo: videoUrl.text.trim().isNotEmpty,
        videoViews: videoUrl.text.trim().isEmpty ? '' : 'ใหม่',
        videoUrl: videoUrl.text.trim(),
        stock: parsedStock,
        colorOptions: splitOptions(colors.text),
        sizeOptions: splitOptions(sizes.text),
        sizeChartImageUrl:
            sizeChartUrl.text.trim().isEmpty ? null : sizeChartUrl.text.trim(),
      );
      try {
        if (widget.product == null) {
          await appStore.addSellerProduct(
            product,
            description: description.text.trim(),
            sku: sku.text.trim(),
            weightKg: double.tryParse(weight.text.trim()) ?? 0,
            parcelSize: parcelSize.text.trim(),
          );
        } else {
          await appStore.updateSellerProduct(
            product,
            description: description.text.trim(),
            sku: sku.text.trim(),
            weightKg: double.tryParse(weight.text.trim()) ?? 0,
            parcelSize: parcelSize.text.trim(),
          );
        }
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกสินค้าไม่สำเร็จ: $error')),
        );
        return;
      } finally {
        if (mounted) setState(() => isSaving = false);
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('เพิ่มสินค้า'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          TextButton(
            onPressed:
                seller == null || !seller.isVerified ? null : saveProduct,
            child: const Text('ส่ง'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
        children: [
          SellerMediaSection(
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            imageFileName: imageFileName,
            videoFileName: videoFileName,
            isUploadingImage: isUploadingImage,
            isUploadingVideo: isUploadingVideo,
            onPickImage: () => _pickProductMedia('image'),
            onPickVideo: () => _pickProductMedia('video'),
            onClearImage: () => setState(() {
              imageUrl.clear();
              imageFileName = '';
            }),
            onClearVideo: () => setState(() {
              videoUrl.clear();
              videoFileName = '';
            }),
          ),
          SellerEditSection(
            children: [
              SellerInlineTextField(
                controller: name,
                label: 'ชื่อสินค้า',
                hint: 'ใส่ตัวอักษรเพิ่มอีก 20 ตัวอักษร',
                required: true,
              ),
              SellerInlineTextField(
                controller: description,
                label: 'รายละเอียดสินค้า',
                hint: 'ใส่ตัวอักษรเพิ่มอีก 25 ตัวอักษร',
                required: true,
                maxLines: 3,
              ),
            ],
          ),
          SellerEditSection(
            children: [
              DropdownButtonFormField<String>(`r`n                initialValue: shopeeProductCategories.contains(category.text)
                    ? category.text
                    : null,
                items: shopeeProductCategories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => category.text = value);
                },
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่สินค้า',
                  prefixIcon: Icon(Icons.list_alt_outlined),
                  filled: true,
                  fillColor: Color(0xFFF6F6F6),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
          SellerEditSection(
            children: [
              SellerFieldGrid(
                children: [
                  SellerCompactFormField(
                    controller: price,
                    label: 'ราคา',
                    hint: 'ตั้งราคา',
                    required: true,
                    keyboardType: TextInputType.number,
                  ),
                  SellerCompactFormField(
                    controller: originalPrice,
                    label: 'ราคาก่อนลด',
                    hint: 'ถ้ามี',
                    keyboardType: TextInputType.number,
                  ),
                  SellerCompactFormField(
                    controller: stock,
                    label: 'คลัง',
                    hint: 'จำนวน',
                    required: true,
                    keyboardType: TextInputType.number,
                  ),
                  SellerCompactFormField(
                    controller: sku,
                    label: 'SKU',
                    hint: 'รหัสสินค้า',
                  ),
                ],
              ),
            ],
          ),
          SellerEditSection(
            children: [
              SellerFieldGrid(
                children: [
                  SellerCompactFormField(
                    controller: colors,
                    label: 'สี',
                    hint: 'ขาว, ดำ, เทา',
                  ),
                  SellerCompactFormField(
                    controller: sizes,
                    label: 'ไซส์',
                    hint: 'S, M, L, XL',
                  ),
                ],
              ),
              SellerInlineTextField(
                controller: sizeChartUrl,
                label: 'ตารางขนาดสินค้า',
                hint: 'ลิงก์รูปตารางไซส์ ถ้ามี',
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          SellerEditSection(
            children: [
              SellerFieldGrid(
                children: [
                  SellerCompactFormField(
                    controller: weight,
                    label: 'น้ำหนัก',
                    hint: 'กก.',
                    keyboardType: TextInputType.number,
                  ),
                  SellerCompactFormField(
                    controller: parcelSize,
                    label: 'ขนาดพัสดุ',
                    hint: 'ก x ย x ส',
                  ),
                  SellerCompactFormField(
                    controller: shipFrom,
                    label: 'ส่งจาก',
                    hint: 'จังหวัด',
                  ),
                  const SellerCompactInfoTile(
                    icon: Icons.info_outline,
                    label: 'สภาพ',
                    value: 'ของใหม่',
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Text(
              'ขนส่งที่ร้านเปิดใช้: Flash Express · KEX · Express · ไปรษณีย์ไทย · J&T Express',
              style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton(
            onPressed:
                seller == null || !seller.isVerified ? null : saveProduct,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: const Text('บันทึกและเปิดขาย'),
          ),
        ),
      ),
    );
  }
}

class SellerMediaSection extends StatelessWidget {
  const SellerMediaSection({
    super.key,
    required this.imageUrl,
    required this.videoUrl,
    required this.imageFileName,
    required this.videoFileName,
    required this.isUploadingImage,
    required this.isUploadingVideo,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onClearImage,
    required this.onClearVideo,
  });

  final TextEditingController imageUrl;
  final TextEditingController videoUrl;
  final String imageFileName;
  final String videoFileName;
  final bool isUploadingImage;
  final bool isUploadingVideo;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onClearImage;
  final VoidCallback onClearVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SellerMediaTile(
                label: 'ภาพปก',
                imageUrl: imageUrl.text,
                fileName: imageFileName,
                loading: isUploadingImage,
                onTap: onPickImage,
                onClear: imageUrl.text.trim().isEmpty ? null : onClearImage,
              ),
              const SizedBox(width: 10),
              SellerMediaTile(
                label: 'วิดีโอ',
                icon: Icons.play_circle_outline,
                fileName: videoFileName,
                loading: isUploadingVideo,
                onTap: onPickVideo,
                onClear: videoUrl.text.trim().isEmpty ? null : onClearVideo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SellerCompactUrlField(
            controller: imageUrl,
            label: 'URL รูปปกสินค้า',
          ),
          const SizedBox(height: 8),
          SellerCompactUrlField(
            controller: videoUrl,
            label: 'URL วิดีโอสินค้า ถ้ามี',
          ),
        ],
      ),
    );
  }
}

class SellerMediaTile extends StatelessWidget {
  const SellerMediaTile({
    super.key,
    required this.label,
    this.imageUrl,
    this.fileName = '',
    this.icon = Icons.add_photo_alternate_outlined,
    this.loading = false,
    this.onTap,
    this.onClear,
  });

  final String label;
  final String? imageUrl;
  final String fileName;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return InkWell(
      onTap: loading ? null : onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: accent,
            style: hasImage ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_outlined, color: accent, size: 28),
              )
            else
              Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : fileName.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: accent, size: 21),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          )
                        : Text(
                            fileName,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700),
                          ),
              ),
            if (hasImage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.42),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            if (onClear != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    padding: const EdgeInsets.all(2),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SellerCompactUrlField extends StatelessWidget {
  const SellerCompactUrlField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class SellerEditSection extends StatelessWidget {
  const SellerEditSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 14, color: line),
          ],
        ],
      ),
    );
  }
}

class SellerInlineTextField extends StatelessWidget {
  const SellerInlineTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: muted, fontSize: 15),
              ),
              if (required)
                const Text(' *',
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(color: ink, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: accent),
              filled: true,
              fillColor: const Color(0xFFF0F0F0),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerFieldGrid extends StatelessWidget {
  const SellerFieldGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          );
        },
      ),
    );
  }
}

class SellerCompactFormField extends StatelessWidget {
  const SellerCompactFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 13.5),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: ink, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: muted, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF0F0F0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }
}

class SellerCompactInfoTile extends StatelessWidget {
  const SellerCompactInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: muted, fontSize: 13.5),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          color: const Color(0xFFF0F0F0),
          child: Row(
            children: [
              Icon(icon, color: muted, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: muted, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class SellerFormRow extends StatelessWidget {
  const SellerFormRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Icon(icon, color: muted, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: ink, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class SellerDocumentUploadCard extends StatelessWidget {
  const SellerDocumentUploadCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.previewBytes,
    required this.previewUrl,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Uint8List? previewBytes;
  final String previewUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final attached = previewBytes != null || previewUrl.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: attached ? accent : line),
              ),
              child: attached
                  ? (previewBytes != null
                      ? Image.memory(previewBytes!, fit: BoxFit.cover)
                      : Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: accent, size: 22),
                        ))
                  : Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attached ? 'แตะเพื่อเปลี่ยนรูป' : 'แตะเพื่อเพิ่มรูป',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: attached ? softAccent : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: attached ? accent : line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: attached ? accent : muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    attached ? Icons.check_circle : Icons.add_photo_alternate,
                    color: attached ? accent : muted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerPickupAddressBlock extends StatelessWidget {
  const SellerPickupAddressBlock({
    super.key,
    required this.ownerName,
    required this.phone,
    required this.detail,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.bankName,
    required this.identityDocument,
    required this.bankBookDocument,
    required this.area,
    required this.areaText,
    required this.hasArea,
    required this.onSelectArea,
  });

  final TextEditingController ownerName;
  final TextEditingController phone;
  final TextEditingController detail;
  final TextEditingController bankAccountName;
  final TextEditingController bankAccountNumber;
  final TextEditingController bankName;
  final Widget identityDocument;
  final Widget bankBookDocument;
  final AddressArea? area;
  final String areaText;
  final bool hasArea;
  final VoidCallback onSelectArea;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.local_shipping_outlined, color: accent, size: 20),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลร้านค้า',
                  style: TextStyle(
                      color: ink, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            identityDocument,
            SellerInlineTextField(
              controller: ownerName,
              label: 'ชื่อ-นามสกุล',
              hint: 'ชื่อจริงและนามสกุลของผู้ขอเปิดร้าน',
              required: true,
            ),
            SellerInlineTextField(
              controller: phone,
              label: 'หมายเลขโทรศัพท์',
              hint: 'เบอร์ติดต่อร้านค้า',
              required: true,
              keyboardType: TextInputType.phone,
            ),
            SellerInlineTextField(
              controller: bankAccountName,
              label: 'ชื่อบัญชี',
              hint: 'ชื่อบัญชีธนาคารสำหรับรับเงิน',
              required: true,
            ),
            SellerInlineTextField(
              controller: bankAccountNumber,
              label: 'เลขบัญชี',
              hint: 'เลขบัญชีธนาคาร',
              required: true,
              keyboardType: TextInputType.number,
            ),
            SellerInlineTextField(
              controller: bankName,
              label: 'ธนาคาร',
              hint: 'ชื่อธนาคาร',
              required: true,
            ),
            bankBookDocument,
            SellerInlineTextField(
              controller: detail,
              label: 'รายละเอียดเพิ่มเติม',
              hint: 'บ้านเลขที่ อาคาร หมู่บ้าน ซอย ถนน หรือจุดสังเกต',
              required: true,
              maxLines: 3,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: InkWell(
                onTap: onSelectArea,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    border: Border.all(color: hasArea ? accent : line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.place_outlined,
                            color: hasArea ? accent : muted, size: 20),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: hasArea && area != null
                            ? Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _AreaChip(
                                      label: 'จังหวัด', value: area!.province),
                                  _AreaChip(
                                      label: 'เขต/อำเภอ',
                                      value: area!.district),
                                  _AreaChip(
                                      label: 'แขวง/ตำบล',
                                      value: area!.subDistrict),
                                  _AreaChip(
                                      label: 'ไปรษณีย์', value: area!.postcode),
                                ],
                              )
                            : Text(
                                areaText,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: ink, fontSize: 12.5, height: 1.15),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerUploadRow extends StatelessWidget {
  const SellerUploadRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final attached = value.contains('แนบแล้ว');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            Icon(icon, color: attached ? accent : muted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: ink, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: attached ? accent : muted,
                fontSize: 13,
                fontWeight: attached ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              attached ? Icons.check_circle : Icons.upload_file_outlined,
              color: attached ? accent : muted,
            ),
          ],
        ),
      ),
    );
  }
}

class SellerTextField extends StatelessWidget {
  const SellerTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accent),
          ),
        ),
      ),
    );
  }
}

List<String> splitOptions(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF10A884), size: 86),
              const SizedBox(height: 16),
              const Text('สั่งซื้อสำเร็จ',
                  style: TextStyle(
                      color: ink, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('เลขคำสั่งซื้อ ${order.id}',
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(order: order))),
                style: FilledButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.white),
                child: const Text('ดูรายละเอียดคำสั่งซื้อ'),
              ),
              TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('กลับหน้าแรก')),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var selectedCategory = 'อัปเดตสำคัญ';
  final readIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appStore.loadSellerWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final items = _buildNotificationItems();
        final categories = [
          _NotificationCategory('อัปเดตสำคัญ', Icons.thumb_up_alt_outlined),
          _NotificationCategory('ร้านค้า', Icons.storefront_outlined),
          _NotificationCategory('คำสั่งซื้อ', Icons.receipt_long_outlined),
          _NotificationCategory('ขนส่ง', Icons.local_shipping_outlined),
          _NotificationCategory('ระบบ', Icons.security_outlined),
        ];
        final filtered = selectedCategory == 'อัปเดตสำคัญ'
            ? items
            : items.where((item) => item.category == selectedCategory).toList();
        return Scaffold(
          backgroundColor: const Color(0xFFF6F6F6),
          appBar: AppBar(
            title: const Text('การแจ้งเตือน'),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: ink,
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => Navigator.of(context).pushNamed('/me/chat'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: appStore.loadSellerWorkspace,
            color: accent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Dismissible(
                  key: const ValueKey('notification-permission-banner'),
                  direction: DismissDirection.endToStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    color: const Color(0xFFFFF8DE),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xFFFFA51F),
                          child: Icon(Icons.notifications_active,
                              color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'เปิดการแจ้งเตือนเพื่อรับอัปเดตคำสั่งซื้อ ร้านค้า และการจัดส่ง',
                            style: TextStyle(
                                color: ink, fontSize: 13.5, height: 1.3),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('เปิดใช้งาน'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'อัปเดตล่าสุด',
                          style: TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          readIds.addAll(items.map((item) => item.id));
                        }),
                        child: const Text('อ่านทั้งหมด'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final selected = category.label == selectedCategory;
                      final unreadCount = items
                          .where((item) =>
                              (category.label == 'อัปเดตสำคัญ' ||
                                  item.category == category.label) &&
                              !readIds.contains(item.id))
                          .length;
                      return _NotificationCategoryTab(
                        category: category,
                        selected: selected,
                        count: unreadCount,
                        onTap: () =>
                            setState(() => selectedCategory = category.label),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: categories.length,
                  ),
                ),
                const Divider(height: 1),
                if (!appStore.isSignedIn)
                  EmptyState(
                    icon: Icons.notifications_none,
                    title: 'เข้าสู่ระบบเพื่อดูแจ้งเตือน',
                    message:
                        'รายการแจ้งเตือนของคำสั่งซื้อและร้านค้าจะแสดงหลังเข้าสู่ระบบ',
                    actionLabel: 'เข้าสู่ระบบ',
                    onAction: () => Navigator.of(context).pushNamed('/auth'),
                  )
                else if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'ยังไม่มีอัปเดต',
                    message:
                        'เมื่อมีคำสั่งซื้อ การอนุมัติร้านค้า หรือเลขพัสดุ ระบบจะแสดงที่นี่',
                  )
                else
                  for (final item in filtered)
                    _NotificationTile(
                      item: item,
                      unread: !readIds.contains(item.id),
                      onTap: () {
                        setState(() => readIds.add(item.id));
                        item.onTap?.call(context);
                      },
                    ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_NotificationItem> _buildNotificationItems() {
    final items = <_NotificationItem>[];
    final shop = appStore.sellerProfile;
    if (shop != null) {
      final status = shop.status;
      final title = status == 'active'
          ? 'ร้านค้าของคุณเปิดขายแล้ว'
          : status == 'paused' || status == 'suspended'
              ? 'คำขอเปิดร้านต้องแก้ไข'
              : 'ส่งคำขอเปิดร้านแล้ว';
      final body = status == 'active'
          ? '${shop.shopName} ได้รับอนุมัติแล้ว เพิ่มสินค้าและเริ่มขายได้ทันที'
          : status == 'paused' || status == 'suspended'
              ? (shop.reviewNote.isEmpty
                  ? 'แอดมินขอให้แก้ไขข้อมูลหรือเอกสารร้านค้า'
                  : shop.reviewNote)
              : '${shop.shopName} อยู่ระหว่างรอแอดมินตรวจสอบ';
      items.add(
        _NotificationItem(
          id: 'shop-${shop.id}-${shop.status}',
          category: 'ร้านค้า',
          title: title,
          body: body,
          time: DateTime.now(),
          icon: Icons.storefront,
          color: status == 'active' ? Colors.green : accent,
          onTap: (context) => Navigator.of(context).pushNamed('/seller'),
        ),
      );
    }

    for (final order in appStore.orders) {
      final firstItem = order.items.isEmpty ? null : order.items.first;
      final updated = order.updatedAt ?? order.createdAt;
      items.add(
        _NotificationItem(
          id: 'order-${order.id}-${order.status}',
          category: 'คำสั่งซื้อ',
          title: 'อัปเดตคำสั่งซื้อ ${order.id}',
          body: firstItem == null
              ? order.status
              : '${firstItem.product.name} • ${order.status}',
          time: updated,
          icon: Icons.receipt_long,
          color: accent,
          onTap: (context) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
          ),
        ),
      );
      if (order.trackingNumber.isNotEmpty) {
        items.add(
          _NotificationItem(
            id: 'shipping-${order.id}-${order.trackingNumber}',
            category: 'ขนส่ง',
            title: 'พัสดุเริ่มจัดส่งแล้ว',
            body: '${order.carrier} • ${order.trackingNumber}',
            time: updated,
            icon: Icons.local_shipping,
            color: const Color(0xFF00A889),
            onTap: (context) => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order)),
            ),
          ),
        );
      }
    }

    if (appStore.customerAccount != null) {
      items.add(
        _NotificationItem(
          id: 'system-login-${appStore.customerAccount!.id}',
          category: 'ระบบ',
          title: 'แจ้งเตือนการเข้าสู่ระบบ',
          body:
              'บัญชี ${appStore.customerAccount!.nameOrEmail} กำลังใช้งานบนอุปกรณ์นี้',
          time: DateTime.now(),
          icon: Icons.shield_outlined,
          color: const Color(0xFFD00245),
        ),
      );
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }
}

class _NotificationCategory {
  const _NotificationCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final DateTime time;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context)? onTap;
}

class _NotificationCategoryTab extends StatelessWidget {
  const _NotificationCategoryTab({
    required this.category,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final _NotificationCategory category;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge.count(
              isLabelVisible: count > 0,
              count: count > 99 ? 99 : count,
              backgroundColor: accent,
              child: Icon(
                category.icon,
                color: selected ? accent : muted,
                size: 25,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? accent : muted,
                fontSize: 11.5,
                height: 1.15,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 2,
              width: 52,
              color: selected ? accent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  final _NotificationItem item;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unread ? const Color(0xFFFFF7F8) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: item.color,
                child: Icon(item.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        height: 1.35,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _formatNotificationTime(item.time),
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatNotificationTime(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  final difference = now.difference(local);
  if (difference.inMinutes < 1) return 'เมื่อสักครู่';
  if (difference.inHours < 1) return '${difference.inMinutes} นาทีที่แล้ว';
  if (difference.inDays < 1) return '${difference.inHours} ชั่วโมงที่แล้ว';
  return '${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')}-${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedTab = 'ทั้งหมด';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final orders = appStore.orders;
        final filteredOrders = orders
            .where((order) =>
                selectedTab == 'ทั้งหมด' ||
                sellerOrderTabForStatus(order.status) == selectedTab)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('คำสั่งซื้อของฉัน'),
            backgroundColor: Colors.white,
            foregroundColor: ink,
          ),
          body: orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'ยังไม่มีคำสั่งซื้อ',
                  message: 'คำสั่งซื้อจะแสดงที่นี่หลังชำระเงิน',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  children: [
                    SellerOrderTabs(
                      orders: orders,
                      selectedTab: selectedTab,
                      onChanged: (tab) => setState(() => selectedTab = tab),
                    ),
                    const SizedBox(height: 8),
                    if (filteredOrders.isEmpty)
                      const CustomerEmptyOrderCard()
                    else
                      for (final order in filteredOrders)
                        CustomerOrderCard(order: order),
                  ],
                ),
        );
      },
    );
  }
}

class CustomerEmptyOrderCard extends StatelessWidget {
  const CustomerEmptyOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: muted.withValues(alpha: 0.7), size: 54),
          const SizedBox(height: 10),
          const Text(
            'ยังไม่มีคำสั่งซื้อในสถานะนี้',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'เมื่อร้านค้าอัปเดตสถานะ คำสั่งซื้อจะแสดงตามแท็บนี้อัตโนมัติ',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.first;
    return CheckoutCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined, color: accent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    firstItem.product.shopName,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ProductMiniTag(label: order.status, filled: true),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ProductThumb(url: firstItem.product.imageUrl, size: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${firstItem.color}, ${firstItem.size} x${firstItem.quantity}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: muted),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'รวม ${order.items.length} รายการ',
                    style: const TextStyle(color: muted, fontSize: 12.5),
                  ),
                ),
                Text(
                  formatBaht(order.grandTotal),
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final liveOrder = appStore.orders.firstWhere(
          (item) => item.id == order.id,
          orElse: () => order,
        );
        final reviewed = appStore.isOrderReviewed(liveOrder);
        return Scaffold(
          backgroundColor: const Color(0xFFF6F6F6),
          appBar: AppBar(
            title: const Text('รายละเอียดคำสั่งซื้อ'),
            backgroundColor: Colors.white,
            foregroundColor: ink,
          ),
          body: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              CheckoutCard(
                child: DetailInfoTile(
                  icon: Icons.receipt_long_outlined,
                  title: liveOrder.status,
                  value: liveOrder.id,
                ),
              ),
              CheckoutCard(child: OrderTrackingBlock(order: liveOrder)),
              CheckoutCard(
                child: DetailInfoTile(
                  icon: Icons.location_on,
                  title: 'ที่อยู่จัดส่ง',
                  value: liveOrder.address,
                ),
              ),
              CheckoutCard(
                child: Column(
                  children: [
                    for (final item in liveOrder.items)
                      CheckoutItemRow(item: item),
                  ],
                ),
              ),
              CheckoutCard(
                child: Column(
                  children: [
                    CheckoutLine(
                      label: 'วิธีชำระเงิน',
                      value: liveOrder.paymentMethod,
                    ),
                    CheckoutLine(label: 'ขนส่ง', value: liveOrder.carrier),
                    CheckoutLine(
                      label: 'เลขพัสดุ',
                      value: liveOrder.trackingNumber.isEmpty
                          ? 'ร้านค้ายังไม่ได้ใส่เลขพัสดุ'
                          : liveOrder.trackingNumber,
                    ),
                    CheckoutLine(
                      label: 'ยอดรวม',
                      value: formatBaht(liveOrder.grandTotal),
                      strong: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: liveOrder.status == 'สำเร็จ'
              ? SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.white,
                    child: FilledButton.icon(
                      onPressed: reviewed
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReviewOrderScreen(order: liveOrder),
                                ),
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: line,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      icon: Icon(reviewed ? Icons.check_circle : Icons.star),
                      label: Text(reviewed ? 'ให้คะแนนแล้ว' : 'ให้คะแนนสินค้า'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class ReviewOrderScreen extends StatefulWidget {
  const ReviewOrderScreen({super.key, required this.order});

  final Order order;

  @override
  State<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends State<ReviewOrderScreen> {
  int rating = 5;
  final reviewController = TextEditingController();

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  void _submitReview() {
    appStore.markOrderReviewed(widget.order);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกคะแนนสินค้าแล้ว')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = widget.order.items.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('ให้คะแนนสินค้า'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          CheckoutCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumb(url: firstItem.product.imageUrl, size: 70),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${firstItem.color}, ${firstItem.size}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CheckoutCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'คะแนนสินค้า',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => rating = i),
                        icon: Icon(
                          i <= rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFB300),
                          size: 30,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reviewController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'เล่าประสบการณ์หลังได้รับสินค้า',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: FilledButton(
            onPressed: _submitReview,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
            ),
            child: const Text('ส่งคะแนน'),
          ),
        ),
      ),
    );
  }
}

class OrderTrackingBlock extends StatelessWidget {
  const OrderTrackingBlock({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final currentStep =
        appStore.isOrderReviewed(order) ? 4 : orderStageIndex(order.status);
    final steps = [
      ('รอร้านยืนยัน', currentStep >= 0),
      ('เตรียมจัดส่ง', currentStep >= 1),
      ('ส่งแล้ว', currentStep >= 2),
      ('ได้รับสินค้า', currentStep >= 3),
      ('ให้คะแนน', currentStep >= 4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ติดตามสถานะสินค้า',
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  step.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: step.$2 ? accent : muted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  step.$1,
                  style: TextStyle(
                    color: step.$2 ? ink : muted,
                    fontWeight: step.$2 ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        DetailInfoTile(
          icon: Icons.local_shipping_outlined,
          title: order.carrier,
          value: order.trackingNumber.isEmpty
              ? 'ร้านค้ายังไม่ได้ใส่เลขพัสดุ'
              : 'เลขพัสดุ ${order.trackingNumber}',
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.actionLabel,
      this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: line),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: ink, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CheckoutCard extends StatelessWidget {
  const CheckoutCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Panel(padding: padding, child: child),
    );
  }
}

class CheckoutLine extends StatelessWidget {
  const CheckoutLine(
      {super.key,
      required this.label,
      required this.value,
      this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: strong ? ink : muted,
                      fontWeight: strong ? FontWeight.w900 : FontWeight.w500))),
          Text(value,
              style: TextStyle(
                  color: strong ? accent : ink,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }
}

class VideoBadge extends StatelessWidget {
  const VideoBadge({super.key, required this.views});

  final String views;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(
            views,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DiscountCorner extends StatelessWidget {
  const DiscountCorner({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFE05C),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
      ),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ProductMiniTag extends StatelessWidget {
  const ProductMiniTag({super.key, required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? accent : Colors.white,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class ProductPromoLine extends StatelessWidget {
  const ProductPromoLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFFFC7B8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.discount_outlined, color: accent, size: 11),
          const SizedBox(width: 3),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductPhoto extends StatelessWidget {
  const ProductPhoto({super.key, required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFEDEFF4),
        child: const Icon(Icons.image_not_supported_outlined, color: muted),
      ),
    );
  }
}

class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEDEFF4),
            child: const Icon(Icons.image_not_supported_outlined, color: muted),
          ),
        ),
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.compact = false,
    this.large = false,
    this.inverted = false,
  });

  final IconData icon;
  final bool compact;
  final bool large;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final size = large
        ? 58.0
        : compact
            ? 34.0
            : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: 0.18) : softAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: inverted ? Colors.white : accent,
        size: large ? 28 : 20,
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.clip = false,
    this.backgroundColor = surface,
    this.borderColor = line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  bool _showLoginPrompt = true;

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final seller = appStore.sellerProfile;
    final orderCount = appStore.orders.length;
    final suggested = marketplaceProducts.take(4).toList();
    final isSignedIn = appStore.isAuthenticated;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
        children: [
          MeProfileHeader(seller: seller),
          if (!isSignedIn && _showLoginPrompt) ...[
            const SizedBox(height: 10),
            LoginSecurityCard(
              onClose: () => setState(() => _showLoginPrompt = false),
            ),
          ],
          const SizedBox(height: 10),
          MeOrderPanel(orderCount: orderCount),
          const SizedBox(height: 10),
          const MeShortcutPanel(
            title: 'My Wallet',
            items: [
              MeMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'เก็บเงินปลายทาง',
                  route: '/payment-methods'),
              MeMenuItem(
                  icon: Icons.qr_code_2_outlined,
                  label: 'QR พร้อมเพย์',
                  route: '/payment-methods'),
              MeMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'วิธีชำระเงิน',
                  route: '/payment-methods'),
              MeMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'โค้ดส่วนลด',
                  route: '/me/vouchers'),
            ],
          ),
          const SizedBox(height: 10),
          const MeTwoColumnPanel(
            title: 'กิจกรรมอื่น ๆ',
            action: 'ดูทั้งหมด',
            items: [
              MeMenuItem(
                  icon: Icons.storefront_outlined,
                  label: 'เปิดร้านค้า',
                  route: '/seller'),
              MeMenuItem(
                  icon: Icons.favorite_border,
                  label: 'สิ่งที่ฉันถูกใจ',
                  route: '/me/favorites'),
              MeMenuItem(
                  icon: Icons.card_giftcard_outlined,
                  label: 'โปรแกรม Affiliate',
                  route: '/me/affiliate'),
              MeMenuItem(
                  icon: Icons.phone_android_outlined,
                  label: 'E-Service',
                  route: '/me/e-service'),
              MeMenuItem(
                  icon: Icons.history_outlined,
                  label: 'ดูล่าสุด',
                  route: '/me/recent'),
              MeMenuItem(
                  icon: Icons.play_circle_outline,
                  label: 'Video',
                  route: '/me/campaigns'),
            ],
          ),
          const SizedBox(height: 10),
          const MeHelpPanel(),
          const SizedBox(height: 14),
          const MeRecommendHeader(),
          const SizedBox(height: 8),
          MeRecommendationGrid(products: suggested),
        ],
      ),
    );
  }
}

class MeProfileHeader extends StatelessWidget {
  const MeProfileHeader({super.key, required this.seller});

  final SellerProfile? seller;

  @override
  Widget build(BuildContext context) {
    final account = appStore.customerAccount;
    final isSignedIn = appStore.isAuthenticated;
    final displayName = isSignedIn
        ? (account?.nameOrEmail ?? account?.email ?? '')
        : 'สมัครสมาชิกเพื่อเข้าสู่ระบบ';
    final secondaryText = isSignedIn ? (account?.email ?? '') : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
      decoration: const BoxDecoration(
        color: accent,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isSignedIn
                  ? () => Navigator.of(context).pushNamed('/me/profile')
                  : () => requireCustomerLogin(context),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: account?.avatarUrl.isNotEmpty == true
                        ? Image.network(
                            account!.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: accent,
                              size: 32,
                            ),
                          )
                        : const Icon(Icons.person, color: accent, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/me/settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'ตั้งค่า',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/cart'),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            tooltip: 'ตะกร้า',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/me/chat'),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'แชท',
          ),
        ],
      ),
    );
  }
}

class LoginSecurityCard extends StatelessWidget {
  const LoginSecurityCard({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.login_outlined, color: accent, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สมัครสมาชิกเพื่อเข้าสู่ระบบ',
                  style: TextStyle(
                      color: ink, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'เข้าสู่ระบบเพื่อซื้อสินค้า เปิดร้าน และติดตามคำสั่งซื้อ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/auth'),
            icon: const Icon(Icons.chevron_right, color: muted),
            tooltip: 'เข้าสู่ระบบ',
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: muted),
            tooltip: 'ปิด',
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
        ],
      ),
    );
  }
}

class MeCard extends StatelessWidget {
  const MeCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MeOrderPanel extends StatelessWidget {
  const MeOrderPanel({super.key, required this.orderCount});

  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(
            title: 'คำสั่งซื้อของฉัน',
            action: 'ดูทั้งหมด',
            onTap: () => Navigator.of(context).pushNamed('/orders'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 13, 8, 13),
            child: Row(
              children: [
                Expanded(
                    child: MeOrderStatus(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'รอชำระเงิน',
                        count: 0)),
                Expanded(
                    child: MeOrderStatus(
                        icon: Icons.inventory_2_outlined,
                        label: 'เตรียมจัดส่ง',
                        count: orderCount)),
                const Expanded(
                    child: MeOrderStatus(
                        icon: Icons.local_shipping_outlined,
                        label: 'กำลังจัดส่ง',
                        count: 0)),
                const Expanded(
                    child: MeOrderStatus(
                        icon: Icons.star_border, label: 'ให้คะแนน', count: 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeOrderStatus extends StatelessWidget {
  const MeOrderStatus({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: ink, size: 25),
            if (count > 0)
              Positioned(
                right: -8,
                top: -7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: ink, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class MeSellerPanel extends StatelessWidget {
  const MeSellerPanel({
    super.key,
    required this.seller,
    required this.productCount,
  });

  final SellerProfile? seller;
  final int productCount;

  Future<void> _openSellerTarget(BuildContext context) async {
    if (!await requireCustomerLogin(context)) return;
    if (seller == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OpenShopScreen()),
      );
      return;
    }
    Navigator.of(context).pushNamed('/seller');
  }

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(
            title: seller == null ? 'เริ่มขายบน NP Market' : 'ร้านค้าของฉัน',
            action: seller == null ? 'เปิดร้าน' : 'เข้าศูนย์ผู้ขาย',
            onTap: () => _openSellerTarget(context),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () => _openSellerTarget(context),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        const IconBox(
                            icon: Icons.storefront_outlined, compact: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller?.shopName ??
                                    'เปิดร้าน ลงสินค้า และรับออเดอร์ได้ที่นี่',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                seller == null
                                    ? 'เมนูร้านค้าอยู่ในหน้า ฉัน ตามโครง Shopee'
                                    : 'สินค้าเปิดขาย $productCount รายการ · รองรับขนส่ง 5 บริษัท',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeMenuPanel extends StatelessWidget {
  const MeMenuPanel({super.key, required this.title, required this.items});

  final String title;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(title: title),
          const Divider(height: 1),
          for (var i = 0; i < items.length; i++) ...[
            MeMenuTile(item: items[i]),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class MeShortcutPanel extends StatelessWidget {
  const MeShortcutPanel({super.key, required this.title, required this.items});

  final String title;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeSectionRow(title: title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 13),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(child: MeShortcutTile(item: item)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeTwoColumnPanel extends StatelessWidget {
  const MeTwoColumnPanel({
    super.key,
    required this.title,
    required this.items,
    this.action,
  });

  final String title;
  final String? action;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(title: title, action: action),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, index) =>
                  MeServiceTile(item: items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class MeServiceTile extends StatelessWidget {
  const MeServiceTile({super.key, required this.item});

  final MeMenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.route == null
          ? null
          : () => Navigator.of(context).pushNamed(item.route!),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: accent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    maxLines: 2,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.trailing != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.trailing!,
                      maxLines: 2,
                      style: const TextStyle(color: accent, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class MeShortcutTile extends StatelessWidget {
  const MeShortcutTile({super.key, required this.item});

  final MeMenuItem item;

  void _open(BuildContext context) {
    if (item.route == null) return;
    Navigator.of(context).pushNamed(item.route!);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Icon(item.icon, color: ink, size: 27),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MeSectionRow extends StatelessWidget {
  const MeSectionRow({super.key, required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
            if (action != null)
              Text(
                action!,
                style: const TextStyle(color: muted, fontSize: 12.5),
              ),
            if (action != null)
              const Icon(Icons.chevron_right, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class MeMenuItem {
  const MeMenuItem({
    required this.icon,
    required this.label,
    this.route,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? route;
  final String? trailing;
}

class MeMenuTile extends StatelessWidget {
  const MeMenuTile({super.key, required this.item});

  final MeMenuItem item;

  void _open(BuildContext context) {
    if (item.route == null) return;
    Navigator.of(context).pushNamed(item.route!);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Icon(item.icon, color: accent, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (item.trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        item.trailing!,
                        style: const TextStyle(color: muted, fontSize: 12.5),
                      ),
                    ),
                  const Icon(Icons.chevron_right, color: muted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MeHelpPanel extends StatelessWidget {
  const MeHelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const MeMenuPanel(
      title: 'ช่วยเหลือ',
      items: [
        MeMenuItem(
            icon: Icons.help_outline,
            label: 'ศูนย์ช่วยเหลือ',
            route: '/me/help'),
        MeMenuItem(
            icon: Icons.support_agent, label: 'Chat กับเรา', route: '/me/chat'),
      ],
    );
  }
}

class MeRecommendHeader extends StatelessWidget {
  const MeRecommendHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'คุณอาจจะชอบสิ่งนี้',
            style: TextStyle(color: ink, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Divider(color: line)),
      ],
    );
  }
}

class MeRecommendationGrid extends StatelessWidget {
  const MeRecommendationGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.53,
      ),
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}

class MeSubPage extends StatelessWidget {
  const MeSubPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                IconBox(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const CheckoutCard(
            margin: EdgeInsets.zero,
            child: Text(
              'หน้านี้เป็นโครงสำหรับเชื่อมข้อมูลจริงในขั้นต่อไป',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const methods = [
      (Icons.payments_outlined, 'เก็บเงินปลายทาง', 'ชำระเงินเมื่อได้รับสินค้า'),
      (Icons.qr_code_2_outlined, 'QR พร้อมเพย์', 'โอนผ่าน QR จากแอปธนาคาร'),
      (
        Icons.account_balance_outlined,
        'Mobile Banking',
        'โอนผ่านธนาคารที่รองรับ'
      ),
      (
        Icons.credit_card_outlined,
        'บัตรเครดิต/เดบิต',
        'รองรับบัตรที่เปิดใช้งานออนไลน์'
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ช่องทางการชำระเงิน'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          CheckoutCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < methods.length; i++) ...[
                  ListTile(
                    leading: Icon(methods[i].$1, color: accent),
                    title: Text(
                      methods[i].$2,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(methods[i].$3),
                    trailing: const Icon(Icons.chevron_right, color: muted),
                  ),
                  if (i != methods.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ตั้งค่าบัญชี'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/me/chat'),
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'แชท',
          ),
        ],
      ),
      body: ListView(
        children: const [
          SettingsGroup(
            title: 'บัญชีของฉัน',
            items: [
              SettingsItem('บัญชี & ความปลอดภัยของบัญชี'),
              SettingsItem('ที่อยู่ของฉัน', route: '/me/addresses'),
              SettingsItem('ข้อมูลบัญชีธนาคาร/บัตร'),
            ],
          ),
          SettingsGroup(
            title: 'การตั้งค่า',
            items: [
              SettingsItem('ตั้งค่าการแชท'),
              SettingsItem('ตั้งค่าคำสั่งซื้อ'),
              SettingsItem('ตั้งค่าการแจ้งเตือน'),
              SettingsItem('การตั้งค่าความเป็นส่วนตัว'),
              SettingsItem('ผู้ใช้ที่ถูกระงับ'),
              SettingsItem('ภาษา / Language', subtitle: 'ไทย'),
            ],
          ),
          SettingsGroup(
            title: 'ช่วยเหลือ',
            items: [
              SettingsItem('ศูนย์ช่วยเหลือ', route: '/me/help'),
              SettingsItem('กฎและข้อบังคับ'),
              SettingsItem('นโยบายของ NP Market'),
              SettingsItem('ชอบใช้แอป NP Market? ให้คะแนนเราเลย!'),
              SettingsItem('เกี่ยวกับ'),
              SettingsItem('คำร้องขอลบบัญชีผู้ใช้'),
            ],
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton(
              onPressed: null,
              child: Text('เปลี่ยนบัญชีผู้ใช้ / ออกจากระบบ'),
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'NP Market v1.0.0',
              style: TextStyle(color: muted, fontSize: 12.5),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  Uint8List? avatarPreview;
  bool isUploadingAvatar = false;

  Future<void> _pickAvatar() async {
    if (isUploadingAvatar) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถอ่านไฟล์รูปนี้ได้')),
      );
      return;
    }

    setState(() {
      avatarPreview = Uint8List.fromList(bytes);
      isUploadingAvatar = true;
    });
    try {
      await appStore.updateCustomerAvatar(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตรูปโปรไฟล์แล้ว')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => avatarPreview = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = appStore.customerAccount;
    final name = account?.displayName.isNotEmpty == true
        ? account!.displayName
        : account?.email.split('@').first ?? '-';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickAvatar,
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFEEF0),
                          border: Border.all(color: line),
                        ),
                        child: avatarPreview != null
                            ? Image.memory(avatarPreview!, fit: BoxFit.cover)
                            : account?.avatarUrl.isNotEmpty == true
                                ? Image.network(
                                    account!.avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: accent,
                                      size: 42,
                                    ),
                                  )
                                : const Icon(Icons.person,
                                    color: accent, size: 42),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add,
                                  color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickAvatar,
                  borderRadius: BorderRadius.circular(8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: muted, size: 18),
                      SizedBox(width: 4),
                      Text('แก้ไข', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ProfileInfoGroup(
            items: [
              ProfileInfoItem(label: 'ชื่อ', value: name),
              ProfileInfoItem(label: 'ประวัติ', value: 'ตั้งค่า'),
            ],
          ),
          const SizedBox(height: 10),
          const ProfileInfoGroup(
            items: [
              ProfileInfoItem(
                  label: 'เพศ', value: 'ตั้งค่า', accentValue: true),
              ProfileInfoItem(
                  label: 'วันเกิด', value: 'ตั้งค่า', accentValue: true),
            ],
          ),
          const SizedBox(height: 10),
          ProfileInfoGroup(
            items: [
              ProfileInfoItem(
                label: 'โทรศัพท์',
                value: maskPhone(account?.phone ?? ''),
              ),
              ProfileInfoItem(
                label: 'อีเมล',
                value: maskEmail(account?.email ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileInfoGroup extends StatelessWidget {
  const ProfileInfoGroup({super.key, required this.items});

  final List<ProfileInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Divider(height: 1, indent: 14, color: line),
          ],
        ],
      ),
    );
  }
}

class ProfileInfoItem extends StatelessWidget {
  const ProfileInfoItem({
    super.key,
    required this.label,
    required this.value,
    this.accentValue = false,
  });

  final String label;
  final String value;
  final bool accentValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: ink, fontSize: 14.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentValue ? accent : muted,
                fontSize: 14,
                fontWeight: accentValue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    );
  }
}

String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return phone;
  return '${'*' * (digits.length - 2)}${digits.substring(digits.length - 2)}';
}

String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts.first.isEmpty) return email;
  final name = parts.first;
  final visible = name.length <= 1 ? name : name.substring(0, 1);
  return '$visible${'*' * 7}@${parts.last}';
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.items});

  final String title;
  final List<SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child:
              Text(title, style: const TextStyle(color: muted, fontSize: 12.5)),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                SettingsTile(item: items[i]),
                if (i != items.length - 1)
                  const Divider(height: 1, indent: 14, color: line),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsItem {
  const SettingsItem(this.title, {this.subtitle, this.route});

  final String title;
  final String? subtitle;
  final String? route;
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.item});

  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.route == null
          ? null
          : () => Navigator.of(context).pushNamed(item.route!),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(color: ink, fontSize: 14.5),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: accent),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                    color: ink, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickMenuItem {
  const QuickMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

String formatBaht(double amount) {
  final fixed = amount.toStringAsFixed(0);
  final chars = fixed.split('').reversed.toList();
  final groups = <String>[];
  for (var i = 0; i < chars.length; i += 3) {
    groups.add(chars.skip(i).take(3).toList().reversed.join());
  }
  return '฿${groups.reversed.join(',')}';
}

String formatDate(DateTime value) {
  return '${value.day}/${value.month}/${value.year + 543}';
}

int orderStageIndex(String status) {
  if (status == 'ให้คะแนนแล้ว') return 4;
  if (status.contains('สำเร็จ') || status.contains('ได้รับ')) return 3;
  if (status.contains('ส่งแล้ว') || status.contains('กำลังจัดส่ง')) return 2;
  if (status.contains('รอจัดส่ง') || status.contains('เตรียมจัดส่ง')) return 1;
  return 0;
}

String sellerOrderTabForStatus(String status) {
  if (status.contains('ยกเลิก')) return 'ยกเลิก';
  if (status.contains('คืนสินค้า') || status.contains('คืนเงิน'))
    return 'คืนสินค้า';
  if (status.contains('สำเร็จ') || status.contains('ได้รับ')) return 'สำเร็จ';
  if (status.contains('ส่งแล้ว') || status.contains('กำลังจัดส่ง')) {
    return 'กำลังจัดส่ง';
  }
  if (status.contains('รอจัดส่ง') || status.contains('เตรียมจัดส่ง')) {
    return 'รอจัดส่ง';
  }
  return 'รอยืนยัน';
}

String compactCount(int count) {
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return count.toString();
}

const searchSuggestions = [
  'เก้าอี้แคมป์',
  'กระเป๋าสะพาย',
  'หูฟังไร้สาย',
  'เสื้อยืดคอตตอน',
  'แก้วเก็บอุณหภูมิ',
];

const quickMenus = [
  QuickMenuItem(icon: Icons.category_outlined, label: 'หมวดหมู่'),
  QuickMenuItem(icon: Icons.local_fire_department_outlined, label: 'ดีลวันนี้'),
  QuickMenuItem(icon: Icons.confirmation_number_outlined, label: 'คูปอง'),
  QuickMenuItem(icon: Icons.local_shipping_outlined, label: 'ส่งฟรี'),
  QuickMenuItem(icon: Icons.storefront_outlined, label: 'ร้านค้า'),
  QuickMenuItem(icon: Icons.play_circle_outline, label: 'วิดีโอ'),
  QuickMenuItem(icon: Icons.receipt_long_outlined, label: 'ออเดอร์'),
  QuickMenuItem(icon: Icons.support_agent, label: 'ช่วยเหลือ'),
];

const campaigns = [
  Campaign(
    title: 'ลดแรงทั้งร้าน',
    subtitle: 'รวมสินค้าราคาดีจากร้านค้าแนะนำ',
    label: 'NP DEAL',
  ),
  Campaign(
    title: 'เปิดร้านฟรี',
    subtitle: 'สมัครร้านค้า ลงสินค้า และเริ่มขายได้ทันที',
    label: 'SELLER',
  ),
  Campaign(
    title: 'ส่งฟรีวันนี้',
    subtitle: 'คัดดีลพร้อมจัดส่งสำหรับลูกค้าใหม่',
    label: 'SHIPPING',
  ),
];

const recommendedShops = <Shop>[];
