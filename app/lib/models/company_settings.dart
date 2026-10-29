/// Cấu hình công ty: vị trí chấm công hợp lệ, bán kính và mức phạt đi trễ.
class CompanySettings {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double latePenaltyPerMinute;

  const CompanySettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.latePenaltyPerMinute,
  });

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
        latitude: ((json['latitude'] ?? 0) as num).toDouble(),
        longitude: ((json['longitude'] ?? 0) as num).toDouble(),
        radiusMeters: ((json['radiusMeters'] ?? 0) as num).toDouble(),
        latePenaltyPerMinute: ((json['latePenaltyPerMinute'] ?? 0) as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'latePenaltyPerMinute': latePenaltyPerMinute,
      };
}
