import '../../core/http/api_client.dart';
import '../../shared/models/address.dart';
import '../../shared/models/category.dart';
import '../../shared/models/cart.dart';
import '../../shared/models/checkout.dart';
import '../../shared/models/complaint.dart';
import '../../shared/models/delivery.dart';
import '../../shared/models/order.dart';
import '../../shared/models/product.dart';
import '../../shared/models/user.dart';
import '../../shared/models/vendor.dart';

/// Extraction de la valeur `data` d'une enveloppe API.
Map<String, dynamic>? _dataObject(Map<String, dynamic> response) {
  final data = response['data'];
  return data is Map<String, dynamic> ? data : null;
}

List<Map<String, dynamic>> _dataList(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  return [];
}

/// Repository partagé (catalogue public + client).
class MarketplaceApi {
  MarketplaceApi(this._api);

  final ApiClient _api;

  Future<HomeData> home() async {
    final response = await _api.get('/home');
    return HomeData.fromJson(response);
  }

  Future<List<Category>> categories() async {
    final response = await _api.get('/categories');
    return _dataList(response).map(Category.fromJson).toList();
  }

  Future<List<Product>> products({
    String? categoryId,
    String? q,
    String? vendorId,
    bool? inStock,
    int perPage = 25,
  }) async {
    final response = await _api.get('/products', query: {
      if (categoryId != null) 'category_id': categoryId,
      if (q != null && q.isNotEmpty) 'q': q,
      if (vendorId != null) 'vendor_id': vendorId,
      if (inStock != null) 'in_stock': inStock.toString(),
      'per_page': perPage.toString(),
    });
    return _dataList(response).map(Product.fromJson).toList();
  }

  Future<Product> product(String id) async {
    final response = await _api.get('/products/$id');
    return Product.fromJson(_dataObject(response) ?? {});
  }

