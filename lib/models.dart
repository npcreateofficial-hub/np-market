class Product {
  const Product({
    required this.id,
    required this.name,
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
    this.stock = 268,
    this.colorOptions = const [],
    this.sizeOptions = const [],
    this.sizeChartImageUrl,
  });

  final String id;
  final String name;
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
  final int stock;
  final List<String> colorOptions;
  final List<String> sizeOptions;
  final String? sizeChartImageUrl;
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

class SellerProfile {
  const SellerProfile({
    required this.shopName,
    required this.category,
    required this.ownerName,
    required this.phone,
    required this.address,
    this.description = '',
    this.pickupProvince = '',
    this.enabledCarriers = const [],
    this.logoUrl = '',
    this.isVerified = false,
  });

  final String shopName;
  final String category;
  final String ownerName;
  final String phone;
  final String address;
  final String description;
  final String pickupProvince;
  final List<String> enabledCarriers;
  final String logoUrl;
  final bool isVerified;
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
  String get fullAddress => '$detail $subDistrict $district $province $postcode';

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
