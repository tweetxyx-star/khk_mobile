class Coach {
  final int id;
  final String name;
  final String? email;
  final String? mobile;
  final String? imageUrl;
  final String? specialty; // From Laravel accessor - maps to specialization
  final String? bio;
  final double? rating;
  final int? experience;
  final int? students;
  final double? hourlyRate; // From Laravel accessor - maps to price_per_hour
  final bool available;

  Coach({
    required this.id,
    required this.name,
    this.email,
    this.mobile,
    this.imageUrl,
    this.specialty,
    this.bio,
    this.rating,
    this.experience,
    this.students,
    this.hourlyRate,
    this.available = true,
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      mobile: json['mobile'] as String?,
      imageUrl: json['image_url'] as String? ?? 'https://i.pravatar.cc/150',
      specialty:
          json['specialty'] as String? ??
          json['specialization'] as String? ??
          'Batting',
      bio: json['bio'] as String?,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString()) ?? 4.5
          : 4.5,
      experience: json['experience'] as int?,
      students: json['students'] as int?,
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : json['price_per_hour'] != null
          ? double.tryParse(json['price_per_hour'].toString())
          : 25.0,
      available: json['available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'image_url': imageUrl,
      'specialty': specialty,
      'bio': bio,
      'rating': rating,
      'experience': experience,
      'students': students,
      'hourly_rate': hourlyRate,
      'available': available,
    };
  }

  @override
  String toString() {
    return 'Coach{id: $id, name: $name, specialty: $specialty, hourlyRate: $hourlyRate}';
  }
}
