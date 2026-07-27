class Facility {
  final int id;
  final String name;
  final String icon;
  final double price;
  final String? description;

  Facility({
    required this.id,
    required this.name,
    required this.icon,
    required this.price,
    this.description,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'add',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      description: json['description'] as String?,
    );
  }
}
