using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SecureUploadPortal.Web.Pages;

public class VerifyModel : PageModel
{
    private const int MaxAttempts = 5;
    private const int OtpExpiryMinutes = 10;

    private readonly ILogger<VerifyModel> _logger;

    public string? ErrorMessage { get; private set; }
    public string MaskedEmail { get; private set; } = string.Empty;

    public VerifyModel(ILogger<VerifyModel> logger)
    {
        _logger = logger;
    }

    public IActionResult OnGet()
    {
        var email = HttpContext.Session.GetString("OtpEmail");
        if (string.IsNullOrEmpty(email))
            return RedirectToPage("/Index");

        MaskedEmail = MaskEmail(email);
        return Page();
    }

    public IActionResult OnPost([FromForm] string otp)
    {
        var email = HttpContext.Session.GetString("OtpEmail");
        if (string.IsNullOrEmpty(email))
            return RedirectToPage("/Index");

        MaskedEmail = MaskEmail(email);

        var storedOtp = HttpContext.Session.GetString("OtpCode");
        var generatedAtStr = HttpContext.Session.GetString("OtpGeneratedAt");
        var attempts = HttpContext.Session.GetInt32("OtpAttempts") ?? 0;

        if (attempts >= MaxAttempts)
        {
            _logger.LogWarning("Max OTP attempts exceeded for {Email}. Resetting session.", email);
            HttpContext.Session.Clear();
            return RedirectToPage("/Index");
        }

        if (string.IsNullOrEmpty(storedOtp) || string.IsNullOrEmpty(generatedAtStr))
        {
            ErrorMessage = "Session expired. Please request a new OTP.";
            return Page();
        }

        var generatedAt = DateTimeOffset.Parse(generatedAtStr);
        if (DateTimeOffset.UtcNow - generatedAt > TimeSpan.FromMinutes(OtpExpiryMinutes))
        {
            _logger.LogInformation("OTP expired for {Email}.", email);
            HttpContext.Session.Clear();
            ErrorMessage = "OTP has expired. Please request a new one.";
            return RedirectToPage("/Index");
        }

        if (otp != storedOtp)
        {
            attempts++;
            HttpContext.Session.SetInt32("OtpAttempts", attempts);
            ErrorMessage = $"Invalid code. {MaxAttempts - attempts} attempt(s) remaining.";
            _logger.LogWarning("Invalid OTP attempt {Attempt}/{Max} for {Email}.", attempts, MaxAttempts, email);
            return Page();
        }

        HttpContext.Session.Remove("OtpCode");
        HttpContext.Session.Remove("OtpGeneratedAt");
        HttpContext.Session.Remove("OtpAttempts");
        HttpContext.Session.SetString("Authenticated", "true");
        HttpContext.Session.SetString("AuthenticatedEmail", email);

        _logger.LogInformation("OTP validated successfully for {Email}.", email);
        return RedirectToPage("/Upload");
    }

    private static string MaskEmail(string email)
    {
        var atIndex = email.IndexOf('@');
        if (atIndex <= 1) return email;
        return $"{email[0]}***{email[atIndex..]}";
    }
}
