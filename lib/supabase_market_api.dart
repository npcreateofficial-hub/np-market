import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseEnabled =>
    supabaseUrl.isNotEmpty &&
    supabaseAnonKey.isNotEmpty &&
    !supabaseAnonKey.contains('replace-with');

class SupabaseMarketApi {
  const SupabaseMarketApi();

  Map<String, String> get _headers => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      };

  Future<CustomerSession> signInCustomer({
    required String email,
    required String password,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Login failed: ${_authError(response.body)}');
    }
    return _sessionFromAuthResponse(response.body);
  }

  Future<CustomerSession> registerCustomer({
    required String displayName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/signup'),
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'data': {
          'display_name': displayName.trim(),
          'phone': phone.trim(),
          'account_type': 'buyer',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Register failed: ${_authError(response.body)}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['access_token'] == null) {
      throw StateError(
        'Registration succeeded but email confirmation is required. Confirm the user in Supabase Auth, then sign in.',
      );
    }

    final session = _sessionFromAuthResponse(response.body);
    await upsertCustomerProfile(
      session: session,
      email: email,
      displayName: displayName,
      phone: phone,
    );
    return session;
  }

  Future<CustomerAccount> fetchCustomerProfile({
    required CustomerSession session,
    required String email,
  }) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/profiles'
      '?select=id,display_name,phone,role'
      '&id=eq.${Uri.encodeComponent(session.userId)}'
      '&limit=1',
    );

    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Fetch profile failed: ${response.statusCode} ${response.body}',
      );
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    final hasProfile = rows.isNotEmpty;
    final row =
        hasProfile ? (rows.first as Map<String, dynamic>) : <String, dynamic>{};
    return CustomerAccount(
      id: session.userId,
      email: email,
      displayName: row['display_name']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      role: row['role']?.toString() ?? 'buyer',
      hasProfile: hasProfile,
    );
  }

  Future<void> upsertCustomerProfile({
    required CustomerSession session,
    required String email,
    required String displayName,
    required String phone,
  }) async {
    await _upsertRows(
      session,
      'profiles',
      [
        {
          'id': session.userId,
          'display_name':
              displayName.trim().isEmpty ? email.trim() : displayName.trim(),
          'phone': phone.trim(),
          'role': 'buyer',
        }
      ],
      onConflict: 'id',
    );
  }

  Future<List<Product>> fetchProducts() async {
    if (!isSupabaseEnabled) return const [];

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/products'
      '?select=id,shop_id,name,price,original_price,stock,rating,sold_count,badge,status,shops(name,pickup_province,category),product_media(url,sort_order),product_variants(color,size,is_active,stock)'
      '&status=eq.active'
      '&order=created_at.desc',
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Supabase products failed: ${response.statusCode}');
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => _productFromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Order>> fetchOrders({required String accessToken}) async {
    if (!isSupabaseEnabled || accessToken.isEmpty) return const [];

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/orders'
      '?select=id,order_no,status,payment_method,shipping_address,grand_total,created_at,order_items(quantity,unit_price,total_price,product_snapshot)'
      '&order=created_at.desc',
    );

    final response = await http.get(uri, headers: {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $accessToken',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Supabase orders failed: ${response.statusCode}');
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => _orderFromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Order>> createCheckoutOrders({
    required List<CartItem> items,
    required Address address,
    required String paymentMethod,
    required CustomerSession session,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }

    final addressId = await _insertCheckoutAddress(session, address);

    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      if (item.product.shopId.isEmpty) {
        throw StateError('Product ${item.product.name} is missing shop_id.');
      }
      grouped.putIfAbsent(item.product.shopId, () => []).add(item);
    }

    final createdOrders = <Order>[];
    var groupIndex = 0;
    for (final entry in grouped.entries) {
      groupIndex += 1;
      final shopItems = entry.value;
      final subtotal = shopItems.fold<double>(
        0,
        (total, item) => total + item.total,
      );
      const shippingFee = 0.0;
      const discount = 0.0;
      final grandTotal = subtotal + shippingFee - discount;
      final orderNo = _orderNo(groupIndex);
      final paymentCode = _paymentMethodCode(paymentMethod);

      final orderRow = await _insertReturningSingle(
        session,
        'orders',
        {
          'order_no': orderNo,
          'buyer_id': session.userId,
          'shop_id': entry.key,
          'address_id': addressId,
          'shipping_address': {
            'recipient': address.name,
            'phone': address.phone,
            'address': address.fullAddress,
          },
          'status': 'seller_confirming',
          'payment_method': paymentCode,
          'subtotal': subtotal,
          'shipping_fee': shippingFee,
          'discount': discount,
          'grand_total': grandTotal,
          'note': 'Created from NP Market mobile app',
        },
      );
      final orderId = orderRow['id']?.toString() ?? '';

      await _insertRows(
        session,
        'order_items',
        shopItems
            .map(
              (item) => {
                'order_id': orderId,
                'product_id': item.product.id,
                'product_snapshot': {
                  'id': item.product.id,
                  'name': item.product.name,
                  'shopId': item.product.shopId,
                  'shopName': item.product.shopName,
                  'category': item.product.category,
                  'imageUrl': item.product.imageUrl,
                },
                'quantity': item.quantity,
                'unit_price': item.product.price,
                'total_price': item.total,
              },
            )
            .toList(),
      );

      await _insertRows(
        session,
        'order_shipments',
        [
          {
            'order_id': orderId,
            'carrier_name': 'ยังไม่ได้เลือกขนส่ง',
            'tracking_number': '',
          }
        ],
      );

      await _insertRows(
        session,
        'payments',
        [
          {
            'order_id': orderId,
            'method': paymentCode,
            'status': paymentCode == 'cod' ? 'pending' : 'paid',
            'amount': grandTotal,
            'provider': paymentCode == 'cod' ? 'cash_on_delivery' : 'manual',
            'provider_ref': orderNo,
            'paid_at': paymentCode == 'cod'
                ? null
                : DateTime.now().toUtc().toIso8601String(),
          }
        ],
      );

      createdOrders.add(
        Order(
          id: orderNo,
          items: List.unmodifiable(shopItems),
          address: address.fullAddress,
          paymentMethod: paymentMethod,
          status: _orderStatusLabel('seller_confirming'),
          createdAt:
              DateTime.tryParse(orderRow['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          carrier: 'ยังไม่ได้เลือกขนส่ง',
          trackingNumber: '',
        ),
      );
    }

    return createdOrders;
  }

  Product _productFromJson(Map<String, dynamic> row) {
    final shop = _firstRelation(row['shops']);
    final media = (row['product_media'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
    final variants = (row['product_variants'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((variant) => variant['is_active'] == true)
        .toList();

    final price = _num(row['price']);
    final originalPrice = _num(row['original_price']);
    final stock = (row['stock'] as num?)?.toInt() ?? 0;
    final colors = _uniqueStrings(variants.map((variant) => variant['color']));
    final sizes = _uniqueStrings(variants.map((variant) => variant['size']));

    return Product(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      shopId: row['shop_id']?.toString() ?? '',
      shopName: shop?['name']?.toString() ?? 'NP Market',
      category: shop?['category']?.toString() ?? '',
      price: price,
      originalPrice: originalPrice > 0 ? originalPrice : price,
      rating: _num(row['rating']),
      soldCount: (row['sold_count'] as num?)?.toInt() ?? 0,
      imageUrl: media.isNotEmpty
          ? media.first['url']?.toString() ?? ''
          : 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
      badge: row['badge']?.toString() ?? '',
      location: shop?['pickup_province']?.toString() ?? '',
      shippingLabel: 'จัดส่งโดยร้านค้า',
      serviceLabel: 'NP Market',
      promoLabel: '',
      discountPercent: _discountPercent(price, originalPrice),
      isVideo: false,
      videoViews: '',
      stock: stock,
      colorOptions: colors,
      sizeOptions: sizes,
    );
  }

  Order _orderFromJson(Map<String, dynamic> row) {
    final items = (row['order_items'] as List<dynamic>? ?? const [])
        .map((item) => _cartItemFromOrderItem(item as Map<String, dynamic>))
        .toList();
    final shippingAddress = row['shipping_address'] is Map
        ? row['shipping_address'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Order(
      id: row['order_no']?.toString() ?? row['id']?.toString() ?? '',
      items: items,
      address: shippingAddress.values.join(' '),
      paymentMethod: row['payment_method']?.toString() ?? '',
      status: _orderStatusLabel(row['status']?.toString() ?? ''),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  CartItem _cartItemFromOrderItem(Map<String, dynamic> row) {
    final snapshot = row['product_snapshot'] is Map
        ? row['product_snapshot'] as Map<String, dynamic>
        : <String, dynamic>{};
    final price = _num(row['unit_price']);
    final product = Product(
      id: snapshot['id']?.toString() ?? '',
      name: snapshot['name']?.toString() ?? 'สินค้า',
      shopId: snapshot['shopId']?.toString() ?? '',
      shopName: snapshot['shopName']?.toString() ?? 'NP Market',
      category: snapshot['category']?.toString() ?? '',
      price: price,
      originalPrice: price,
      rating: 0,
      soldCount: 0,
      imageUrl: snapshot['imageUrl']?.toString() ?? '',
      badge: '',
      location: '',
      shippingLabel: '',
      serviceLabel: '',
      promoLabel: '',
      discountPercent: 0,
      isVideo: false,
      videoViews: '',
      stock: 1,
    );
    return CartItem(
      product: product,
      color: '',
      size: '',
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  CustomerSession _sessionFromAuthResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return CustomerSession(
      accessToken: json['access_token']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
    );
  }

  Future<String> _insertCheckoutAddress(
    CustomerSession session,
    Address address,
  ) async {
    final addressId = _newUuid();
    await _insertRows(
      session,
      'addresses',
      [
        {
          'id': addressId,
          'user_id': session.userId,
          'recipient_name': address.name,
          'phone': address.phone,
          'detail': address.detail,
          'province': address.province,
          'district': address.district,
          'sub_district': address.subDistrict,
          'postcode': address.postcode,
          'label': address.label,
          'is_default': address.isDefault,
        }
      ],
    );
    return addressId;
  }

  Future<Map<String, dynamic>> _insertReturningSingle(
    CustomerSession session,
    String table,
    Map<String, dynamic> row,
  ) async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table?select=*'),
      headers: _authHeaders(session, prefer: 'return=representation'),
      body: jsonEncode(row),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Insert $table failed: ${response.statusCode} ${response.body}',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.first as Map<String, dynamic>;
  }

  Future<void> _insertRows(
    CustomerSession session,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table'),
      headers: _authHeaders(session),
      body: jsonEncode(rows),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Insert $table failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> _upsertRows(
    CustomerSession session,
    String table,
    List<Map<String, dynamic>> rows, {
    required String onConflict,
  }) async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table?on_conflict=$onConflict'),
      headers: _authHeaders(session, prefer: 'resolution=merge-duplicates'),
      body: jsonEncode(rows),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Upsert $table failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Map<String, String> _authHeaders(
    CustomerSession session, {
    String? prefer,
  }) {
    return {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
      if (prefer != null) 'Prefer': prefer,
    };
  }
}

class CustomerSession {
  const CustomerSession({
    required this.accessToken,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final String userId;
  final String email;
}

Map<String, dynamic>? _firstRelation(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value.first as Map<String, dynamic>;
  }
  if (value is Map<String, dynamic>) return value;
  return null;
}

String _authError(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['msg']?.toString() ??
        json['message']?.toString() ??
        json['error_description']?.toString() ??
        body;
  } catch (_) {
    return body;
  }
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _uniqueStrings(Iterable<dynamic> values) {
  final result = <String>[];
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && !result.contains(text)) result.add(text);
  }
  return result;
}

int _discountPercent(double price, double originalPrice) {
  if (originalPrice <= 0 || price <= 0 || price >= originalPrice) return 0;
  return (((originalPrice - price) / originalPrice) * 100).round();
}

String _orderStatusLabel(String status) {
  return switch (status) {
    'pending_payment' => 'รอชำระเงิน',
    'seller_confirming' => 'รอร้านยืนยัน',
    'awaiting_shipment' => 'รอจัดส่ง',
    'packed' => 'เตรียมจัดส่ง',
    'shipped' => 'ส่งแล้ว',
    'in_transit' => 'กำลังจัดส่ง',
    'delivered' => 'ได้รับสินค้าแล้ว',
    'completed' => 'สำเร็จ',
    'cancelled' => 'ยกเลิก',
    'return_refund' => 'คืนสินค้า/คืนเงิน',
    _ => status,
  };
}

String _paymentMethodCode(String paymentMethod) {
  if (paymentMethod.contains('QR')) return 'promptpay_qr';
  if (paymentMethod.contains('Mobile')) return 'mobile_banking';
  if (paymentMethod.contains('บัตร')) return 'card';
  return 'cod';
}

String _orderNo(int index) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return index == 1 ? 'NP$timestamp' : 'NP$timestamp-$index';
}

String _newUuid() {
  final random = Random.secure();
  int next(int max) => random.nextInt(max);
  String hex(int value, int width) =>
      value.toRadixString(16).padLeft(width, '0');
  return '${hex(next(0x100000000), 8)}-'
      '${hex(next(0x10000), 4)}-'
      '4${hex(next(0x1000), 3)}-'
      '${hex(0x8000 | next(0x4000), 4)}-'
      '${hex(next(0x1000000), 6)}${hex(next(0x1000000), 6)}';
}
