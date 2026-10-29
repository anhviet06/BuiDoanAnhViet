using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Buidoananhviet.Api.Services;

public interface IEmailSender
{
    Task SendAsync(string to, string subject, string body);
}

// Gửi email qua SMTP (MailKit). Cấu hình trong section Smtp.
public class EmailSender : IEmailSender
{
    private readonly IConfiguration _configuration;

    public EmailSender(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendAsync(string to, string subject, string body)
    {
        var smtp = _configuration.GetSection("Smtp");
        var host = smtp["Host"];
        if (string.IsNullOrWhiteSpace(host))
            throw new InvalidOperationException("Chưa cấu hình Smtp:Host");

        // Chấp nhận cả hai kiểu tên khóa: User/From hoặc Username/FromEmail (+ FromName)
        var user = First(smtp["User"], smtp["Username"]);
        var fromAddress = First(smtp["From"], smtp["FromEmail"], user) ?? "";
        var password = smtp["Password"] ?? "";
        // Mật khẩu ứng dụng Gmail hay được chép kèm dấu cách ("abcd efgh ...") -> bỏ đi
        if (host.Contains("gmail", StringComparison.OrdinalIgnoreCase))
            password = password.Replace(" ", "");

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(smtp["FromName"] ?? "", fromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("plain") { Text = body };

        using var client = new SmtpClient();
        await client.ConnectAsync(host, int.Parse(smtp["Port"] ?? "587"), SecureSocketOptions.StartTls);
        if (!string.IsNullOrWhiteSpace(user))
            await client.AuthenticateAsync(user, password);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }

    // Giá trị đầu tiên không rỗng (appsettings.json đặt sẵn chuỗi rỗng cho các khóa này)
    private static string? First(params string?[] values) => values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));
}
