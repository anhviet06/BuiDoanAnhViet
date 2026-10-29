using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class HealthController : ControllerBase
{
    // Kiểm tra backend sống (không cần đăng nhập)
    [HttpGet]
    public IActionResult Get() => Ok(new { app = "TimeGuard", status = "ok" });
}
