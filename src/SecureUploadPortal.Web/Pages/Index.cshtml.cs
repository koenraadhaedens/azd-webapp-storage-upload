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

        try
        {
            await _otpEmailService.SendOtpAsync(email, otp);
            _logger.LogInformation("OTP dispatched for email {Email}.", email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to dispatch OTP for {Email}.", email);
            ErrorMessage = "Failed to send OTP. Please try again in a moment.";
            return Page();
        }

        return RedirectToPage("/Verify");
    }
}
