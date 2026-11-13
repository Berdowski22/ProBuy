class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String image;
  final double rating;
  final int stock;
  final List<String> features;
  final Map<String, String> specs;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.image,
    required this.rating,
    required this.stock,
    this.features = const [],
    this.specs = const {},
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      image: json['image'] as String,
      rating: (json['rating'] as num).toDouble(),
      stock: json['stock'] as int,
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      specs: (json['specs'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'image': image,
        'rating': rating,
        'stock': stock,
        'features': features,
        'specs': specs,
      };
}