  Future<List<Vendor>> vendors({String? q, String? city, int perPage = 25}) async {
    final response = await _api.get('/vendors', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (city != null && city.isNotEmpty) 'city': city,
      'per_page': perPage.toString(),
    });
    return _dataList(response).map(Vendor.fromJson).toList();
  }

  Future<ShopDetail> vendor(String id) async {
    final response = await _api.get('/vendors/$id');
    return ShopDetail.fromJson(_dataObject(response) ?? {});
  }

  Future<DeliveryQuote> deliveryQuote(String vendorId, {String? city, String? address, double? latitude, double? longitude}) async {
    final response = await _api.post('/delivery/quote', body: {
      'vendor_id': vendorId,
      'address': {
        if (city != null && city.isNotEmpty) 'city': city,
        if (address != null && address.isNotEmpty) 'address_text': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    });
    return DeliveryQuote.fromJson(_dataObject(response) ?? {});
  }

  Future<List<Address>> addresses() async {
    final response = await _api.get('/addresses');
    return _dataList(response).map(Address.fromJson).toList();
  }

  Future<Address> createAddress({
    String? label,
    String? fullAddress,
    String? city,
    String? area,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final response = await _api.post('/addresses', body: {
      if (label != null && label.isNotEmpty) 'label': label,
      'full_address': fullAddress ?? '',
      if (city != null && city.isNotEmpty) 'city': city,
      if (area != null && area.isNotEmpty) 'area': area,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isDefault ?? false) 'is_default': true,
    });
    return Address.fromJson(_dataObject(response) ?? {});
  }

  Future<Cart> cart() async {
    final response = await _api.get('/cart');
    final data = _dataObject(response);
    if (data == null) {
      return const Cart(id: '', items: [], subtotal: 0);
    }
    return Cart.fromJson(data);
  }

  Future<Cart> addToCart(String productId, {int quantity = 1}) async {
    final response = await _api.post('/cart/items', body: {'product_id': productId, 'quantity': quantity});
    return Cart.fromJson(_dataObject(response) ?? {});
  }

  Future<Cart> updateCartItem(String itemId, int quantity) async {
    final response = await _api.patch('/cart/items/$itemId', body: {'quantity': quantity});
    return Cart.fromJson(_dataObject(response) ?? {});
  }

  Future<Cart> removeCartItem(String itemId) async {
    final response = await _api.delete('/cart/items/$itemId');
    return Cart.fromJson(_dataObject(response) ?? {});
  }

  Future<void> clearCart() async {
    await _api.delete('/cart');
  }

  Future<OrderSummary> orderSummary(String addressId) async {
    final response = await _api.post('/orders/summary', body: {'address_id': addressId});
    return OrderSummary.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> createOrder(String addressId, {String? notes}) async {
    final response = await _api.post('/orders', body: {
      'address_id': addressId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Map<String, dynamic>> createPayment(String orderId) async {
    final response = await _api.post('/payments/create', body: {'order_id': orderId});
    return _dataObject(response) ?? {};
  }

  Future<Map<String, dynamic>> verifyPayment(String transactionId) async {
    final response = await _api.post('/payments/verify', body: {'transaction_id': transactionId});
    return _dataObject(response) ?? {};
  }

  Future<List<Order>> orders({int perPage = 25}) async {
    final response = await _api.get('/orders', query: {'per_page': perPage.toString()});
    return _dataList(response).map(Order.fromJson).toList();
  }

  Future<Order> order(String id) async {
    final response = await _api.get('/orders/$id');
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> cancelOrder(String orderId, String reason) async {
    final response = await _api.post('/orders/$orderId/cancel', body: {'reason': reason});
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<List<Complaint>> complaints({int perPage = 25}) async {
    final response = await _api.get('/complaints', query: {'per_page': perPage.toString()});
    return _dataList(response).map(Complaint.fromJson).toList();
  }

  Future<Complaint> complaint(String id) async {
    final response = await _api.get('/complaints/$id');
    return Complaint.fromJson(_dataObject(response) ?? {});
  }

  Future<Complaint> createComplaint({String? orderId, required String type, required String subject, required String description}) async {
    final response = await _api.post('/complaints', body: {
      if (orderId != null) 'order_id': orderId,
      'type': type,
      'subject': subject,
      'description': description,
    });
    return Complaint.fromJson(_dataObject(response) ?? {});
  }

  Future<void> replyComplaint(String complaintId, String message) async {
    await _api.post('/complaints/$complaintId/messages', body: {'message': message});
  }

  Future<List<Delivery>> myDeliveries() async {
    final response = await _api.get('/driver/me/deliveries');
    return _dataList(response).map(Delivery.fromJson).toList();
  }

  Future<List<Delivery>> availableOffers() async {
    final response = await _api.get('/driver/me/deliveries/offers');
    return _dataList(response).map(Delivery.fromJson).toList();
  }

  Future<Delivery> acceptOffers(String id) async {
    final response = await _api.post('/driver/me/deliveries/$id/accept');
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Delivery> declineOffer(String id, {String? reason}) async {
    final response = await _api.post('/driver/me/deliveries/$id/decline', body: {if (reason != null) 'reason': reason});
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Delivery> markPickedUp(String id) async {
    final response = await _api.post('/driver/me/deliveries/$id/pickup');
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Delivery> markInDelivery(String id) async {
    final response = await _api.post('/driver/me/deliveries/$id/start');
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Delivery> markDelivered(String id, {String? proofCode}) async {
    final response = await _api.post('/driver/me/deliveries/$id/deliver', body: {
      if (proofCode != null && proofCode.isNotEmpty) 'proof_code': proofCode,
    });
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Delivery> reportIncident(String id, String message) async {
    final response = await _api.post('/driver/me/deliveries/$id/incident', body: {'message': message});
    return Delivery.fromJson(_dataObject(response) ?? {});
  }

  Future<Map<String, dynamic>> setAvailability(bool available, {double? latitude, double? longitude}) async {
    final response = await _api.post('/driver/me/availability', body: {
      'available': available,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return _dataObject(response) ?? {};
  }

  Future<Map<String, dynamic>> updateDriverLocation(double latitude, double longitude) async {
    final response = await _api.patch('/driver/me/availability/location', body: {
      'latitude': latitude,
      'longitude': longitude,
    });
    return _dataObject(response) ?? {};
  }

  Future<Map<String, dynamic>> driverStatus() async {
    final response = await _api.get('/driver/me/status');
    return _dataObject(response) ?? {};
  }

  Future<Map<String, dynamic>> vendorStatus() async {
    final response = await _api.get('/vendors/me/status');
    return _dataObject(response) ?? {};
  }

  Future<void> vendorOnboarding({
    required String businessName,
    String? legalName,
    String? ifu,
    String? description,
    required String phone,
    String? email,
    String? city,
    String? address,
  }) async {
    await _api.post('/vendors/me/onboarding', body: {
      'business_name': businessName,
      if (legalName != null && legalName.isNotEmpty) 'legal_name': legalName,
      if (ifu != null && ifu.isNotEmpty) 'ifu': ifu,
      if (description != null && description.isNotEmpty) 'description': description,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (city != null && city.isNotEmpty) 'city': city,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  }

  Future<void> driverOnboarding({
    required String vehicle,
  }) async {
    await _api.post('/driver/me/onboarding', body: {'vehicle': vehicle});
  }

  Future<void> registerDevice({required String fcmToken, required String platform}) async {
    await _api.post('/me/devices', body: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<User> me() async {
    final response = await _api.get('/me');
    return User.fromJson(_dataObject(response) ?? {});
  }

  Future<void> updateMe({String? name, String? email}) async {
    await _api.patch('/me', body: {
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null) 'email': email,
    });
  }

  // ------------------------------------------------------------------
  // Vendeur : produits
  // ------------------------------------------------------------------

  Future<List<Product>> vendorProducts() async {
    final response = await _api.get('/vendors/me/products');
    return _dataList(response).map(Product.fromJson).toList();
  }

  Future<Product> createProduct({
    required String name,
    required int price,
    required String categoryId,
    String? description,
    String? unit,
    int? stockQty,
    bool isAvailable = true,
  }) async {
    final response = await _api.post('/vendors/me/products', body: {
      'name': name,
      'price': price,
      'category_id': categoryId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
      if (stockQty != null) 'stock_qty': stockQty,
      'is_available': isAvailable,
    });
    return Product.fromJson(_dataObject(response) ?? {});
  }

  Future<Product> updateProduct(String productId, {
    String? name,
    int? price,
    String? categoryId,
    String? description,
    String? unit,
    int? stockQty,
    bool? isAvailable,
    bool? isActive,
  }) async {
    final response = await _api.patch('/vendors/me/products/$productId', body: {
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'description': description,
      if (unit != null) 'unit': unit,
      if (stockQty != null) 'stock_qty': stockQty,
      if (isAvailable != null) 'is_available': isAvailable,
      if (isActive != null) 'is_active': isActive,
    });
    return Product.fromJson(_dataObject(response) ?? {});
  }

  Future<void> deleteProduct(String productId) async {
    await _api.delete('/vendors/me/products/$productId');
  }

  // ------------------------------------------------------------------
  // Vendeur : commandes
  // ------------------------------------------------------------------

  Future<List<Order>> vendorOrders({int perPage = 25}) async {
    final response = await _api.get('/vendors/me/orders', query: {'per_page': perPage.toString()});
    return _dataList(response).map(Order.fromJson).toList();
  }

  Future<Order> vendorAccept(String orderId) async {
    final response = await _api.post('/vendors/me/orders/$orderId/accept');
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> vendorRefuse(String orderId, {required String reason}) async {
    final response = await _api.post('/vendors/me/orders/$orderId/refuse', body: {'reason': reason});
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> vendorPreparing(String orderId) async {
    final response = await _api.post('/vendors/me/orders/$orderId/preparing');
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> vendorReady(String orderId) async {
    final response = await _api.post('/vendors/me/orders/$orderId/ready');
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<Order> vendorCancel(String orderId, {required String reason}) async {
    final response = await _api.post('/vendors/me/orders/$orderId/cancel', body: {'reason': reason});
    return Order.fromJson(_dataObject(response) ?? {});
  }

  Future<List<String>> categoriesForProductForm() async {
    final cats = await categories();
    return cats.map((c) => c.id).toList();
  }

  // ------------------------------------------------------------------
  // Upload médias
  // ------------------------------------------------------------------

  Future<void> uploadVendorDocument(String type, List<int> bytes, {String? fileName}) async {
    await _api.multipart(
      '/vendors/me/documents',
      fields: {'type': type},
      files: {'document': bytes},
      fileNames: {'document': fileName ?? 'document.pdf'},
    );
  }

  Future<void> uploadDriverDocument(String type, List<int> bytes, {String? fileName}) async {
    await _api.multipart(
      '/driver/me/documents',
      fields: {'type': type},
      files: {'document': bytes},
      fileNames: {'document': fileName ?? 'document.pdf'},
    );
  }

  /// Ajoute une image à un produit (première image = image principale).
  Future<void> uploadProductImage(String productId, List<int> bytes, {String? fileName, bool isMain = false}) async {
    await _api.multipart(
      '/vendors/me/products/$productId/images',
      fields: {if (isMain) 'is_main': '1'},
      files: {'image': bytes},
      fileNames: {'image': fileName ?? 'image.jpg'},
    );
  }

  /// Met à jour le logo / la couverture de la boutique du vendeur.
  Future<void> updateVendorMedia({List<int>? logo, List<int>? cover}) async {
    final files = <String, List<int>>{};
    final names = <String, String>{};
    if (logo != null) {
      files['logo'] = logo;
      names['logo'] = 'logo.${_imageExtension(logo)}';
    }
    if (cover != null) {
      files['cover'] = cover;
      names['cover'] = 'cover.${_imageExtension(cover)}';
    }
    if (files.isEmpty) {
      return;
    }
    await _api.multipart(
      '/vendors/me',
      fields: const {},
      files: files,
      fileNames: names,
      method: 'PATCH',
    );
  }
}

/// Détecte l'extension d'une image à partir de ses octets (magic bytes).
String _imageExtension(List<int> bytes) {
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
    return 'webp';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'jpg';
  }
  return 'jpg';
}

class HomeVendor {
  const HomeVendor({
    required this.id,
    required this.businessName,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.city,
    this.isOpen,
  });

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? city;
  final bool? isOpen;

  factory HomeVendor.fromJson(Map<String, dynamic> json) => HomeVendor(
        id: _s(json['id']),
        businessName: _s(json['business_name']),
        description: json['description'] is String ? json['description'] as String : null,
        logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
        coverUrl: json['cover_url'] is String ? json['cover_url'] as String : null,
        city: json['city'] is String ? json['city'] as String : null,
        isOpen: json['is_open'] is bool ? json['is_open'] as bool : null,
      );
}

class HomeData {
  const HomeData({this.categories = const [], this.featuredProducts = const [], this.vendors = const []});

  final List<Category> categories;
  final List<Product> featuredProducts;
  final List<HomeVendor> vendors;

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawProducts = json['featured_products'];
    final rawVendors = json['vendors'];

    return HomeData(
      categories: rawCategories is List ? rawCategories.whereType<Map<String, dynamic>>().map(Category.fromJson).toList() : [],
      featuredProducts: rawProducts is List ? rawProducts.whereType<Map<String, dynamic>>().map(Product.fromJson).toList() : [],
      vendors: rawVendors is List ? rawVendors.whereType<Map<String, dynamic>>().map(HomeVendor.fromJson).toList() : [],
    );
  }
}

class ShopDetail {
  const ShopDetail({required this.vendor, this.products = const [], this.hours = const []});

  final Vendor vendor;
  final List<Product> products;
  final List<OpeningHour> hours;

  factory ShopDetail.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final rawHours = json['hours'];
    final rawVendor = Map<String, dynamic>.of(json)..remove('products')..remove('hours');

    return ShopDetail(
      vendor: Vendor.fromJson(rawVendor),
      products: rawProducts is List ? rawProducts.whereType<Map<String, dynamic>>().map(Product.fromJson).toList() : [],
      hours: rawHours is List ? rawHours.whereType<Map<String, dynamic>>().map(OpeningHour.fromJson).toList() : [],
    );
  }
}

class OpeningHour {
  const OpeningHour({required this.dayOfWeek, this.opensAt, this.closesAt, this.isClosed = false});

  final int dayOfWeek;
  final String? opensAt;
  final String? closesAt;
  final bool isClosed;

  factory OpeningHour.fromJson(Map<String, dynamic> json) => OpeningHour(
        dayOfWeek: _i(json['day_of_week']),
        opensAt: json['opens_at'] is String ? json['opens_at'] as String : null,
        closesAt: json['closes_at'] is String ? json['closes_at'] as String : null,
        isClosed: json['is_closed'] == true,
      );
}

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;