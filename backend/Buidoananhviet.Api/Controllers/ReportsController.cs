using System.Globalization;
using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

[Authorize]
[Route("api/[controller]")]
[ApiController]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;
    private readonly ITimeService _time;
    private readonly ILogger<ReportsController> _logger;

    public ReportsController(IReportService reportService, ITimeService time, ILogger<ReportsController> logger)
    {
        _reportService = reportService;
        _time = time;
        _logger = logger;
    }

    // month = yyyy-MM, bỏ trống thì lấy tháng hiện tại
    private bool TryParseMonth(string? month, out int year, out int mon)
    {
        var now = _time.LocalNow;
        year = now.Year;
        mon = now.Month;
        if (string.IsNullOrWhiteSpace(month)) return true;
        if (!DateTime.TryParseExact(month, "yyyy-MM", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
            return false;
        year = d.Year;
        mon = d.Month;
        return true;
    }

    // Admin: báo cáo tháng của mọi nhân viên
    [Authorize(Roles = Roles.Admin)]
    [HttpGet("monthly")]
    public async Task<IActionResult> GetMonthly([FromQuery] string? month)
    {
        try
        {
            if (!TryParseMonth(month, out var year, out var mon))
                return BadRequest(new { success = false, message = "month phải có dạng yyyy-MM" });
            return Ok(await _reportService.GetMonthlyAsync(year, mon, null));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetMonthly lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Admin: báo cáo tháng của 1 nhân viên (kèm chi tiết từng ngày)
    [Authorize(Roles = Roles.Admin)]
    [HttpGet("monthly/{userId:int}")]
    public async Task<IActionResult> GetMonthlyForUser(int userId, [FromQuery] string? month)
    {
        try
        {
            if (!TryParseMonth(month, out var year, out var mon))
                return BadRequest(new { success = false, message = "month phải có dạng yyyy-MM" });
            var report = await _reportService.GetMonthlyAsync(year, mon, userId);
            if (report.Rows.Count == 0)
                return NotFound();
            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetMonthlyForUser lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Nhân viên: lương tạm tính + chi tiết từng ngày của chính mình
    [Authorize(Roles = Roles.Employee)]
    [HttpGet("my-monthly")]
    public async Task<IActionResult> GetMyMonthly([FromQuery] string? month)
    {
        try
        {
            if (!TryParseMonth(month, out var year, out var mon))
                return BadRequest(new { success = false, message = "month phải có dạng yyyy-MM" });
            var report = await _reportService.GetMonthlyAsync(year, mon, User.GetUserId());
            if (report.Rows.Count == 0)
                return NotFound();
            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetMyMonthly lỗi");
            return StatusCode(500, "Internal server error");
        }
    }
}
