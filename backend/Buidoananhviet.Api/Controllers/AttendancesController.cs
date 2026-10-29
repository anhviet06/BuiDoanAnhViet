using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

// Nhân viên: check-in/out, xem hôm nay và lịch sử của mình.
// Admin: xem toàn bộ chấm công (lọc theo nhân viên/ngày/trạng thái).
[Authorize]
[Route("api/[controller]")]
[ApiController]
public class AttendancesController : ControllerBase
{
    private readonly IAttendanceService _attendanceService;
    private readonly IAttendanceRepository _attendanceRepository;
    private readonly IShiftRepository _shiftRepository;
    private readonly ILeaveRepository _leaveRepository;
    private readonly ITimeService _time;
    private readonly ILogger<AttendancesController> _logger;

    public AttendancesController(
        IAttendanceService attendanceService,
        IAttendanceRepository attendanceRepository,
        IShiftRepository shiftRepository,
        ILeaveRepository leaveRepository,
        ITimeService time,
        ILogger<AttendancesController> logger)
    {
        _attendanceService = attendanceService;
        _attendanceRepository = attendanceRepository;
        _shiftRepository = shiftRepository;
        _leaveRepository = leaveRepository;
        _time = time;
        _logger = logger;
    }

    private IActionResult ToResponse(AttendanceResult result) =>
        result.Success
            ? Ok(new { success = true, message = result.Message, attendance = AttendanceView.From(result.Attendance!) })
            : StatusCode(result.StatusCode, new { success = false, message = result.Message });

    [Authorize(Roles = Roles.Employee)]
    [HttpPost("check-in")]
    public async Task<IActionResult> CheckIn([FromBody] CheckRequestModel model)
    {
        try
        {
            return ToResponse(await _attendanceService.CheckInAsync(User.GetUserId(), model));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CheckIn lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Employee)]
    [HttpPost("check-out")]
    public async Task<IActionResult> CheckOut([FromBody] CheckRequestModel model)
    {
        try
        {
            return ToResponse(await _attendanceService.CheckOutAsync(User.GetUserId(), model));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CheckOut lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Dashboard nhân viên: các ca đang hoạt động hôm nay + bản ghi chấm công của mình
    [Authorize(Roles = Roles.Employee)]
    [HttpGet("today")]
    public async Task<IActionResult> GetToday()
    {
        try
        {
            var userId = User.GetUserId();
            var now = _time.LocalNow;
            var today = now.Date;

            var items = new List<object>();
            foreach (var shift in (await _shiftRepository.GetShiftsAsync()).Where(s => s.IsActive))
            {
                var attendance = await _attendanceRepository.FindAsync(userId, shift.Id, today);
                // Ca qua nửa đêm (đến 24:00): sau 00:00 vẫn hiện bản ghi đang mở của hôm qua để check-out
                if (attendance == null && ShiftTime.IsEndOfDay(shift.EndTime))
                    attendance = await _attendanceRepository.FindOpenAsync(userId, shift.Id, today.AddDays(-1));
                items.Add(new
                {
                    shift = new { shift.Id, shift.Name, shift.StartTime, shift.EndTime, shift.LateGraceMinutes },
                    attendance = attendance == null ? null : AttendanceView.From(attendance)
                });
            }

            return Ok(new
            {
                date = today,
                serverTime = now,
                onLeave = await _leaveRepository.HasApprovedLeaveOnAsync(userId, today),
                items
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetToday lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // from/to theo ngày làm việc (yyyy-MM-dd). Nhân viên luôn chỉ thấy của mình.
    [HttpGet]
    public async Task<IActionResult> GetAttendances(
        [FromQuery] int? userId, [FromQuery] DateTime? from, [FromQuery] DateTime? to, [FromQuery] string? status)
    {
        try
        {
            var filterUser = User.IsAdmin() ? userId : User.GetUserId();
            var list = await _attendanceRepository.GetAttendancesAsync(filterUser, from, to, status);
            return Ok(list.Select(AttendanceView.From));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetAttendances lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetAttendanceById(int id)
    {
        try
        {
            var attendance = await _attendanceRepository.GetAttendanceDetailAsync(id);
            if (attendance == null || (!User.IsAdmin() && attendance.UserId != User.GetUserId()))
                return NotFound();
            return Ok(AttendanceView.From(attendance));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetAttendanceById lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Admin gỡ cờ nghi ngờ của một bản ghi
    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/review")]
    public async Task<IActionResult> Review(int id, [FromBody] AdminNoteModel? model = null)
    {
        try
        {
            return ToResponse(await _attendanceService.ReviewAsync(id, User.GetUserId(), model?.Note));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Review lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Admin đóng bản ghi quên check-out
    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/close")]
    public async Task<IActionResult> Close(int id, [FromBody] CloseAttendanceModel model)
    {
        try
        {
            return ToResponse(await _attendanceService.CloseAsync(id, User.GetUserId(), model.CheckOutTime, model.Note));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Close lỗi");
            return StatusCode(500, "Internal server error");
        }
    }
}
