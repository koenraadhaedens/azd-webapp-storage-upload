using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SecureUploadPortal.Web.Pages;

public class SuccessModel : PageModel
{
    public IReadOnlyList<(string FileName, string BlobName)> UploadedFiles { get; private set; } = [];

    public IActionResult OnGet([FromQuery] string? fileNames, [FromQuery] string? blobRefs)
    {
        if (HttpContext.Session.GetString("Authenticated") != "true")
            return RedirectToPage("/Index");

        var names = fileNames?.Split('|') ?? [];
        var refs  = blobRefs?.Split('|')  ?? [];
        UploadedFiles = names.Zip(refs, (n, r) => (n, r)).ToList();
        return Page();
    }
}
