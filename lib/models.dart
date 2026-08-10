class ProductMediaItem {
  const ProductMediaItem({
    required this.type,
    required this.url,
  });

  final String type;
  final String url;

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.shopId = '',
    required this.shopName,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.soldCount,
    required this.imageUrl,
    required this.badge,
    required this.location,
    required this.shippingLabel,
    required this.serviceLabel,
    required this.promoLabel,
    required this.discountPercent,
    required this.isVideo,
    required this.videoViews,
    this.videoUrl = '',
    this.stock = 268,
    this.description = '',
    this.sku = '',
    this.weightKg = 0,
    this.parcelSize = '',
    this.status = 'active',
    this.mediaItems = const [],
    this.galleryImageUrls = const [],
    this.variantImageUrls = const {},
    this.colorOptions = const [],
    this.sizeOptions = const [],
    this.sizeChartImageUrl,
    this.attributes = const {},
    this.detailImageUrls = const [],
  });

  final String id;
  final String name;
  final String shopId;
  final String shopName;
  final String category;
  final double price;
  final double originalPrice;
  final double rating;
  final int soldCount;
  final String imageUrl;
  final String badge;
  final String location;
  final String shippingLabel;
  final String serviceLabel;
  final String promoLabel;
  final int discountPercent;
  final bool isVideo;
  final String videoViews;
  final String videoUrl;
  final int stock;
  final String description;
  final String sku;
  final double weightKg;
  final String parcelSize;
  final String status;
  final List<ProductMediaItem> mediaItems;
  final List<String> galleryImageUrls;
  final Map<String, String> variantImageUrls;
  final List<String> colorOptions;
  final List<String> sizeOptions;
  final String? sizeChartImageUrl;
  final Map<String, String> attributes;
  final List<String> detailImageUrls;

  Product copyWith({
    String? id,
    String? name,
    String? shopId,
    String? shopName,
    String? category,
    double? price,
    double? originalPrice,
    double? rating,
    int? soldCount,
    String? imageUrl,
    String? badge,
    String? location,
    String? shippingLabel,
    String? serviceLabel,
    String? promoLabel,
    int? discountPercent,
    bool? isVideo,
    String? videoViews,
    String? videoUrl,
    int? stock,
    String? description,
    String? sku,
    double? weightKg,
    String? parcelSize,
    String? status,
    List<ProductMediaItem>? mediaItems,
    List<String>? galleryImageUrls,
    Map<String, String>? variantImageUrls,
    List<String>? colorOptions,
    List<String>? sizeOptions,
    String? sizeChartImageUrl,
    Map<String, String>? attributes,
    List<String>? detailImageUrls,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      category: category ?? this.category,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      soldCount: soldCount ?? this.soldCount,
      imageUrl: imageUrl ?? this.imageUrl,
      badge: badge ?? this.badge,
      location: location ?? this.location,
      shippingLabel: shippingLabel ?? this.shippingLabel,
      serviceLabel: serviceLabel ?? this.serviceLabel,
      promoLabel: promoLabel ?? this.promoLabel,
      discountPercent: discountPercent ?? this.discountPercent,
      isVideo: isVideo ?? this.isVideo,
      videoViews: videoViews ?? this.videoViews,
      videoUrl: videoUrl ?? this.videoUrl,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      weightKg: weightKg ?? this.weightKg,
      parcelSize: parcelSize ?? this.parcelSize,
      status: status ?? this.status,
      mediaItems: mediaItems ?? this.mediaItems,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      variantImageUrls: variantImageUrls ?? this.variantImageUrls,
      colorOptions: colorOptions ?? this.colorOptions,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      sizeChartImageUrl: sizeChartImageUrl ?? this.sizeChartImageUrl,
      attributes: attributes ?? this.attributes,
      detailImageUrls: detailImageUrls ?? this.detailImageUrls,
    );
  }
}

class MarketCategory {
  const MarketCategory({
    required this.name,
    required this.icon,
    required this.itemCount,
  });

  final String name;
  final String icon;
  final int itemCount;
}

class Campaign {
  const Campaign({
    required this.title,
    required this.subtitle,
    required this.label,
  });

  final String title;
  final String subtitle;
  final String label;
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.productCount,
    required this.badge,
  });

  final String id;
  final String name;
  final String category;
  final double rating;
  final int productCount;
  final String badge;
}

