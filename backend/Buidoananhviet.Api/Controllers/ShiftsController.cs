using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

// Đã đăng nhập là xem được ca; chỉ admin mới thêm/sửa/xóa và thấy QrToken.
// Nhân viên KHÔNG được thấy QrToken (nếu không sẽ chấm công từ xa được).
[Authorize]
[Route("api/[controller]")]
[ApiController]
public class ShiftsController : ControllerBase
{
    private readonly IShiftRepository _shiftRepository;
    private readonly IAttendanceRepository _attendanceRepository;
    private readonly ILogger<ShiftsController> _logger;

    public ShiftsController(
        IShiftRepository shiftRepository,
        IAttendanceRepository attendanceRepository,
        ILogger<ShiftsController> logger)
    {
        _shiftRepository = shiftRepository;
        _attendanceRepository = attendanceRepository;
        _logger = logger;
    }

    // Admin thấy đủ entity (có QrToken), nhân viên chỉ thấy thông tin ca
    private object View(Shift s) => User.IsAdmin()
        ? s
        : new { s.Id, s.Name, s.StartTime, s.EndTime, s.LateGraceMinutes, s.IsActive };

    private static string? Validate(ShiftModel m) =>
        m.EndTime <= m.StartTime ? "Giờ kết thúc phải sau giờ bắt đầu" :
        m.StartTime < TimeSpan.Zero || m.EndTime >= TimeSpan.FromDays(1) ? "Giờ ca không hợp lệ" : null;

    [HttpGet]
    public async Task<IActionResult> GetShifts()
    {
        try
        {
            var shifts = await _shiftRepository.GetShiftsAsync();
            return Ok(shifts.Select(View));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetShifts lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetShiftById(int id)
    {
        try
        {
            var shift = await _shiftRepository.GetShiftByIdAsync(id);
            if (shift == null)
                return NotFound();
            return Ok(View(shift));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetShiftById lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPost]
    public async Task<IActionResult> AddShift([FromBody] ShiftModel model)
    {
        try
        {
            var error = Validate(model);
            if (error != null)
                return BadRequest(new { success = false, message = error });

            // QrToken tự sinh ở entity (Guid), client không được tự đặt
            var shift = new Shift
            {
                Name = model.Name.Trim(),
                StartTime = model.StartTime,
                EndTime = model.EndTime,
                LateGraceMinutes = model.LateGraceMinutes,
                IsActive = model.IsActive
            };
            await _shiftRepository.AddShiftAsync(shift);
            return CreatedAtAction(nameof(GetShiftById), new { id = shift.Id }, shift);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AddShift lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateShift(int id, [FromBody] ShiftModel model)
    {
        try
        {
            var shift = await _shiftRepository.GetShiftByIdAsync(id);
            if (shift == null)
                return NotFound();
            var error = Validate(model);
            if (error != null)
                return BadRequest(new { success = false, message = error });

            shift.Name = model.Name.Trim();
            shift.StartTime = model.StartTime;
            shift.EndTime = model.EndTime;
            shift.LateGraceMinutes = model.LateGraceMinutes;
            shift.IsActive = model.IsActive;
            await _shiftRepository.UpdateShiftAsync(shift);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateShift lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Tạo lại token QR của ca (vô hiệu QR cũ, ví dụ khi QR bị lộ)
    [Authorize(Roles = Roles.Admin)]
    [HttpPost("{id:int}/regenerate-qr")]
    public async Task<IActionResult> RegenerateQr(int id)
    {
        try
        {
            var shift = await _shiftRepository.GetShiftByIdAsync(id);
            if (shift == null)
                return NotFound();

            shift.QrToken = Guid.NewGuid().ToString("N");
            await _shiftRepository.UpdateShiftAsync(shift);
            return Ok(shift);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RegenerateQr lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Ca đã có chấm công thì không xóa (409), hãy tắt IsActive
    [Authorize(Roles = Roles.Admin)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteShift(int id)
    {
        try
        {
            var shift = await _shiftRepository.GetShiftByIdAsync(id);
            if (shift == null)
                return NotFound();
            if (await _attendanceRepository.HasAttendanceForShiftAsync(id))
                return Conflict(new { success = false, message = "Ca đã có dữ liệu chấm công, không thể xóa. Hãy tắt hoạt động của ca." });

            await _shiftRepository.DeleteShiftAsync(id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DeleteShift lỗi");
            return StatusCode(500, "Internal server error");
        }
    }
}
