namespace Buidoananhviet.Api.Models;

// Một dòng báo cáo tháng của một nhân viên
public class MonthlyReportRow
{
    public int UserId { get; set; }
    public string FullName { get; set; } = "";
    public decimal HourlyRate { get; set; }
    public int DaysWorked { get; set; }          // Số bản ghi đã check-out
    public int OpenCount { get; set; }           // Bản ghi chưa check-out (không tính lương)
    public decimal TotalHours { get; set; }
    public int LateCount { get; set; }
    public int TotalLateMinutes { get; set; }
    public decimal TotalPenalty { get; set; }
    public decimal GrossPay { get; set; }        // Trước phạt
    public decimal NetPay { get; set; }          // Sau phạt (đã gồm cả bản ghi suspicious)
    public int SuspiciousCount { get; set; }
    public decimal SuspiciousPay { get; set; }   // Phần NetPay đến từ bản ghi suspicious
    public int LeaveDays { get; set; }           // Số ngày nghỉ đã duyệt rơi vào tháng
    public List<DailyReportItem>? Days { get; set; }   // Chỉ có khi xem 1 nhân viên
}

public class DailyReportItem
{
    public DateTime Date { get; set; }
    public decimal Hours { get; set; }
    public int LateMinutes { get; set; }
    public decimal Penalty { get; set; }
    public decimal Pay { get; set; }
    public string Status { get; set; } = "";
}

public class MonthlyReport
{
    public string Month { get; set; } = "";      // yyyy-MM
    public List<MonthlyReportRow> Rows { get; set; } = new();
    public decimal TotalHours { get; set; }
    public decimal TotalPenalty { get; set; }
    public decimal TotalNetPay { get; set; }
    public int TotalSuspicious { get; set; }
    public decimal TotalGrossPay { get; set; }
    public decimal TotalSuspiciousPay { get; set; }   // Tiền lương đến từ bản ghi đang bị nghi ngờ
}
