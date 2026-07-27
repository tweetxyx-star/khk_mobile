class Net {
  final int id;
  final String name;
  final String location;
  final String? description;
  final double pricePerHour;
  final String? imageUrl;
  final bool isActive;

  // Runtime fields - not from DB
  final String? status;
  final String? nextSlot;

  Net({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    required this.pricePerHour,
    this.imageUrl,
    this.isActive = true,
    this.status,
    this.nextSlot,
  });

  factory Net.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic value) {
      if (value == null) return 5.0; // Default price
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 5.0;
      return 5.0;
    }

    return Net(
      id: json['id'] as int,
      name: json['name'] as String,
      location: json['location'] as String? ?? 'KHK Cricket Arena',
      description: json['description'] as String?,
      pricePerHour: parsePrice(json['price_per_hour']),
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String?,
      nextSlot: json['next_slot'] as String?,
    );
  }

  Net copyWith({String? status, String? nextSlot}) {
    return Net(
      id: id,
      name: name,
      location: location,
      description: description,
      pricePerHour: pricePerHour,
      imageUrl: imageUrl,
      isActive: isActive,
      status: status ?? this.status,
      nextSlot: nextSlot ?? this.nextSlot,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'price_per_hour': pricePerHour,
      'image_url': imageUrl,
      'is_active': isActive,
      'status': status,
      'next_slot': nextSlot,
    };
  }
}
