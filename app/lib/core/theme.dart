import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Khoảng cách dùng chung (đơn vị dp).
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Bo góc dùng chung.
class AppRadius {
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

/// Bảng màu slate (sáng/tối) ở MỘT chỗ.
class AppColors {
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF3B82F6);

  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF090D16);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF111827);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color fieldLight = Color(0xFFF1F5F9);
  static const Color fieldDark = Color(0xFF1E293B);
  static const Color mutedLight = Color(0xFF64748B);
  static const Color mutedDark = Color(0xFF94A3B8);

  /// Gradient thương hiệu (logo, thẻ chào).
  static const Color brandDeep = Color(0xFF1E40AF);
  static const Color brandMid = Color(0xFF2563EB);
  static const Color brandLight = Color(0xFF3B82F6);
}

/// Kiểu chữ bổ sung.
class AppTypography {
  static const String family = 'BeVietnamPro';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Số lớn đậm (giờ, tiền, thống kê) dùng chữ số đều nhau.
  static TextStyle metric(BuildContext context, {double size = 20, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
    color: color ?? Theme.of(context).colorScheme.onSurface,
    height: 1.2,
  );

  /// Dòng phụ (chú thích, nhãn nhỏ).
  static TextStyle subtitle(BuildContext context, {double size = 13}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35);
}

/// Theme thống nhất (Material 3), màu chủ đạo xanh dương #2563EB, tự đổi sáng/tối theo hệ thống.
class AppTheme {
  static const Color seed = AppColors.primaryLight;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = base.copyWith(
      primary: dark ? AppColors.primaryDark : AppColors.primaryLight,
      surface: dark ? AppColors.bgDark : AppColors.bgLight,
      surfaceContainerLowest: dark ? AppColors.bgDark : AppColors.bgLight,
      surfaceContainerLow: dark ? AppColors.cardDark : AppColors.cardLight,
      surfaceContainer: dark ? AppColors.cardDark : AppColors.cardLight,
      surfaceContainerHighest: dark ? AppColors.fieldDark : AppColors.fieldLight,
      outlineVariant: dark ? AppColors.borderDark : AppColors.borderLight,
      onSurfaceVariant: dark ? AppColors.mutedDark : AppColors.mutedLight,
    );
    final radius = BorderRadius.circular(AppRadius.md);

    final baseTheme = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: AppTypography.family);
    final text = baseTheme.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
          titleSmall: baseTheme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.family,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      // Chuyển trang mờ dần nhẹ nhàng, giống nhau trên mọi nền tảng
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: const FadeForwardsPageTransitionsBuilder()},
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(fontFamily: AppTypography.family, color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: AppTypography.family, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontFamily: AppTypography.family, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontFamily: AppTypography.family, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: AppTypography.family, fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: TextStyle(fontFamily: AppTypography.family, fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(fontFamily: AppTypography.family, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.25 : 0.14),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(fontFamily: AppTypography.family, fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    );
  }
}

/// Màu theo trạng thái chấm công / nghỉ phép, dùng thống nhất ở mọi màn hình.
/// [of] = màu gốc (chấm, viền, icon, cột biểu đồ); [textOf] = bản đủ tương phản (>= 4.5:1) cho CHỮ.
class StatusColors {
  static Color of(BuildContext context, String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'on-time':
      case 'approved':
        return dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case 'late':
      case 'pending':
        return dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case 'suspicious':
      case 'rejected':
        return dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  /// Bản màu cho chữ: sáng = làm đậm ~35% đen; tối = giữ bản sáng.
  static Color textColor(BuildContext context, Color color) => onTint(Theme.of(context).brightness, color);

  static Color onTint(Brightness brightness, Color color) =>
      brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.12)! : Color.lerp(color, Colors.black, 0.35)!;

  static Color textOf(BuildContext context, String status) {
    switch (status) {
      case 'on-time':
      case 'approved':
      case 'late':
      case 'pending':
      case 'suspicious':
      case 'rejected':
        return textColor(context, of(context, status));
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  /// Màu cột biểu đồ theo trạng thái ở MỘT chỗ: bình thường = primary, đi trễ = cảnh báo, nghi ngờ = nguy hiểm.
  static Color barColorFor(BuildContext context, String status) {
    if (status == 'late') return of(context, 'late');
    if (status == 'suspicious') return of(context, 'suspicious');
    return Theme.of(context).colorScheme.primary;
  }

  /// Nhãn tiếng Việt của trạng thái.
  static String label(String status) {
    switch (status) {
      case 'on-time':
        return 'Đúng giờ';
      case 'late':
        return 'Đi trễ';
      case 'suspicious':
        return 'Nghi ngờ';
      case 'pending':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }
}

/// Nhãn vai trò, ánh xạ ở MỘT chỗ.
String roleLabel(String role) => role == 'admin' ? 'Quản trị viên' : 'Nhân viên';

/// Chữ cái đầu của TỪ CUỐI trong họ tên (tên riêng); rỗng thì "?".
String avatarInitial(String fullName) {
  final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return words.last.characters.first.toUpperCase();
}
