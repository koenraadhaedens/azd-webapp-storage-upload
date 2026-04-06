using Azure.Identity;
using Azure.Storage.Blobs;
using SecureUploadPortal.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(15);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});

var storageAccountName = builder.Configuration["STORAGE_ACCOUNT_NAME"]
    ?? throw new InvalidOperationException("STORAGE_ACCOUNT_NAME configuration is required.");

var blobServiceUri = new Uri($"https://{storageAccountName}.blob.core.windows.net");

builder.Services.AddSingleton(_ =>
    new BlobServiceClient(blobServiceUri, new DefaultAzureCredential()));

builder.Services.AddSingleton<BlobUploadService>();
builder.Services.AddHttpClient<OtpEmailService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
