using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;

namespace Buidoananhviet.Api.Services;

public interface IReportService
{
    /// <summary>Báo cáo tháng; userId = null -> mọi nhân viên (role employee).</summary>
    Task<MonthlyReport> GetMonthlyAsync(int year, int month, int? userId);
}

public class ReportService : IReportService
{
    private readonly IUserRepository _users;
    private readonly IAttendanceRepository _attendances;
    private readonly ILeaveRepository _leaves;

    public ReportService(IUserRepository users, IAttendanceRepository attendances, ILeaveRepository leaves)
    {
        _users = users;
        _attendances = attendances;
        _leaves = leaves;
    }

    public async Task<MonthlyReport> GetMonthlyAsync(int year, int month, int? userId)
    {
        var first = new DateTime(year, month, 1);
        var last = first.AddMonths(1).AddDays(-1);

        var users = (await _users.GetUsersAsync())
            .Where(u => userId != null ? u.Id == userId : u.Role == Roles.Employee)
            .OrderBy(u => u.FullName)
            .ToList();
        var attendances = (await _attendances.GetAttendancesAsync(userId, first, last, null)).ToList();
        var leaves = (await _leaves.GetLeavesAsync(userId, LeaveStatus.Approved)).ToList();

        var report = new MonthlyReport { Month = first.ToString("yyyy-MM") };
        foreach (var user in users)
        {
            var mine = attendances.Where(a => a.UserId == user.Id).ToList();
            // Chỉ bản ghi đã check-out mới có giờ làm / lương
            var done = mine.Where(a => a.CheckOutAt != null).ToList();
            var suspicious = done.Where(a => a.Status == AttendanceStatus.Suspicious).ToList();

            var row = new MonthlyReportRow
            {
                UserId = user.Id,
                FullName = user.FullName,
                HourlyRate = user.HourlyRate,
                DaysWorked = done.Count,
                OpenCount = mine.Count - done.Count,
                TotalHours = done.Sum(a => a.WorkedHours),
                LateCount = mine.Count(a => a.LateMinutes > 0),
                TotalLateMinutes = mine.Sum(a => a.LateMinutes),
                TotalPenalty = done.Sum(a => a.LatePenalty),
                GrossPay = done.Sum(a => a.GrossPay),
                NetPay = done.Sum(a => a.Pay),
                SuspiciousCount = mine.Count(a => a.Status == AttendanceStatus.Suspicious),
                SuspiciousPay = suspicious.Sum(a => a.Pay),
                LeaveDays = leaves.Where(l => l.UserId == user.Id).Sum(l => OverlapDays(l, first, last))
            };
            if (userId != null)
            {
                row.Days = mine.OrderBy(a => a.WorkDate).ThenBy(a => a.CheckInAt).Select(a => new DailyReportItem
                {
                    Date = a.WorkDate,
                    Hours = a.WorkedHours,
                    LateMinutes = a.LateMinutes,
                    Penalty = a.LatePenalty,
                    Pay = a.Pay,
                    Status = a.Status
                }).ToList();
            }
            report.Rows.Add(row);
        }

        report.TotalHours = report.Rows.Sum(r => r.TotalHours);
        report.TotalPenalty = report.Rows.Sum(r => r.TotalPenalty);
        report.TotalNetPay = report.Rows.Sum(r => r.NetPay);
        report.TotalSuspicious = report.Rows.Sum(r => r.SuspiciousCount);
        report.TotalGrossPay = report.Rows.Sum(r => r.GrossPay);
        report.TotalSuspiciousPay = report.Rows.Sum(r => r.SuspiciousPay);
        return report;
    }

    private static int OverlapDays(Leave leave, DateTime first, DateTime last)
    {
        var from = leave.FromDate.Date > first ? leave.FromDate.Date : first;
        var to = leave.ToDate.Date < last ? leave.ToDate.Date : last;
        return to >= from ? (to - from).Days + 1 : 0;
    }
}
