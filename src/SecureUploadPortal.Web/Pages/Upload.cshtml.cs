using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SecureUploadPortal.Web.Services;

namespace SecureUploadPortal.Web.Pages;

public class UploadModel : PageModel
{
    private readonly BlobUploadService _blobUploadService;
    private readonly ILogger<UploadModel> _logger;

    public string? ErrorMessage { get; private set; }
    public string AuthenticatedEmail { get; private set; } = string.Empty;

    public UploadModel(BlobUploadService blobUploadService, ILogger<UploadModel> logger)
    {
        _blobUploadService = blobUploadService;
        _logger = logger;
    }

    public IActionResult OnGet()
    {
        if (HttpContext.Session.GetString("Authenticated") != "true")
            return RedirectToPage("/Index");

        AuthenticatedEmail = HttpContext.Session.GetString("AuthenticatedEmail") ?? string.Empty;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(IFormFile file)
    {
        if (HttpContext.Session.GetString("Authenticated") != "true")
            return RedirectToPage("/Index");

        AuthenticatedEmail = HttpContext.Session.GetString("AuthenticatedEmail") ?? string.Empty;

        if (file is null || file.Length == 0)
        {
            ErrorMessage = "Please select a file to upload.";
            return Page();
        }

        try
        {
            var blobName = await _blobUploadService.UploadFileAsync(file);
            _logger.LogInformation("File {FileName} uploaded by {Email} as blob {BlobName}.",
                file.FileName, AuthenticatedEmail, blobName);

            return RedirectToPage("/Success", new { fileName = file.FileName, blobName });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Upload failed for {Email}.", AuthenticatedEmail);
            ErrorMessage = "Upload failed. Please try again.";
            return Page();
        }
    }
}
