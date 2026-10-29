import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Logo thương hiệu TimeGuard (vẽ bằng icon, không cần ảnh/package): khiên + đồng hồ trên nền squircle gradient.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TimeGuard',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandDeep, AppColors.brandLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: size > 48 ? 1.5 : 1),
            boxShadow: [
              BoxShadow(color: AppColors.brandDeep.withValues(alpha: 0.35), blurRadius: size * 0.3, offset: Offset(0, size * 0.12)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.shield_rounded, size: size * 0.66, color: Colors.white.withValues(alpha: 0.96)),
              Icon(Icons.schedule_rounded, size: size * 0.32, color: AppColors.brandMid),
            ],
          ),
        ),
      ),
    );
  }
}
