import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const supabaseEmailRedirectTo =
    String.fromEnvironment('SUPABASE_EMAIL_REDIRECT_TO');

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

    final signupBody = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'data': {
        'display_name': displayName.trim(),
        'phone': phone.trim(),
        'account_type': 'buyer',
      },
    };
    if (supabaseEmailRedirectTo.isNotEmpty) {
      signupBody['email_redirect_to'] = supabaseEmailRedirectTo;
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/signup'),
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(signupBody),
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
      '?select=id,display_name,phone,avatar_url,role'
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
      avatarUrl: row['avatar_url']?.toString() ?? '',
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
          'email': email.trim(),
          'display_name':
              displayName.trim().isEmpty ? email.trim() : displayName.trim(),
          'phone': phone.trim(),
          'role': 'buyer',
        }
      ],
      onConflict: 'id',
    );
  }

  Future<CustomerAccount> updateCustomerAvatar({
    required CustomerSession session,
    required String email,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final objectPath =
        'profiles/${session.userId}/avatar-${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final upload = await http.put(
      Uri.parse(
        '$supabaseUrl/storage/v1/object/product-media/${Uri.encodeFull(objectPath)}',
      ),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/octet-stream',
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (upload.statusCode < 200 || upload.statusCode >= 300) {
      throw StateError(
        'Upload profile image failed: ${upload.statusCode} ${upload.body}',
      );
    }

    final avatarUrl =
        '$supabaseUrl/storage/v1/object/public/product-media/${Uri.encodeFull(objectPath)}';
    final response = await http.patch(
      Uri.parse(
        '$supabaseUrl/rest/v1/profiles?id=eq.${Uri.encodeComponent(session.userId)}&select=id,display_name,phone,avatar_url,role',
      ),
      headers: _authHeaders(session, prefer: 'return=representation'),
      body: jsonEncode({'avatar_url': avatarUrl}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Update profile image failed: ${response.statusCode} ${response.body}',
      );
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    final row = rows.isNotEmpty
        ? rows.first as Map<String, dynamic>
        : <String, dynamic>{};
    return CustomerAccount(
      id: session.userId,
      email: email,
      displayName: row['display_name']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString() ?? avatarUrl,
      role: row['role']?.toString() ?? 'buyer',
    );
  }

  Future<List<Product>> fetchProducts() async {
    if (!isSupabaseEnabled) return const [];

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/products'
      '?select=id,shop_id,category_id,name,price,original_price,stock,rating,sold_count,badge,status,shops!inner(name,pickup_province,category,status),categories(name),product_media(type,url,sort_order),product_variants(color,size,is_active,stock)'
      '&status=eq.active'
      '&shops.status=eq.active'
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
      '?select=id,order_no,status,payment_method,shipping_address,grand_total,created_at,order_shipments(carrier_name,tracking_number),order_items(quantity,unit_price,total_price,product_snapshot)'
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

  Future<SellerProfile?> fetchMyShop({required CustomerSession session}) async {
    if (!isSupabaseEnabled) return null;

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/shops'
      '?select=id,name,category,description,logo_url,phone,pickup_address,pickup_province,pickup_district,pickup_sub_district,pickup_postcode,bank_account_name,bank_account_number,bank_name,status,review_note,profiles(display_name,email,phone),shop_documents(type,file_url,file_path,created_at,updated_at),shop_carriers(carriers(name))'
      '&owner_id=eq.${Uri.encodeComponent(session.userId)}'
      '&order=created_at.desc'
      '&limit=1',
    );

    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Fetch seller shop failed: ${response.statusCode} ${response.body}',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;
    final profile = _sellerProfileFromJson(rows.first as Map<String, dynamic>);
    return profile.copyWith(
      logoUrl: await _signedShopFileUrl(session, profile.logoUrl),
      identityCardUrl:
          await _signedShopFileUrl(session, profile.identityCardUrl),
      bankBookUrl: await _signedShopFileUrl(session, profile.bankBookUrl),
    );
  }

  Future<SellerProfile> createOrUpdateShop({
    required CustomerSession session,
    required SellerProfile profile,
    String identityCardUrl = '',
    String bankBookUrl = '',
    String identityCardPath = '',
    String bankBookPath = '',
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }

    await _upsertRows(
      session,
      'profiles',
      [
        {
          'id': session.userId,
          'email': session.email,
          'display_name': profile.ownerName.trim().isEmpty
              ? session.email
              : profile.ownerName.trim(),
          'phone': profile.phone.trim(),
          'role': 'seller',
        }
      ],
      onConflict: 'id',
    );

    final nextStatus = profile.id.isEmpty
        ? 'pending_review'
        : (profile.isVerified ? 'active' : 'pending_review');
    final row = {
      if (profile.id.isNotEmpty) 'id': profile.id,
      'owner_id': session.userId,
      'name': profile.shopName.trim(),
      'category': profile.category.trim(),
      'description': profile.description.trim(),
      'logo_url': profile.logoUrl.trim(),
      'phone': profile.phone.trim(),
      'pickup_address': profile.address.trim(),
      'pickup_province': profile.pickupProvince.trim(),
      'pickup_district': profile.pickupDistrict.trim(),
      'pickup_sub_district': profile.pickupSubDistrict.trim(),
      'pickup_postcode': profile.pickupPostcode.trim(),
      'bank_account_name': profile.bankAccountName.trim(),
      'bank_account_number': profile.bankAccountNumber.trim(),
      'bank_name': profile.bankName.trim(),
      'status': nextStatus,
      if (nextStatus == 'pending_review') 'review_note': '',
      if (nextStatus == 'pending_review') 'approved_at': null,
      if (nextStatus == 'pending_review') 'approved_by': null,
    };
    final saved = await _insertReturningSingle(
      session,
      'shops',
      row,
      prefer: profile.id.isNotEmpty
          ? 'return=representation,resolution=merge-duplicates'
          : 'return=representation',
      query: profile.id.isNotEmpty ? '?on_conflict=id&select=*' : '?select=*',
    );

    await _replaceShopCarriers(
      session,
      saved['id']?.toString() ?? profile.id,
      profile.enabledCarriers,
    );
    await _createRequiredShopDocuments(
      session,
      saved['id']?.toString() ?? profile.id,
      identityCardUrl: identityCardUrl,
      bankBookUrl: bankBookUrl,
      identityCardPath: identityCardPath,
      bankBookPath: bankBookPath,
    );

    return profile.copyWith(
      id: saved['id']?.toString() ?? profile.id,
      isVerified: saved['status']?.toString() == 'active',
      status: saved['status']?.toString() ?? 'pending_review',
      reviewNote: saved['review_note']?.toString() ?? '',
    );
  }

  Future<List<Product>> fetchSellerProducts({
    required CustomerSession session,
  }) async {
    final shop = await fetchMyShop(session: session);
    if (shop == null || shop.id.isEmpty) return const [];
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/products'
      '?select=id,shop_id,category_id,name,price,original_price,stock,rating,sold_count,badge,status,shops(name,pickup_province,category),categories(name),product_media(type,url,sort_order),product_variants(color,size,is_active,stock)'
      '&shop_id=eq.${Uri.encodeComponent(shop.id)}'
      '&order=created_at.desc',
    );
    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Fetch seller products failed: ${response.statusCode} ${response.body}',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => _productFromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createSellerProduct({
    required CustomerSession session,
    required SellerProfile shop,
    required Product product,
    required String description,
    required String sku,
    required double weightKg,
    required String parcelSize,
  }) async {
    if (shop.id.isEmpty) {
      throw StateError('Create a seller shop before adding products.');
    }
    if (!shop.isVerified) {
      throw StateError('Your shop must be approved before adding products.');
    }

    final categoryId = await _categoryIdByName(session, product.category);
    final productRow = await _insertReturningSingle(
      session,
      'products',
      {
        'shop_id': shop.id,
        if (categoryId.isNotEmpty) 'category_id': categoryId,
        'name': product.name,
        'description': description,
        'sku': sku,
        'price': product.price,
        'original_price': product.originalPrice,
        'stock': product.stock,
        'weight_kg': weightKg,
        'parcel_size': parcelSize,
        'ship_from_province': product.location,
        'badge': product.badge,
        'status': product.stock <= 0 ? 'sold_out' : 'active',
      },
    );
    final productId = productRow['id']?.toString() ?? '';

    final mediaRows = <Map<String, dynamic>>[];
    if (product.imageUrl.trim().isNotEmpty) {
      mediaRows.add(
        {
          'product_id': productId,
          'type': 'image',
          'url': product.imageUrl.trim(),
          'sort_order': 0,
        },
      );
    }
    if (product.videoUrl.trim().isNotEmpty) {
      mediaRows.add(
        {
          'product_id': productId,
          'type': 'video',
          'url': product.videoUrl.trim(),
          'sort_order': 1,
        },
      );
    }
    await _insertRows(session, 'product_media', mediaRows);

    final variants = <Map<String, dynamic>>[];
    final colors = product.colorOptions.isEmpty ? [''] : product.colorOptions;
    final sizes = product.sizeOptions.isEmpty ? [''] : product.sizeOptions;
    for (final color in colors) {
      for (final size in sizes) {
        variants.add({
          'product_id': productId,
          'color': color,
          'size': size,
          'sku': [sku, color, size].where((part) => part.isNotEmpty).join('-'),
          'price': product.price,
          'stock': product.stock,
          'is_active': true,
        });
      }
    }
    await _insertRows(session, 'product_variants', variants);

    return product.copyWithId(productId, shop.id);
  }

  Future<void> deleteSellerProduct({
    required CustomerSession session,
    required String productId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$supabaseUrl/rest/v1/products?id=eq.${Uri.encodeComponent(productId)}',
      ),
      headers: _authHeaders(session),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Delete product failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<Product> updateSellerProduct({
    required CustomerSession session,
    required SellerProfile shop,
    required Product product,
    required String description,
    required String sku,
    required double weightKg,
    required String parcelSize,
  }) async {
    if (shop.id.isEmpty || product.id.isEmpty) {
      throw StateError('Product and shop are required before updating.');
    }
    if (!shop.isVerified) {
      throw StateError('Your shop must be approved before updating products.');
    }
    final categoryId = await _categoryIdByName(session, product.category);
    final response = await http.patch(
      Uri.parse(
        '$supabaseUrl/rest/v1/products?id=eq.${Uri.encodeComponent(product.id)}&shop_id=eq.${Uri.encodeComponent(shop.id)}&select=*',
      ),
      headers: _authHeaders(session, prefer: 'return=representation'),
      body: jsonEncode({
        if (categoryId.isNotEmpty) 'category_id': categoryId,
        'name': product.name,
        'description': description,
        'sku': sku,
        'price': product.price,
        'original_price': product.originalPrice,
        'stock': product.stock,
        'weight_kg': weightKg,
        'parcel_size': parcelSize,
        'ship_from_province': product.location,
        'badge': product.badge,
        'status': product.stock <= 0 ? 'sold_out' : 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Update product failed: ${response.statusCode} ${response.body}',
      );
    }

    await http.delete(
      Uri.parse(
        '$supabaseUrl/rest/v1/product_media?product_id=eq.${Uri.encodeComponent(product.id)}',
      ),
      headers: _authHeaders(session),
    );
    final mediaRows = <Map<String, dynamic>>[];
    if (product.imageUrl.trim().isNotEmpty) {
      mediaRows.add({
        'product_id': product.id,
        'type': 'image',
        'url': product.imageUrl.trim(),
        'sort_order': 0,
      });
    }
    if (product.videoUrl.trim().isNotEmpty) {
      mediaRows.add({
        'product_id': product.id,
        'type': 'video',
        'url': product.videoUrl.trim(),
        'sort_order': 1,
      });
    }
    await _insertRows(session, 'product_media', mediaRows);
    return product.copyWithId(product.id, shop.id);
  }

  Future<List<Order>> fetchSellerOrders({
    required CustomerSession session,
  }) async {
    final shop = await fetchMyShop(session: session);
    if (shop == null || shop.id.isEmpty) return const [];
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/orders'
      '?select=id,order_no,status,payment_method,shipping_address,grand_total,created_at,order_shipments(carrier_name,tracking_number),order_items(quantity,unit_price,total_price,product_snapshot)'
      '&shop_id=eq.${Uri.encodeComponent(shop.id)}'
      '&order=created_at.desc',
    );
    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Fetch seller orders failed: ${response.statusCode} ${response.body}',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => _orderFromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Order?> updateSellerOrderShipment({
    required CustomerSession session,
    required String orderNo,
    required String carrier,
    required String trackingNumber,
    required String status,
  }) async {
    final orderId = await _orderIdFromOrderNo(session, orderNo);
    if (orderId.isEmpty) return null;
    final statusCode = _orderStatusCode(status);

    final orderUpdate = await http.patch(
      Uri.parse('$supabaseUrl/rest/v1/orders?id=eq.$orderId&select=*'),
      headers: _authHeaders(session, prefer: 'return=representation'),
      body: jsonEncode({'status': statusCode}),
    );
    if (orderUpdate.statusCode < 200 || orderUpdate.statusCode >= 300) {
      throw StateError(
        'Update order failed: ${orderUpdate.statusCode} ${orderUpdate.body}',
      );
    }

    final shipmentPatch = await http.patch(
      Uri.parse('$supabaseUrl/rest/v1/order_shipments?order_id=eq.$orderId'),
      headers: _authHeaders(session),
      body: jsonEncode({
        'carrier_name': carrier,
        'tracking_number': trackingNumber,
        if (trackingNumber.isNotEmpty)
          'shipped_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    if (shipmentPatch.statusCode < 200 || shipmentPatch.statusCode >= 300) {
      throw StateError(
        'Update shipment failed: ${shipmentPatch.statusCode} ${shipmentPatch.body}',
      );
    }

    await _insertRows(session, 'order_tracking_events', [
      {
        'order_id': orderId,
        'status': statusCode,
        'title': _orderStatusLabel(statusCode),
        'description':
            trackingNumber.isEmpty ? carrier : '$carrier - $trackingNumber',
      }
    ]);

    final refreshed = await fetchSellerOrders(session: session);
    return refreshed.where((order) => order.id == orderNo).firstOrNull;
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
    final category = _firstRelation(row['categories']);
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
    final imageMedia = media.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['type']?.toString() == 'image',
          orElse: () => media.isEmpty ? null : media.first,
        );
    final videoMedia = media.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['type']?.toString() == 'video',
          orElse: () => null,
        );
    final videoUrl = videoMedia?['url']?.toString() ?? '';

    return Product(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      shopId: row['shop_id']?.toString() ?? '',
      shopName: shop?['name']?.toString() ?? 'NP Market',
      category:
          category?['name']?.toString() ?? shop?['category']?.toString() ?? '',
      price: price,
      originalPrice: originalPrice > 0 ? originalPrice : price,
      rating: _num(row['rating']),
      soldCount: (row['sold_count'] as num?)?.toInt() ?? 0,
      imageUrl: imageMedia?['url']?.toString() ?? '',
      badge: row['badge']?.toString() ?? '',
      location: shop?['pickup_province']?.toString() ?? '',
      shippingLabel: 'จัดส่งโดยร้านค้า',
      serviceLabel: 'NP Market',
      promoLabel: '',
      discountPercent: _discountPercent(price, originalPrice),
      isVideo: videoUrl.isNotEmpty,
      videoViews: videoUrl.isEmpty ? '' : 'วิดีโอ',
      videoUrl: videoUrl,
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
    final shipment = _firstRelation(row['order_shipments']);

    return Order(
      id: row['order_no']?.toString() ?? row['id']?.toString() ?? '',
      items: items,
      address: shippingAddress.values.join(' '),
      paymentMethod: row['payment_method']?.toString() ?? '',
      status: _orderStatusLabel(row['status']?.toString() ?? ''),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      carrier: shipment?['carrier_name']?.toString() ?? '',
      trackingNumber: shipment?['tracking_number']?.toString() ?? '',
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
    Map<String, dynamic> row, {
    String query = '?select=*',
    String? prefer,
  }) async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table$query'),
      headers: _authHeaders(session, prefer: prefer ?? 'return=representation'),
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

  Future<void> _replaceShopCarriers(
    CustomerSession session,
    String shopId,
    List<String> carrierNames,
  ) async {
    if (shopId.isEmpty || carrierNames.isEmpty) return;
    final uri = Uri.parse('$supabaseUrl/rest/v1/carriers?select=id,name');
    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) return;
    final wanted = carrierNames.map((name) => name.trim()).toSet();
    final rows = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((row) => wanted.contains(row['name']?.toString().trim()))
        .toList();
    if (rows.isEmpty) return;
    await _upsertRows(
      session,
      'shop_carriers',
      rows
          .map((row) => {
                'shop_id': shopId,
                'carrier_id': row['id']?.toString() ?? '',
                'is_enabled': true,
              })
          .toList(),
      onConflict: 'shop_id,carrier_id',
    );
  }

  Future<void> _createRequiredShopDocuments(
    CustomerSession session,
    String shopId, {
    required String identityCardUrl,
    required String bankBookUrl,
    required String identityCardPath,
    required String bankBookPath,
  }) async {
    if (shopId.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    if (identityCardUrl.trim().isNotEmpty) {
      rows.add({
        'shop_id': shopId,
        'type': 'identity_card',
        'file_url': identityCardUrl.trim(),
        'file_path': identityCardPath.trim().isEmpty
            ? identityCardUrl.trim()
            : identityCardPath.trim(),
        'status': 'pending_review',
        'uploaded_by': session.userId,
      });
    }
    if (bankBookUrl.trim().isNotEmpty) {
      rows.add({
        'shop_id': shopId,
        'type': 'bank_book',
        'file_url': bankBookUrl.trim(),
        'file_path': bankBookPath.trim().isEmpty
            ? bankBookUrl.trim()
            : bankBookPath.trim(),
        'status': 'pending_review',
        'uploaded_by': session.userId,
      });
    }
    if (rows.isEmpty) return;
    await _insertRows(session, 'shop_documents', rows);
  }

  Future<String> _orderIdFromOrderNo(
    CustomerSession session,
    String orderNo,
  ) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/orders?select=id&order_no=eq.${Uri.encodeComponent(orderNo)}&limit=1',
    );
    final response = await http.get(uri, headers: _authHeaders(session));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Fetch order id failed: ${response.statusCode} ${response.body}',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return '';
    return (rows.first as Map<String, dynamic>)['id']?.toString() ?? '';
  }

  Future<String> _categoryIdByName(
    CustomerSession session,
    String categoryName,
  ) async {
    final name = categoryName.trim();
    if (name.isEmpty) return '';
    final response = await http.get(
      Uri.parse(
        '$supabaseUrl/rest/v1/categories?select=id&name=eq.${Uri.encodeComponent(name)}&limit=1',
      ),
      headers: _authHeaders(session),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return '';
    return (rows.first as Map<String, dynamic>)['id']?.toString() ?? '';
  }

  Future<UploadedShopFile> uploadShopFile({
    required CustomerSession session,
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final objectPath =
        '${session.userId}/$kind-${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final response = await http.put(
      Uri.parse(
        '$supabaseUrl/storage/v1/object/shop-documents/${Uri.encodeFull(objectPath)}',
      ),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/octet-stream',
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Upload shop file failed: ${response.statusCode} ${response.body}',
      );
    }
    final url =
        '$supabaseUrl/storage/v1/object/shop-documents/${Uri.encodeFull(objectPath)}';
    return UploadedShopFile(url: url, path: objectPath);
  }

  Future<String> uploadProductMedia({
    required CustomerSession session,
    required String shopId,
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isSupabaseEnabled) {
      throw StateError('Supabase is not configured.');
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final objectPath =
        '${session.userId}/products/$shopId/$kind-${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final response = await http.put(
      Uri.parse(
        '$supabaseUrl/storage/v1/object/product-media/${Uri.encodeFull(objectPath)}',
      ),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/octet-stream',
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Upload product media failed: ${response.statusCode} ${response.body}',
      );
    }
    return '$supabaseUrl/storage/v1/object/public/product-media/${Uri.encodeFull(objectPath)}';
  }

  Future<String> _signedShopFileUrl(
    CustomerSession session,
    String urlOrPath,
  ) async {
    final path = _shopFilePath(urlOrPath);
    if (path.isEmpty) return urlOrPath;
    final response = await http.post(
      Uri.parse(
        '$supabaseUrl/storage/v1/object/sign/shop-documents/${Uri.encodeFull(path)}',
      ),
      headers: _authHeaders(session),
      body: jsonEncode({'expiresIn': 3600}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return urlOrPath;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final signedUrl = body['signedURL']?.toString() ?? '';
    if (signedUrl.isEmpty) return urlOrPath;
    if (signedUrl.startsWith('http')) return signedUrl;
    return '$supabaseUrl/storage/v1$signedUrl';
  }

  String _shopFilePath(String urlOrPath) {
    if (urlOrPath.isEmpty) return '';
    const marker = '/storage/v1/object/shop-documents/';
    final markerIndex = urlOrPath.indexOf(marker);
    if (markerIndex < 0) return urlOrPath.contains('/') ? urlOrPath : '';
    final pathWithQuery = urlOrPath.substring(markerIndex + marker.length);
    return Uri.decodeComponent(pathWithQuery.split('?').first);
  }
}

class UploadedShopFile {
  const UploadedShopFile({required this.url, required this.path});

  final String url;
  final String path;
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

String _orderStatusCode(String status) {
  if (status == 'pending_payment' ||
      status == 'seller_confirming' ||
      status == 'awaiting_shipment' ||
      status == 'packed' ||
      status == 'shipped' ||
      status == 'in_transit' ||
      status == 'delivered' ||
      status == 'completed' ||
      status == 'cancelled' ||
      status == 'return_refund') {
    return status;
  }
  if (status.contains('เธเธณเธฃเธฐ')) return 'pending_payment';
  if (status.contains('เธขเธทเธเธขเธฑเธ')) return 'seller_confirming';
  if (status.contains('เธฃเธญเธเธฑเธ”เธชเนเธ')) return 'awaiting_shipment';
  if (status.contains('เน€เธ•เธฃเธตเธขเธก')) return 'packed';
  if (status.contains('เธชเนเธเนเธฅเนเธง')) return 'shipped';
  if (status.contains('เธเธณเธฅเธฑเธ')) return 'in_transit';
  if (status.contains('เนเธ”เนเธฃเธฑเธ')) return 'delivered';
  if (status.contains('เธชเธณเน€เธฃเนเธ')) return 'completed';
  if (status.contains('เธขเธเน€เธฅเธดเธ')) return 'cancelled';
  if (status.contains('เธเธทเธ')) return 'return_refund';
  return 'seller_confirming';
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

extension _ProductCopy on Product {
  Product copyWithId(String id, String shopId) {
    return Product(
      id: id,
      name: name,
      shopId: shopId,
      shopName: shopName,
      category: category,
      price: price,
      originalPrice: originalPrice,
      rating: rating,
      soldCount: soldCount,
      imageUrl: imageUrl,
      badge: badge,
      location: location,
      shippingLabel: shippingLabel,
      serviceLabel: serviceLabel,
      promoLabel: promoLabel,
      discountPercent: discountPercent,
      isVideo: isVideo,
      videoViews: videoViews,
      videoUrl: videoUrl,
      stock: stock,
      colorOptions: colorOptions,
      sizeOptions: sizeOptions,
      sizeChartImageUrl: sizeChartImageUrl,
    );
  }
}

SellerProfile _sellerProfileFromJson(Map<String, dynamic> row) {
  final ownerProfile = _firstRelation(row['profiles']);
  final carriers = <String>[];
  for (final item in row['shop_carriers'] as List<dynamic>? ?? const []) {
    if (item is! Map<String, dynamic>) continue;
    final carrier = _firstRelation(item['carriers']);
    final name = carrier?['name']?.toString() ?? '';
    if (name.isNotEmpty) carriers.add(name);
  }
  final documents = (row['shop_documents'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
  return SellerProfile(
    id: row['id']?.toString() ?? '',
    shopName: row['name']?.toString() ?? '',
    category: row['category']?.toString() ?? '',
    ownerName: ownerProfile?['display_name']?.toString() ?? '',
    phone: (row['phone']?.toString() ?? '').isNotEmpty
        ? row['phone']?.toString() ?? ''
        : ownerProfile?['phone']?.toString() ?? '',
    address: row['pickup_address']?.toString() ?? '',
    description: row['description']?.toString() ?? '',
    pickupProvince: row['pickup_province']?.toString() ?? '',
    pickupDistrict: row['pickup_district']?.toString() ?? '',
    pickupSubDistrict: row['pickup_sub_district']?.toString() ?? '',
    pickupPostcode: row['pickup_postcode']?.toString() ?? '',
    bankAccountName: row['bank_account_name']?.toString() ?? '',
    bankAccountNumber: row['bank_account_number']?.toString() ?? '',
    bankName: row['bank_name']?.toString() ?? '',
    enabledCarriers: carriers,
    logoUrl: row['logo_url']?.toString() ?? '',
    identityCardUrl: _latestShopDocumentUrl(documents, 'identity_card'),
    bankBookUrl: _latestShopDocumentUrl(documents, 'bank_book'),
    isVerified: row['status']?.toString() == 'active',
    status: row['status']?.toString() ?? 'pending_review',
    reviewNote: row['review_note']?.toString() ?? '',
  );
}

String _latestShopDocumentUrl(
    List<Map<String, dynamic>> documents, String type) {
  Map<String, dynamic>? latest;
  for (final document in documents.where((item) => item['type'] == type)) {
    final currentTime = DateTime.tryParse(
          latest?['updated_at']?.toString() ??
              latest?['created_at']?.toString() ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final documentTime = DateTime.tryParse(
          document['updated_at']?.toString() ??
              document['created_at']?.toString() ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (latest == null || documentTime.isAfter(currentTime)) latest = document;
  }
  return latest?['file_url']?.toString() ?? '';
}
