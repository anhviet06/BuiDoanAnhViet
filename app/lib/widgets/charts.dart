import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/monthly_report.dart';

double _niceInterval(double raw) {
  if (raw <= 0) return 1;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / magnitude;
  final nice = n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10));
  return nice * magnitude;
}

/// Một cột của biểu đồ cột.
class BarPoint {
  final String label; // nhãn dưới trục X
  final double value;
  final Color? color;
  final String tooltip; // nội dung khi chạm vào cột

  const BarPoint({required this.label, required this.value, required this.tooltip, this.color});
}

/// Biểu đồ cột đơn giản dùng chung (lương theo nhân viên, giờ theo nhân viên, giờ theo ngày).
/// Tự cuộn ngang khi có nhiều cột; khi không có dữ liệu thì hiện dòng thông báo.
class SimpleBarChart extends StatelessWidget {
  final List<BarPoint> bars;
  final String Function(double) axisFormatter;
  final double height;
  final double barWidth;
  final double slotWidth; // bề rộng tối thiểu cho mỗi cột (để cuộn ngang)
  final bool Function(int index)? showLabel;

  /// Khi nội dung rộng hơn màn hình: bắt đầu ở cuối (phần mới nhất) thay vì đầu.
  final bool startAtEnd;

  /// Chạm vào một cột (ví dụ mở chi tiết nhân viên).
  final void Function(int index)? onBarTap;

  const SimpleBarChart({
    super.key,
    required this.bars,
    required this.axisFormatter,
    this.height = 200,
    this.barWidth = 18,
    this.slotWidth = 52,
    this.showLabel,
    this.startAtEnd = false,
    this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    if (bars.isEmpty || maxValue <= 0) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Chưa có dữ liệu để vẽ biểu đồ', style: TextStyle(color: scheme.onSurfaceVariant))),
      );
    }
    // Khoảng chia "đẹp" (1, 2, 5 x 10^n) để nhãn trục tròn số, không xuống dòng
    final interval = _niceInterval(maxValue * 1.1 / 4);
    final maxY = interval * math.max(1, (maxValue * 1.05 / interval).ceil());
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = math.max(c.maxWidth, bars.length * slotWidth + 48);
          final chart = BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1, dashArray: const [6, 4]),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value > meta.max - interval / 100 && value != 0 && value == meta.max) return const SizedBox.shrink();
                      return SideTitleWidget(meta: meta, child: Text(axisFormatter(value), style: labelStyle));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= bars.length || (showLabel != null && !showLabel!(i))) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(bars[i].label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (onBarTap == null || event is! FlTapUpEvent) return;
                  final spot = response?.spot;
                  if (spot != null) onBarTap!(spot.touchedBarGroupIndex);
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(10),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    bars[group.x].tooltip,
                    TextStyle(
                      fontFamily: AppTypography.family,
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bars[i].value,
                        width: barWidth,
                        color: bars[i].color ?? scheme.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: scheme.surfaceContainerHighest.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
              ],
            ),
          );
          return width > c.maxWidth
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: startAtEnd, child: SizedBox(width: width, height: height, child: chart))
              : chart;
        },
      ),
    );
  }
}

/// Biểu đồ giờ làm theo ngày trong tháng. Cột đỏ = ngày có ca nghi ngờ, vàng = có đi trễ.
class HoursByDayChart extends StatelessWidget {
  final List<DailyReportItem> days;
  final DateTime month;

  const HoursByDayChart({super.key, required this.days, required this.month});

  /// Gom các bản ghi cùng ngày thành một cột (giờ cộng dồn, trạng thái xấu nhất).
  static List<BarPoint> buildBars(BuildContext context, List<DailyReportItem> days, DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    final hours = List<double>.filled(last + 1, 0);
    final worst = List<String>.filled(last + 1, '');
    int rank(String s) => s == 'suspicious' ? 3 : (s == 'late' ? 2 : (s.isEmpty ? 0 : 1));
    for (final d in days) {
      if (d.date.year != month.year || d.date.month != month.month) continue;
      hours[d.date.day] += d.hours;
      if (rank(d.status) > rank(worst[d.date.day])) worst[d.date.day] = d.status;
    }
    return [
      for (var day = 1; day <= last; day++)
        BarPoint(
          label: '$day',
          value: hours[day],
          color: worst[day].isEmpty || worst[day] == 'on-time' ? null : StatusColors.barColorFor(context, worst[day]),
          tooltip: 'Ngày $day/${month.month}: ${Fmt.hours(hours[day])}${worst[day].isEmpty ? '' : ' · ${StatusColors.label(worst[day])}'}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chart(context),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [
          dot(scheme.primary, 'Bình thường'),
          dot(StatusColors.barColorFor(context, 'late'), 'Đi trễ'),
          dot(StatusColors.barColorFor(context, 'suspicious'), 'Nghi ngờ'),
        ]),
      ],
    );
  }

  Widget _chart(BuildContext context) {
    return SimpleBarChart(
      bars: buildBars(context, days, month),
      axisFormatter: (v) => NumberFormatShort.hours(v),
      barWidth: 6,
      slotWidth: 9, // 31 ngày vừa một màn hình điện thoại thường
      startAtEnd: true,
      showLabel: (i) => (i + 1) == 1 || (i + 1) % 5 == 0,
    );
  }
}

/// Định dạng ngắn cho trục giờ.
class NumberFormatShort {
  static String hours(double v) => v == v.roundToDouble() ? '${v.round()}h' : '${v.toStringAsFixed(1)}h';
}
