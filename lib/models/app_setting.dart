class AppSetting {
  final String? logo;
  final String? bgImage;
  final String? banner1;
  final String? banner2;
  final String? banner3;
  final String? onboardImage1;
  final String? onboardImage2;
  final String? onboardImage3;

  AppSetting({
    this.logo,
    this.bgImage,
    this.banner1,
    this.banner2,
    this.banner3,
    this.onboardImage1,
    this.onboardImage2,
    this.onboardImage3,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) {
    return AppSetting(
      logo: json['logo'],
      bgImage: json['bg_image'],
      banner1: json['banner1'],
      banner2: json['banner2'],
      banner3: json['banner3'],
      onboardImage1: json['onboard_image_1'],
      onboardImage2: json['onboard_image_2'],
      onboardImage3: json['onboard_image_3'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logo': logo,
      'bg_image': bgImage,
      'banner1': banner1,
      'banner2': banner2,
      'banner3': banner3,
      'onboard_image_1': onboardImage1,
      'onboard_image_2': onboardImage2,
      'onboard_image_3': onboardImage3,
    };
  }
}
