import 'package:buidoananhviet/core/config.dart';
import 'package:buidoananhviet/services/device_id_service.dart';
import 'package:buidoananhviet/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_employee_backend.dart';
import 'helpers.dart';

Finder field(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class Harness {
  final FakeEmployeeBackend backend;
  final FakeTokenStorage storage;
  final FakeFaceLiveness face;
  final FakeQrScanner scanner;

  Harness(this.backend, this.storage, this.face, this.scanner);

  List<dynamic> get checkRequests => backend.adapter.requests.where((r) => r.path.contains('/check-')).toList();
}

Future<Harness> open(
  WidgetTester tester, {
  FakeEmployeeBackend? backend,
  FakeFaceLiveness? face,
  FakeQrScanner? scanner,
  LocationService? location,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = backend ?? FakeEmployeeBackend();
  final f = face ?? FakeFaceLiveness();
  final qr = scanner ?? FakeQrScanner();
  final storage = FakeTokenStorage(token: makeJwt(), fullName: 'Nguyễn Văn An');
  final t = buildTestApp(storage, fake.adapter, face: f, scanner: qr, location: location);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  return Harness(fake, storage, f, qr);
}

Future<void> tapCheck(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('checkin_button')));
  await settle(tester);
}

/// Backend chỉ còn 1 ca để luồng tự bắt đầu, không hiện danh sách chọn.
FakeEmployeeBackend oneShift() => FakeEmployeeBackend()..todayShifts = [FakeEmployeeBackend().todayShifts.first];

