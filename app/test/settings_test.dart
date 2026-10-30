import 'package:buidoananhviet/core/theme.dart';
import 'package:buidoananhviet/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_employee_backend.dart';
import 'helpers.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeTokenStorage> openApp(WidgetTester tester, {FakeTokenStorage? storage, int userId = 2}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = FakeEmployeeBackend();
  final s = storage ?? FakeTokenStorage(token: makeJwt(userId: userId), fullName: 'Nguyễn Văn An');
  final t = buildTestApp(s, fake.adapter);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  return s;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Hồ sơ')));
  await settle(tester);
  await tester.ensureVisible(find.byKey(const Key('profile_settings')));
  await tester.tap(find.byKey(const Key('profile_settings')));
  await settle(tester);
}

BuildContext ctx(WidgetTester tester, Finder f) => tester.element(f);

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('AppPrefs', () {
    test('mặc định + JSON hai chiều; giá trị lạ/hỏng quay về mặc định', () {
      expect(AppPrefs.defaults.isDefault, true);
      const p = AppPrefs(fontScale: 1.15, themeMode: ThemeMode.dark, accent: 3, background: 2);
      final back = AppPrefs.fromJson(p.toJson());
      expect((back.fontScale, back.themeMode, back.accent, back.background), (1.15, ThemeMode.dark, 3, 2));
      final bad = AppPrefs.fromJson({'fontScale': 7.0, 'themeMode': 'neon', 'accent': 99, 'background': -4});
      expect(bad.fontScale, 1.0);
      expect(bad.themeMode, ThemeMode.system);
      expect(bad.accent, 5);
      expect(bad.background, 0);
    });
  });

  group('Theme', () {
    test('mặc định giống hệt giao diện gốc', () {
      final l = AppTheme.build(Brightness.light);
      final d = AppTheme.build(Brightness.dark);
      expect(l.colorScheme.primary, AppColors.primaryLight);
      expect(l.scaffoldBackgroundColor, AppColors.bgLight);
      expect(d.colorScheme.primary, AppColors.primaryDark);
      expect(d.scaffoldBackgroundColor, AppColors.bgDark);
      expect(AppTheme.light.colorScheme.primary, l.colorScheme.primary);
    });

    test('mọi tông nền: chữ chính >= 4,5:1 và chữ phụ >= 4,5:1 trên nền (sáng và tối)', () {
      for (var i = 0; i < AppPalettes.backgrounds.length; i++) {
        for (final b in Brightness.values) {
          final t = AppTheme.build(b, background: i);
          final bg = t.scaffoldBackgroundColor;
          expect(contrast(t.colorScheme.onSurface, bg), greaterThanOrEqualTo(4.5), reason: 'nền $i $b onSurface');
          expect(contrast(t.colorScheme.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5), reason: 'nền $i $b chữ phụ');
        }
      }
    });

    test('mọi màu chủ đạo (trừ mặc định): chữ trên nút primary >= 4,5:1; màu trên nền >= 3:1', () {
      for (var i = 1; i < AppPalettes.accents.length; i++) {
        for (final b in Brightness.values) {
          final t = AppTheme.build(b, accent: i);
          expect(contrast(t.colorScheme.onPrimary, t.colorScheme.primary), greaterThanOrEqualTo(4.5), reason: 'accent $i $b');
          expect(contrast(t.colorScheme.primary, t.scaffoldBackgroundColor), greaterThanOrEqualTo(3.0), reason: 'accent $i $b trên nền');
        }
      }
    });
  });

  group('Màn Cài đặt', () {
    testWidgets('mặc định: nút Khôi phục bị tắt; cỡ chữ Vừa; giao diện hệ thống', (tester) async {
      await openApp(tester);
      await openSettings(tester);
      expect(find.text('Cài đặt'), findsWidgets);
      final reset = tester.widget<OutlinedButton>(find.byKey(const Key('settings_reset')));
      expect(reset.onPressed, isNull);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.system);
      expect(ctx(tester, find.byKey(const Key('settings_preview'))).findAncestorWidgetOfExactType<MediaQuery>()!.data.textScaler.scale(1), 1.0);
    });

    testWidgets('đổi cỡ chữ áp dụng ngay cho cả ứng dụng và lưu theo userId', (tester) async {
      final storage = await openApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_font_3')));
      await settle(tester);
      final scaler = MediaQuery.of(ctx(tester, find.byKey(const Key('settings_preview')))).textScaler;
      expect(scaler.scale(1), closeTo(1.3, 0.001));
      expect(storage.values['prefs_2'], contains('1.3'));
    });

    testWidgets('chế độ tối + màu chủ đạo + tông nền đổi theme thật', (tester) async {
      await openApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_mode_dark')));
      await settle(tester);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('settings_accent_2')));
      await settle(tester);
      expect(Theme.of(ctx(tester, find.byKey(const Key('settings_preview')))).colorScheme.primary, AppPalettes.accents[2].dark);

      await tester.tap(find.byKey(const Key('settings_bg_1')));
      await settle(tester);
      expect(Theme.of(ctx(tester, find.byKey(const Key('settings_preview')))).scaffoldBackgroundColor, AppPalettes.backgrounds[1].dark);
    });

    testWidgets('Khôi phục mặc định đưa mọi thứ về gốc và xóa bản lưu', (tester) async {
      final storage = await openApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_font_2')));
      await tester.tap(find.byKey(const Key('settings_accent_4')));
      await settle(tester);
      expect(storage.values.containsKey('prefs_2'), true);
      await tester.tap(find.byKey(const Key('settings_reset')));
      await settle(tester);
      expect(storage.values.containsKey('prefs_2'), false);
      expect(Theme.of(ctx(tester, find.byKey(const Key('settings_preview')))).colorScheme.primary, AppColors.primaryLight);
      expect(MediaQuery.of(ctx(tester, find.byKey(const Key('settings_preview')))).textScaler.scale(1), 1.0);
    });

    testWidgets('cài đặt còn nguyên khi mở lại ứng dụng; tài khoản khác không bị ảnh hưởng', (tester) async {
      final storage = await openApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_font_0')));
      await tester.tap(find.byKey(const Key('settings_accent_1')));
      await settle(tester);

      // mở lại với cùng kho lưu: cài đặt được nạp
      await tester.pumpWidget(const SizedBox());
      await openApp(tester, storage: storage);
      await openSettings(tester);
      expect(MediaQuery.of(ctx(tester, find.byKey(const Key('settings_preview')))).textScaler.scale(1), closeTo(0.9, 0.001));
      expect(Theme.of(ctx(tester, find.byKey(const Key('settings_preview')))).colorScheme.primary, AppPalettes.accents[1].light);

      // tài khoản khác (userId 7) dùng mặc định
      await tester.pumpWidget(const SizedBox());
      final other = FakeTokenStorage(token: makeJwt(userId: 7), fullName: 'Người khác')..values.addAll(storage.values);
      await openApp(tester, storage: other);
      await openSettings(tester);
      expect(Theme.of(ctx(tester, find.byKey(const Key('settings_preview')))).colorScheme.primary, AppColors.primaryLight);
    });

    testWidgets('không tràn ở cỡ chữ lớn nhất trên màn hẹp', (tester) async {
      await openApp(tester);
      await openSettings(tester);
      tester.view.physicalSize = const Size(360, 780);
      await tester.tap(find.byKey(const Key('settings_font_3')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
