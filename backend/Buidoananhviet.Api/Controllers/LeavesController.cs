using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

// Nhân viên: tạo/xem/sửa/xóa đơn của mình (sửa/xóa chỉ khi còn pending).
// Admin: xem tất cả (lọc theo nhân viên/trạng thái) và duyệt/từ chối.
[Authorize]
[Route("api/[controller]")]
[ApiController]
public class LeavesController : ControllerBase
{
    private readonly ILeaveRepository _leaveRepository;
    private readonly ILogger<LeavesController> _logger;

    public LeavesController(ILeaveRepository leaveRepository, ILogger<LeavesController> logger)
    {
        _leaveRepository = leaveRepository;
        _logger = logger;
    }

    private static string? Validate(LeaveRequestModel m) =>
        m.ToDate.Date < m.FromDate.Date ? "Ngày kết thúc phải từ ngày bắt đầu trở đi" :
        string.IsNullOrWhiteSpace(m.Reason) ? "Vui lòng nhập lý do" : null;

    // Admin lọc được theo userId; nhân viên luôn chỉ thấy đơn của mình
    [HttpGet]
    public async Task<IActionResult> GetLeaves([FromQuery] int? userId, [FromQuery] string? status)
    {
        try
        {
            var filterUser = User.IsAdmin() ? userId : User.GetUserId();
            return Ok(await _leaveRepository.GetLeavesAsync(filterUser, status));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetLeaves lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetLeaveById(int id)
    {
        try
        {
            var leave = await _leaveRepository.GetLeaveByIdAsync(id);
            // Nhân viên xem đơn người khác -> coi như không tồn tại
            if (leave == null || (!User.IsAdmin() && leave.UserId != User.GetUserId()))
                return NotFound();
            return Ok(leave);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetLeaveById lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Employee)]
    [HttpPost]
    public async Task<IActionResult> AddLeave([FromBody] LeaveRequestModel model)
    {
        try
        {
            var error = Validate(model);
            if (error != null)
                return BadRequest(new { success = false, message = error });

            var userId = User.GetUserId();
            var from = model.FromDate.Date;
            var to = model.ToDate.Date;
            if (await _leaveRepository.HasOverlapAsync(userId, from, to))
                return BadRequest(new { success = false, message = "Khoảng ngày này trùng với một đơn nghỉ khác" });

            var leave = new Leave
            {
                UserId = userId,
                FromDate = from,
                ToDate = to,
                Reason = model.Reason.Trim()
            };
            await _leaveRepository.AddLeaveAsync(leave);
            return CreatedAtAction(nameof(GetLeaveById), new { id = leave.Id }, leave);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AddLeave lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Employee)]
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateLeave(int id, [FromBody] LeaveRequestModel model)
    {
        try
        {
            var leave = await _leaveRepository.GetLeaveByIdAsync(id);
            if (leave == null || leave.UserId != User.GetUserId())
                return NotFound();
            if (leave.Status != LeaveStatus.Pending)
                return Conflict(new { success = false, message = "Chỉ sửa được đơn đang chờ duyệt" });
            var error = Validate(model);
            if (error != null)
                return BadRequest(new { success = false, message = error });
            if (await _leaveRepository.HasOverlapAsync(leave.UserId, model.FromDate.Date, model.ToDate.Date, id))
                return BadRequest(new { success = false, message = "Khoảng ngày này trùng với một đơn nghỉ khác" });

            leave.FromDate = model.FromDate.Date;
            leave.ToDate = model.ToDate.Date;
            leave.Reason = model.Reason.Trim();
            await _leaveRepository.UpdateLeaveAsync(leave);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateLeave lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Employee)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteLeave(int id)
    {
        try
        {
            var leave = await _leaveRepository.GetLeaveByIdAsync(id);
            if (leave == null || leave.UserId != User.GetUserId())
                return NotFound();
            if (leave.Status != LeaveStatus.Pending)
                return Conflict(new { success = false, message = "Chỉ xóa được đơn đang chờ duyệt" });

            await _leaveRepository.DeleteLeaveAsync(id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DeleteLeave lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/approve")]
    public Task<IActionResult> Approve(int id, [FromBody] LeaveDecisionModel? model = null) =>
        Decide(id, LeaveStatus.Approved, model?.AdminNote);

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/reject")]
    public Task<IActionResult> Reject(int id, [FromBody] LeaveDecisionModel? model = null) =>
        Decide(id, LeaveStatus.Rejected, model?.AdminNote);

    // Chỉ quyết định được đơn đang pending
    private async Task<IActionResult> Decide(int id, string status, string? note)
    {
        try
        {
            var leave = await _leaveRepository.GetLeaveByIdAsync(id);
            if (leave == null)
                return NotFound();
            if (leave.Status != LeaveStatus.Pending)
                return Conflict(new { success = false, message = "Đơn này đã được xử lý" });

            leave.Status = status;
            leave.AdminNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
            await _leaveRepository.UpdateLeaveAsync(leave);
            return Ok(leave);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Decide lỗi");
            return StatusCode(500, "Internal server error");
        }
    }
}
