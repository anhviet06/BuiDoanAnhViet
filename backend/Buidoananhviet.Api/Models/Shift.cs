namespace Buidoananhviet.Api.Models;

public class Shift
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public int LateGraceMinutes { get; set; } = 5;   // Số phút được phép trễ trước khi tính phạt
    public string QrToken { get; set; } = Guid.NewGuid().ToString("N"); // Token nhúng trong QR của ca
    public bool IsActive { get; set; } = true;
}
