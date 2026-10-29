using System.Security.Claims;
using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Services;

public static class ClaimsExtensions
{
    // Id người dùng lấy từ JWT (0 nếu không có)
    public static int GetUserId(this ClaimsPrincipal principal)
    {
        return int.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
    }

    public static bool IsAdmin(this ClaimsPrincipal principal) => principal.IsInRole(Roles.Admin);
}
