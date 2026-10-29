/// Một ngày trong báo cáo tháng (dùng cho biểu đồ ở T9).
class DailyReportItem {
  final DateTime date;
  final double hours;
  final int lateMinutes;
  final double penalty;
  final double pay;
  final String status;

  const DailyReportItem({
    required this.date,
    required this.hours,
    required this.lateMinutes,
    required this.penalty,
    required this.pay,
    required this.status,
  });

  factory DailyReportItem.fromJson(Map<String, dynamic> json) => DailyReportItem(
        date: DateTime.parse(json['date'] as String),
        hours: ((json['hours'] ?? 0) as num).toDouble(),
        lateMinutes: (json['lateMinutes'] ?? 0) as int,
        penalty: ((json['penalty'] ?? 0) as num).toDouble(),
        pay: ((json['pay'] ?? 0) as num).toDouble(),
        status: (json['status'] ?? '') as String,
      );
}

/// Số liệu tháng của một nhân viên (lương tạm tính, phạt, số lần trễ...).
class MonthlySummary {
  final int userId;
  final String fullName;
  final double hourlyRate;
  final int daysWorked;
  final int openCount; // bản ghi chưa check-out (chưa tính lương)
  final double totalHours;
  final int lateCount;
  final int totalLateMinutes;
  final double totalPenalty;
  final double grossPay;
  final double netPay;
  final int suspiciousCount;
  final double suspiciousPay;
  final int leaveDays;
  final List<DailyReportItem> days;

  const MonthlySummary({
    this.userId = 0,
    this.fullName = '',
    this.hourlyRate = 0,
    this.daysWorked = 0,
    this.openCount = 0,
    this.totalHours = 0,
    this.lateCount = 0,
    this.totalLateMinutes = 0,
    this.totalPenalty = 0,
    this.grossPay = 0,
    this.netPay = 0,
    this.suspiciousCount = 0,
    this.suspiciousPay = 0,
    this.leaveDays = 0,
    this.days = const [],
  });

  static double _d(dynamic v) => ((v ?? 0) as num).toDouble();

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
        userId: (json['userId'] ?? 0) as int,
        fullName: (json['fullName'] ?? '') as String,
        hourlyRate: _d(json['hourlyRate']),
        daysWorked: (json['daysWorked'] ?? 0) as int,
        openCount: (json['openCount'] ?? 0) as int,
        totalHours: _d(json['totalHours']),
        lateCount: (json['lateCount'] ?? 0) as int,
        totalLateMinutes: (json['totalLateMinutes'] ?? 0) as int,
        totalPenalty: _d(json['totalPenalty']),
        grossPay: _d(json['grossPay']),
        netPay: _d(json['netPay']),
        suspiciousCount: (json['suspiciousCount'] ?? 0) as int,
        suspiciousPay: _d(json['suspiciousPay']),
        leaveDays: (json['leaveDays'] ?? 0) as int,
        days: ((json['days'] ?? const []) as List)
            .map((e) => DailyReportItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Báo cáo tháng của mọi nhân viên (GET /api/Reports/monthly).
class MonthlyReport {
  final String month; // yyyy-MM
  final List<MonthlySummary> rows;
  final double totalHours;
  final double totalPenalty;
  final double totalNetPay;
  final double totalGrossPay;
  final int totalSuspicious;
  final double totalSuspiciousPay; // tiền lương đến từ bản ghi đang bị nghi ngờ

  const MonthlyReport({
    this.month = '',
    this.rows = const [],
    this.totalHours = 0,
    this.totalPenalty = 0,
    this.totalNetPay = 0,
    this.totalGrossPay = 0,
    this.totalSuspicious = 0,
    this.totalSuspiciousPay = 0,
  });

  static double _d(dynamic v) => ((v ?? 0) as num).toDouble();

  factory MonthlyReport.fromJson(Map<String, dynamic> json) => MonthlyReport(
        month: (json['month'] ?? '') as String,
        rows: ((json['rows'] ?? const []) as List).map((e) => MonthlySummary.fromJson(e as Map<String, dynamic>)).toList(),
        totalHours: _d(json['totalHours']),
        totalPenalty: _d(json['totalPenalty']),
        totalNetPay: _d(json['totalNetPay']),
        totalGrossPay: _d(json['totalGrossPay']),
        totalSuspicious: (json['totalSuspicious'] ?? 0) as int,
        totalSuspiciousPay: _d(json['totalSuspiciousPay']),
      );
}
