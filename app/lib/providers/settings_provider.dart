import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import 'auth_provider.dart';

/// Các mức cỡ chữ cho người dùng chọn (nhãn, hệ số).
const List<(String, double)> fontScaleOptions = [
  ('Nhỏ', 0.9),
  ('Vừa', 1.0),
  ('Lớn', 1.15),
  ('Rất lớn', 1.3),
];

/// Cài đặt giao diện cá nhân. Mặc định = giao diện gốc của ứng dụng.
class AppPrefs {
  final double fontScale;
  final ThemeMode themeMode;
  final int accent; // chỉ số trong AppPalettes.accents
  final int background; // chỉ số trong AppPalettes.backgrounds

  const AppPrefs({this.fontScale = 1.0, this.themeMode = ThemeMode.system, this.accent = 0, this.background = 0});

  static const AppPrefs defaults = AppPrefs();

  bool get isDefault => fontScale == 1.0 && themeMode == ThemeMode.system && accent == 0 && background == 0;

  AppPrefs copyWith({double? fontScale, ThemeMode? themeMode, int? accent, int? background}) => AppPrefs(
        fontScale: fontScale ?? this.fontScale,
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        background: background ?? this.background,
      );

  Map<String, dynamic> toJson() => {'fontScale': fontScale, 'themeMode': themeMode.name, 'accent': accent, 'background': background};

  /// Đọc JSON; giá trị lạ/hỏng thì dùng mặc định (không bao giờ ném lỗi).
  factory AppPrefs.fromJson(Map<String, dynamic> json) {
    final scale = (json['fontScale'] as num?)?.toDouble() ?? 1.0;
    final allowed = fontScaleOptions.map((o) => o.$2);
    return AppPrefs(
      fontScale: allowed.contains(scale) ? scale : 1.0,
      themeMode: ThemeMode.values.firstWhere((m) => m.name == json['themeMode'], orElse: () => ThemeMode.system),
      accent: (json['accent'] as int?)?.clamp(0, 5) ?? 0,
      background: (json['background'] as int?)?.clamp(0, 4) ?? 0,
    );
  }
}

/// Cài đặt cá nhân theo từng tài khoản, chỉ lưu trên máy (secure storage, khóa `prefs_<userId>`).
/// Chưa đăng nhập thì dùng mặc định. Gắn với AuthProvider để tự nạp khi đổi tài khoản.
class SettingsProvider extends ChangeNotifier {
  final TokenStorage _storage;
  AppPrefs prefs = AppPrefs.defaults;
  int? _userId;

  SettingsProvider(this._storage);

  static String keyFor(int userId) => 'prefs_$userId';

  /// Theo dõi AuthProvider: đổi tài khoản (hoặc đăng xuất) thì nạp lại cài đặt tương ứng.
  void bindAuth(AuthProvider auth) {
    _activate(auth.session?.userId);
    auth.addListener(() {
      final id = auth.session?.userId;
      if (id != _userId) _activate(id);
    });
  }

  Future<void> _activate(int? userId) async {
    _userId = userId;
    var loaded = AppPrefs.defaults;
    if (userId != null) {
      try {
        final raw = await _storage.readValue(keyFor(userId));
        if (raw != null) loaded = AppPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        loaded = AppPrefs.defaults; // dữ liệu hỏng -> mặc định
      }
    }
    if (_userId != userId) return; // đã đổi tài khoản trong lúc đọc
    prefs = loaded;
    notifyListeners();
  }

  Future<void> _set(AppPrefs next) async {
    prefs = next;
    notifyListeners();
    final id = _userId;
    if (id != null) await _storage.writeValue(keyFor(id), jsonEncode(next.toJson()));
  }

  Future<void> setFontScale(double v) => _set(prefs.copyWith(fontScale: v));
  Future<void> setThemeMode(ThemeMode m) => _set(prefs.copyWith(themeMode: m));
  Future<void> setAccent(int i) => _set(prefs.copyWith(accent: i));
  Future<void> setBackground(int i) => _set(prefs.copyWith(background: i));

  /// Khôi phục mặc định (xóa cài đặt đã lưu của tài khoản này).
  Future<void> reset() async {
    prefs = AppPrefs.defaults;
    notifyListeners();
    final id = _userId;
    if (id != null) await _storage.deleteValue(keyFor(id));
  }
}