class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phone,
    this.avatarUrl = '',
    this.role = 'buyer',
    this.hasProfile = true,
  });

  final String id;
  final String email;
  final String displayName;
  final String phone;
  final String avatarUrl;
  final String role;
  final bool hasProfile;

  String get nameOrEmail => displayName.isNotEmpty ? displayName : email;

  CustomerAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phone,
    String? avatarUrl,
    String? role,
    bool? hasProfile,
  }) {
    return CustomerAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      hasProfile: hasProfile ?? this.hasProfile,
    );
  }
}

class SellerProfile {
  const SellerProfile({
    this.id = '',
    required this.shopName,
    required this.category,
    required this.ownerName,
    required this.phone,
    required this.address,
    this.description = '',
    this.pickupProvince = '',
    this.pickupDistrict = '',
    this.pickupSubDistrict = '',
    this.pickupPostcode = '',
    this.enabledCarriers = const [],
    this.logoUrl = '',
    this.identityCardUrl = '',
    this.bankBookUrl = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankName = '',
    this.isVerified = false,
    this.status = 'pending_review',
    this.reviewNote = '',
  });

  final String id;
  final String shopName;
  final String category;
  final String ownerName;
  final String phone;
  final String address;
  final String description;
  final String pickupProvince;
  final String pickupDistrict;
  final String pickupSubDistrict;
  final String pickupPostcode;
  final List<String> enabledCarriers;
  final String logoUrl;
  final String identityCardUrl;
  final String bankBookUrl;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankName;
  final bool isVerified;
  final String status;
  final String reviewNote;

  SellerProfile copyWith({
    String? id,
    String? shopName,
    String? category,
    String? ownerName,
    String? phone,
    String? address,
    String? description,
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupSubDistrict,
    String? pickupPostcode,
    List<String>? enabledCarriers,
    String? logoUrl,
    String? identityCardUrl,
    String? bankBookUrl,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    bool? isVerified,
    String? status,
    String? reviewNote,
  }) {
    return SellerProfile(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      category: category ?? this.category,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      description: description ?? this.description,
      pickupProvince: pickupProvince ?? this.pickupProvince,
      pickupDistrict: pickupDistrict ?? this.pickupDistrict,
      pickupSubDistrict: pickupSubDistrict ?? this.pickupSubDistrict,
      pickupPostcode: pickupPostcode ?? this.pickupPostcode,
      enabledCarriers: enabledCarriers ?? this.enabledCarriers,
      logoUrl: logoUrl ?? this.logoUrl,
      identityCardUrl: identityCardUrl ?? this.identityCardUrl,
      bankBookUrl: bankBookUrl ?? this.bankBookUrl,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankName: bankName ?? this.bankName,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

class CartItem {
  const CartItem({
    required this.product,
    required this.color,
    required this.size,
    required this.quantity,
  });

  final Product product;
  final String color;
  final String size;
  final int quantity;

  double get total => product.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      color: color,
      size: size,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Address {
  const Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.detail,
    required this.province,
    required this.district,
    required this.subDistrict,
    required this.postcode,
    this.isDefault = false,
    this.label = '',
  });

  final String id;
  final String name;
  final String phone;
  final String detail;
  final String province;
  final String district;
  final String subDistrict;
  final String postcode;
  final bool isDefault;
  final String label;

  String get shortAddress => '$detail $subDistrict $district $province';
  String get fullAddress =>
      '$detail $subDistrict $district $province $postcode';

  Address copyWith({bool? isDefault}) {
    return Address(
      id: id,
      name: name,
      phone: phone,
      detail: detail,
      province: province,
      district: district,
      subDistrict: subDistrict,
      postcode: postcode,
      isDefault: isDefault ?? this.isDefault,
      label: label,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.address,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.carrier = '',
    this.trackingNumber = '',
    this.updatedAt,
  });

  final String id;
  final List<CartItem> items;
  final String address;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final String carrier;
  final String trackingNumber;
  final DateTime? updatedAt;

  double get subtotal => items.fold(0, (total, item) => total + item.total);

  double get shippingFee => 0;

  double get discount => 0;

  double get grandTotal => subtotal + shippingFee - discount;

  Order copyWith({
    String? status,
    String? carrier,
    String? trackingNumber,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id,
      items: items,
      address: address,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt,
      carrier: carrier ?? this.carrier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
