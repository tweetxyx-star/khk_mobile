class User {
  final int id;
  final String name;
  final String phone;
  final String? countryCode;
  final String? email;
  final String? avatar;
  final String? token;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.countryCode,
    this.email,
    this.avatar,
    this.token,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      countryCode: json['country_code'],
      email: json['email'],
      avatar: json['avatar'],
      token: json['token'] ?? json['access_token'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'country_code': countryCode,
      'email': email,
      'avatar': avatar,
      'token': token,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? phone,
    String? countryCode,
    String? email,
    String? avatar,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, phone: $phone, countryCode: $countryCode}';
  }
}