/// Đi hết 3 bước tới khi thấy kết quả: quét QR -> (tự lấy GPS) -> xác thực khuôn mặt.
Future<void> runFlow(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('fake_scan')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('fake_face_ok')));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Luồng chấm công vào ca: QR -> vị trí -> khuôn mặt', () {
    testWidgets('nhiều ca: chọn ca -> quét QR -> GPS -> khuôn mặt -> thành công, tab Hôm nay cập nhật', (tester) async {
      final h = await open(tester);
      await tapCheck(tester);
      expect(find.text('Chọn ca cần chấm công'), findsOneWidget);
      expect(find.textContaining('Chấm công VÀO ca'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('flow_pick_1')));
      await settle(tester);
      // bước 1: quét QR đầu tiên (chưa có vân tay/PIN)
      expect(find.text('Quét mã QR của ca'), findsOneWidget);
      expect(find.byKey(const Key('flow_stepbar')), findsOneWidget);
      expect(find.text('Quét QR'), findsOneWidget);
      expect(find.text('Khuôn mặt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fake_scan')));
      await settle(tester);
      // bước 3: GPS đã lấy xong, đang ở khuôn mặt
      expect(find.text('Xác thực khuôn mặt'), findsOneWidget);
      expect(find.textContaining('Đã lấy vị trí (21.02850, 105.85420)'), findsOneWidget);
      expect(h.checkRequests, isEmpty, reason: 'chưa gửi server cho tới khi xong khuôn mặt');

      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);
      expect(find.byKey(const Key('flow_success')), findsOneWidget);
      expect(find.text('Đã chấm công vào ca'), findsOneWidget);
      expect(find.text('Check-in thành công'), findsOneWidget);
      expect(find.text('Đã xác thực khuôn mặt'), findsOneWidget);

      final req = h.checkRequests.single;
      expect(req.path, '/api/Attendances/check-in');
      final body = req.data as Map;
      expect(body['qrToken'], 'token-sang');
      expect(body['latitude'], 21.0285);
      expect(body['isMocked'], false);
      expect(body['faceVerified'], true);
      expect(body['deviceId'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

      await tester.tap(find.byKey(const Key('flow_done')));
      await settle(tester);
      expect(find.byKey(const Key('flow_success')), findsNothing);
      expect(find.text('Đúng giờ'), findsOneWidget); // thẻ Ca sáng đã cập nhật
    });

    testWidgets('chỉ còn một ca chấm được: tự bắt đầu ở bước QR, bỏ qua bước chọn ca', (tester) async {
      await open(tester, backend: oneShift());
      await tapCheck(tester);
      expect(find.text('Chọn ca cần chấm công'), findsNothing);
      expect(find.text('Quét mã QR của ca'), findsOneWidget);
    });

    testWidgets('nhập nhầm/rỗng mã tay không đi tiếp; GPS lỗi -> ở bước vị trí kèm Thử lại, chưa mở camera mặt', (tester) async {
      final loc = FakeLocationService(error: const LocationException('Bạn chưa cấp quyền truy cập vị trí cho ứng dụng.'));
      final h = await open(tester, backend: oneShift(), location: loc);
      await tapCheck(tester);
      await tester.tap(find.byKey(const Key('flow_toggle_manual')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('flow_manual_submit')));
      await settle(tester);
      expect(find.text('Nhập mã ca'), findsOneWidget, reason: 'mã rỗng thì ở lại bước QR');

      await tester.enterText(field('flow_manual_field'), 'token-sang');
      await tester.tap(find.byKey(const Key('flow_manual_submit')));
      await settle(tester);
      expect(find.text('Bạn chưa cấp quyền truy cập vị trí cho ứng dụng.'), findsOneWidget);
      expect(h.face.builds, 0, reason: 'chưa có vị trí thì chưa tới bước khuôn mặt');
      // thử lại từ chính bước vị trí (không quét QR lại)
      loc.error = null;
      await tester.tap(find.byKey(const Key('flow_location_retry')));
      await settle(tester);
      expect(find.text('Xác thực khuôn mặt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);
      expect((h.checkRequests.single.data as Map)['qrToken'], 'token-sang');
    });

    testWidgets('GPS giả: cảnh báo ở bước khuôn mặt; server đánh dấu nghi ngờ và kết quả hiện lý do', (tester) async {
      final loc = FakeLocationService(reading: const LocationReading(21.0285, 105.8542, isMocked: true));
      final h = await open(tester, backend: oneShift(), location: loc);
      await tapCheck(tester);
      await tester.tap(find.byKey(const Key('fake_scan')));
      await settle(tester);
      expect(find.byKey(const Key('flow_mock_warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);
      expect((h.checkRequests.single.data as Map)['isMocked'], true);
      expect(find.text('Nghi ngờ'), findsOneWidget);
      expect(find.text('GPS giả (mock location)'), findsOneWidget);
    });

    testWidgets('nhập mã tay thay cho camera (có cắt khoảng trắng)', (tester) async {
      final h = await open(tester, backend: oneShift());
      await tapCheck(tester);
      await tester.tap(find.byKey(const Key('flow_toggle_manual')));
      await settle(tester);
      expect(find.text('Nhập mã ca'), findsOneWidget);
      expect(find.byKey(const Key('fake_scan')), findsNothing);
      await tester.enterText(field('flow_manual_field'), '  token-sang ');
      await tester.tap(find.byKey(const Key('flow_manual_submit')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);
      expect((h.checkRequests.single.data as Map)['qrToken'], 'token-sang');
      expect(find.byKey(const Key('flow_success')), findsOneWidget);
    });

    testWidgets('camera QR lỗi / từ chối quyền: tự chuyển sang nhập mã tay', (tester) async {
      final scanner = FakeQrScanner(errorMessage: 'Bạn chưa cấp quyền camera cho ứng dụng.');
      await open(tester, backend: oneShift(), scanner: scanner);
      await tapCheck(tester);
      expect(find.byKey(const Key('flow_scanner_error')), findsOneWidget);
      expect(find.textContaining('Bạn chưa cấp quyền camera cho ứng dụng. Hãy nhập mã tay.'), findsOneWidget);
      expect(find.byKey(const Key('flow_manual_field')), findsOneWidget);
    });
  });

  group('Bỏ qua khuôn mặt (demo) và thất bại', () {
    testWidgets('allowSkipFace bật (debug): có nút Bỏ qua; bỏ qua -> faceVerified=false, kết quả ghi "Chưa xác thực mặt", KHÔNG nghi ngờ', (tester) async {
      expect(AppConfig.allowSkipFace, true, reason: 'mặc định bật ở bản debug/test');
      final h = await open(tester, backend: oneShift());
      await tapCheck(tester);
      await tester.tap(find.byKey(const Key('fake_scan')));
      await settle(tester);
      expect(find.text('Bỏ qua (chỉ để demo)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('face_skip')));
      await settle(tester);
      expect((h.checkRequests.single.data as Map)['faceVerified'], false);
      expect(find.text('Chưa xác thực mặt'), findsOneWidget);
      expect(find.text('Đúng giờ'), findsOneWidget, reason: 'bỏ qua mặt không làm bản ghi thành nghi ngờ');
      expect(find.text('Nghi ngờ'), findsNothing);
    });

    testWidgets('QR sai: server từ chối -> Thử lại quay về bước QR (chưa có gì giữ lại), rồi chấm lại thành công', (tester) async {
      final scanner = FakeQrScanner(code: 'ma-sai');
      final h = await open(tester, backend: oneShift(), scanner: scanner);
      await tapCheck(tester);
      await runFlow(tester);
      expect(find.byKey(const Key('flow_failure')), findsOneWidget);
      expect(find.text('Mã QR không hợp lệ hoặc ca không còn hoạt động'), findsOneWidget);

      scanner.code = 'token-sang';
      await tester.tap(find.byKey(const Key('flow_retry')));
      await settle(tester);
      expect(find.text('Quét mã QR của ca'), findsOneWidget, reason: 'server từ chối thì làm lại từ bước QR');
      await runFlow(tester);
      expect(find.byKey(const Key('flow_success')), findsOneWidget);
      expect(h.checkRequests.length, 2);
    });

    testWidgets('ngoài bán kính: server từ chối, hiện khoảng cách', (tester) async {
      final loc = FakeLocationService(reading: const LocationReading(21.5, 105.8542));
      await open(tester, backend: oneShift(), location: loc);
      await tapCheck(tester);
      await runFlow(tester);
      expect(find.textContaining('vượt bán kính cho phép'), findsOneWidget);
      await tester.tap(find.byKey(const Key('flow_close')));
      await settle(tester);
      expect(find.byKey(const Key('flow_failure')), findsNothing);
      expect(find.byKey(const Key('checkin_button')), findsOneWidget);
    });

    testWidgets('đang nghỉ phép được duyệt: chooser có cảnh báo, check-in bị server từ chối kèm lý do', (tester) async {
      final fake = FakeEmployeeBackend()..onLeave = true;
      await open(tester, backend: fake);
      await tapCheck(tester);
      expect(find.textContaining('chỉ chấm công ra ca được'), findsOneWidget);
      await tester.tap(find.byKey(const Key('flow_pick_1')));
      await settle(tester);
      await runFlow(tester);
      expect(find.textContaining('đơn nghỉ phép đã được duyệt, không thể chấm công'), findsWidgets);
      expect(find.byKey(const Key('flow_failure')), findsOneWidget);
    });
  });

  group('Check-out và các trường hợp khác', () {
    testWidgets('đã vào ca chưa ra: tự suy ra là check-out, gửi faceVerified, kết quả có số giờ, lương, khuôn mặt', (tester) async {
      final fake = oneShift();
      fake.todayAttendance[1] = record(7, fake.now, open: true);
      final h = await open(tester, backend: fake);
      await tapCheck(tester);
      expect(find.text('Chấm công ra ca'), findsOneWidget); // tiêu đề AppBar
      await runFlow(tester);
      expect(h.checkRequests.single.path, '/api/Attendances/check-out');
      expect((h.checkRequests.single.data as Map)['faceVerified'], true);
      expect(find.text('Đã chấm công ra ca'), findsOneWidget);
      expect(find.text('Số giờ làm'), findsOneWidget);
      expect(find.text('Lương ca'), findsOneWidget);
      expect(find.text('Đã xác thực khuôn mặt'), findsOneWidget);
    });

    testWidgets('danh sách chọn ghi rõ VÀO/RA theo từng ca', (tester) async {
      final fake = FakeEmployeeBackend();
      fake.todayAttendance[1] = record(7, fake.now, open: true);
      await open(tester, backend: fake);
      await tapCheck(tester);
      expect(find.textContaining('Chấm công RA ca'), findsOneWidget);
      expect(find.textContaining('Chấm công VÀO ca'), findsOneWidget);
    });

    testWidgets('đã hoàn thành mọi ca: không có gì để chấm', (tester) async {
      final fake = FakeEmployeeBackend();
      fake.todayAttendance[1] = record(7, fake.now);
      fake.todayAttendance[2] = record(8, fake.now, shift: 'Ca chiều');
      await open(tester, backend: fake);
      await tapCheck(tester);
      expect(find.text('Không có ca nào cần chấm công'), findsOneWidget);
    });

    testWidgets('mã thiết bị: sinh một lần, dùng lại và còn nguyên sau khi đăng xuất', (tester) async {
      final fake = oneShift();
      final h = await open(tester, backend: fake);
      await tapCheck(tester);
      await runFlow(tester);
      final first = (h.checkRequests.single.data as Map)['deviceId'];
      expect(h.storage.deviceId, first);

      await h.storage.clear(); // như khi đăng xuất
      expect(h.storage.deviceId, first);
      expect(await DeviceIdService(h.storage).get(), first);
    });
  });

  group('DeviceIdService', () {
    test('UUID v4 hợp lệ, không trùng giữa các lần sinh', () {
      final s = DeviceIdService(FakeTokenStorage());
      final ids = {for (var i = 0; i < 50; i++) s.generate()};
      expect(ids.length, 50);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      }
    });

    test('đã có thì dùng lại, chưa có thì lưu', () async {
      final storage = FakeTokenStorage();
      final s = DeviceIdService(storage);
      final id = await s.get();
      expect(storage.deviceId, id);
      expect(await s.get(), id);
      expect(await DeviceIdService(FakeTokenStorage(deviceId: 'co-san')).get(), 'co-san');
    });
  });

  group('Không chấm 2 ca cùng lúc (ca đang mở còn trong giờ khóa các ca khác)', () {
    const endOfDay = '23:59:59.9999999';

    /// Ca A (00:00 - 24:00) đang mở + Ca B chồng giờ chưa chấm.
    FakeEmployeeBackend overlapping({String endA = endOfDay}) {
      final fake = FakeEmployeeBackend();
      fake.todayShifts = [
        {'id': 1, 'name': 'Ca A', 'startTime': '00:00:00', 'endTime': endA, 'lateGraceMinutes': 5},
        {'id': 2, 'name': 'Ca B', 'startTime': '06:00:00', 'endTime': '12:00:00', 'lateGraceMinutes': 5},
      ];
      fake.todayAttendance[1] = record(7, fake.now, open: true, shift: 'Ca A');
      return fake;
    }

    testWidgets('thẻ Hôm nay: ca khác mờ kèm "Đang trong Ca A chưa check-out"; ca đang mở hiện "24:00"', (tester) async {
      await open(tester, backend: overlapping());
      expect(find.text('Đang trong Ca A chưa check-out'), findsOneWidget);
      expect(find.text('00:00 - 24:00'), findsOneWidget);
    });

    testWidgets('màn chọn ca: chỉ ca đang mở chọn được (RA), ca khác khóa, bấm không bắt đầu luồng', (tester) async {
      await open(tester, backend: overlapping());
      await tapCheck(tester);
      expect(find.text('Chọn ca cần chấm công'), findsOneWidget);
      expect(find.textContaining('Đang trong Ca A chưa check-out'), findsWidgets);
      expect(find.textContaining('Chấm công RA ca'), findsOneWidget);
      await tester.tap(find.byKey(const Key('flow_pick_2')));
      await settle(tester);
      expect(find.text('Chọn ca cần chấm công'), findsOneWidget, reason: 'ca bị khóa không bắt đầu luồng');
      await tester.tap(find.byKey(const Key('flow_pick_1')));
      await settle(tester);
      expect(find.text('Chấm công ra ca'), findsOneWidget);
    });

    testWidgets('thẻ ca đang mở có nút "Check-out ca này": bấm vào là vào thẳng luồng RA ca của ca đó', (tester) async {
      final h = await open(tester, backend: overlapping());
      expect(find.byKey(const Key('today_checkout_1')), findsOneWidget);
      expect(find.byKey(const Key('today_checkout_2')), findsNothing, reason: 'ca chưa vào không có nút check-out');
      await tester.tap(find.byKey(const Key('today_checkout_1')));
      await settle(tester);
      expect(find.text('Chấm công ra ca'), findsOneWidget);
      expect(find.text('Chọn ca cần chấm công'), findsNothing, reason: 'đã chọn sẵn ca, không hiện danh sách');
      await runFlow(tester);
      expect(h.checkRequests.single.path, '/api/Attendances/check-out');
      expect(find.text('Đã chấm công ra ca'), findsOneWidget);
    });

    testWidgets('ca đã quá giờ mà quên check-out KHÔNG khóa ca khác', (tester) async {
      await open(tester, backend: overlapping(endA: '01:00:00'));
      expect(find.text('Đang trong Ca A chưa check-out'), findsNothing);
      await tapCheck(tester);
      expect(find.textContaining('Đang trong Ca A chưa check-out'), findsNothing);
      expect(find.textContaining('Chấm công VÀO ca'), findsOneWidget);
    });

    testWidgets('sau khi check-out ca A thì chấm ca B bình thường', (tester) async {
      final fake = overlapping();
      fake.todayAttendance[1]!['checkOutAt'] = '${isoDay(fake.now)}T05:00:00Z';
      await open(tester, backend: fake);
      expect(find.text('Đang trong Ca A chưa check-out'), findsNothing);
    });

    testWidgets('server từ chối (409) thì hiện đúng lời server và cho thử lại', (tester) async {
      final fake = FakeEmployeeBackend()..todayShifts = [FakeEmployeeBackend().todayShifts.first];
      final h = await open(tester, backend: fake);
      fake.adapter.interceptor = (o) => o.path.contains('/check-in')
          ? (status: 409, body: {'success': false, 'message': 'Bạn đang trong Ca gãy sáng chưa check-out. Hãy check-out ca đó trước khi chấm ca khác.'})
          : null;
      await tapCheck(tester);
      await runFlow(tester);
      expect(find.text('Bạn đang trong Ca gãy sáng chưa check-out. Hãy check-out ca đó trước khi chấm ca khác.'), findsOneWidget);
      expect(find.byKey(const Key('flow_retry')), findsOneWidget);
      expect(h.checkRequests.length, 1);
    });
  });
}
