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

    public async Task<IActionResult> OnPostAsync(IReadOnlyList<IFormFile> files)
    {
        if (HttpContext.Session.GetString("Authenticated") != "true")
            return RedirectToPage("/Index");

        AuthenticatedEmail = HttpContext.Session.GetString("AuthenticatedEmail") ?? string.Empty;

        var nonEmpty = files?.Where(f => f.Length > 0).ToList() ?? [];
        if (nonEmpty.Count == 0)
        {
            ErrorMessage = "Please select at least one file to upload.";
            return Page();
        }

        try
        {
            var blobNames = await _blobUploadService.UploadFilesAsync(nonEmpty);
            _logger.LogInformation("{Count} file(s) uploaded by {Email}.", blobNames.Count, AuthenticatedEmail);

            var fileNames = string.Join("|", nonEmpty.Select(f => f.FileName));
            var blobRefs  = string.Join("|", blobNames);
            return RedirectToPage("/Success", new { fileNames, blobRefs });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Upload failed for {Email}.", AuthenticatedEmail);
            ErrorMessage = "Upload failed. Please try again.";
            return Page();
        }
    }
}
