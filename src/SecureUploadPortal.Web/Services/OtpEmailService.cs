namespace SecureUploadPortal.Web.Services;

public class OtpEmailService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<OtpEmailService> _logger;

    public OtpEmailService(HttpClient httpClient, IConfiguration configuration, ILogger<OtpEmailService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendOtpAsync(string email, string otp, CancellationToken cancellationToken = default)
    {
        var logicAppUrl = _configuration["LOGIC_APP_URL"]
            ?? throw new InvalidOperationException("LOGIC_APP_URL configuration is required.");

        var payload = new { email, otp };
        var response = await _httpClient.PostAsJsonAsync(logicAppUrl, payload, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Logic App OTP trigger returned {StatusCode} for email {Email}",
                response.StatusCode, email);
            throw new HttpRequestException($"OTP email delivery failed with status {response.StatusCode}.");
        }

        _logger.LogInformation("OTP sent to {Email} via Logic App.", email);
    }
}
