using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SecureUploadPortal.Web.Pages;

public class SuccessModel : PageModel
{
    public string FileName { get; private set; } = string.Empty;
    public string BlobName { get; private set; } = string.Empty;

    public IActionResult OnGet([FromQuery] string? fileName, [FromQuery] string? blobName)
    {
        if (HttpContext.Session.GetString("Authenticated") != "true")
            return RedirectToPage("/Index");

        FileName = fileName ?? string.Empty;
        BlobName = blobName ?? string.Empty;
        return Page();
    }
}
