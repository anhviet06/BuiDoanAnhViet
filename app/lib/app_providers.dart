import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'providers/auth_provider.dart';
import 'services/admin_services.dart';
import 'services/api_client.dart';
import 'services/device_id_service.dart';
import 'services/face_liveness.dart';
import 'services/employee_services.dart';
import 'services/location_service.dart';
import 'services/qr_scanner.dart';
import 'widgets/face_liveness_view.dart';

/// Các provider dùng chung toàn app (service không giữ trạng thái + AuthProvider).
/// Provider có trạng thái của từng khu vực (admin...) được tạo ở đầu khu vực đó để hủy khi đăng xuất.
/// Dùng chung cho main.dart và test để nối dây giống nhau.
List<SingleChildWidget> buildAppProviders({
  required ApiClient api,
  required AuthProvider auth,
  LocationService? location,
  FaceLivenessBuilder? faceLiveness,
  QrScannerBuilder? qrScanner,
}) =>
    [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      Provider<LocationService>.value(value: location ?? GeolocatorLocationService()),
      Provider<FaceLivenessBuilder>.value(value: faceLiveness ?? buildFaceLiveness),
      Provider<QrScannerBuilder>.value(value: qrScanner ?? buildMobileScanner),
      Provider<DeviceIdService>.value(value: DeviceIdService(api.storage)),
      Provider<UserService>.value(value: UserService(api)),
      Provider<ShiftService>.value(value: ShiftService(api)),
      Provider<SettingsService>.value(value: SettingsService(api)),
      Provider<LeaveService>.value(value: LeaveService(api)),
      Provider<ReportService>.value(value: ReportService(api)),
      Provider<AdminAttendanceService>.value(value: AdminAttendanceService(api)),
      Provider<AttendanceService>.value(value: AttendanceService(api)),
      Provider<ProfileService>.value(value: ProfileService(api)),
    ];
