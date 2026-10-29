import 'package:flutter/material.dart';

/// Thanh chọn tháng với mũi tên trước/sau. Dùng cho lịch sử của nhân viên và báo cáo của admin.
class MonthBar extends StatelessWidget {
  final DateTime month;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const MonthBar({
    super.key,
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('month_prev'),
            tooltip: 'Tháng trước',
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            onPressed: canGoPrev ? onPrev : null,
          ),
          SizedBox(
            width: 190,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Tháng ${month.month}/${month.year}',
                key: const Key('month_title'),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            key: const Key('month_next'),
            tooltip: 'Tháng sau',
            icon: const Icon(Icons.chevron_right_rounded, size: 30),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}
