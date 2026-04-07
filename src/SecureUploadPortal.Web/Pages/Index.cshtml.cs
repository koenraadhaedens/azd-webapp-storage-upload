using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SecureUploadPortal.Web.Services;

namespace SecureUploadPortal.Web.Pages;

public class IndexModel : PageModel
{
    private readonly OtpEmailService _otpEmailService;
    private readonly ILogger<IndexModel> _logger;

    public string? ErrorMessage { get; private set; }

    public IndexModel(OtpEmailService otpEmailService, ILogger<IndexModel> logger)
    {
        _otpEmailService = otpEmailService;
        _logger = logger;
    }

    public IActionResult OnGet()
    {
        if (HttpContext.Session.GetString("Authenticated") == "true")
            return RedirectToPage("/Upload");

        return Page();
    }

    public async Task<IActionResult> OnPostAsync([FromForm] string email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            ErrorMessage = "Please provide a valid email address.";
            return Page();
        }

        var otp = OtpGenerator.Generate();

        HttpContext.Session.SetString("OtpEmail", email);
        HttpContext.Session.SetString("OtpCode", otp);
        HttpContext.Session.SetString("OtpGeneratedAt", DateTimeOffset.UtcNow.ToString("O"));
        HttpContext.Session.SetInt32("OtpAttempts", 0);

        var emailSent = await _otpEmailService.SendOtpAsync(email, otp);
        if (emailSent)
            _logger.LogInformation("OTP dispatched for email {Email}.", email);
        else
            _logger.LogWarning("OTP email could not be sent for {Email} — proceeding to verify page.", email);

        return RedirectToPage("/Verify");
    }
}
