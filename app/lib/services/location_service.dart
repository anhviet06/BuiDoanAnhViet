import 'package:geolocator/geolocator.dart';

/// Vị trí GPS đọc được. [isMocked] = thiết bị báo đây là vị trí giả.
class LocationReading {
  final double latitude;
  final double longitude;
  final bool isMocked;

  const LocationReading(this.latitude, this.longitude, {this.isMocked = false});
}

/// Lỗi lấy vị trí, [message] là tiếng Việt để hiện cho người dùng.
class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Tách interface để test không cần plugin thật (và để T8 dùng lại cho chấm công).
abstract class LocationService {
  Future<LocationReading> current();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationReading> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Dịch vụ vị trí đang tắt. Hãy bật GPS rồi thử lại.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Bạn chưa cấp quyền truy cập vị trí cho ứng dụng.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Quyền vị trí bị chặn. Hãy cấp lại trong Cài đặt của thiết bị.');
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return LocationReading(p.latitude, p.longitude, isMocked: p.isMocked);
    } catch (_) {
      throw const LocationException('Không lấy được vị trí hiện tại. Hãy ra nơi thoáng và thử lại.');
    }
  }
}
