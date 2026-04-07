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

    public async Task<bool> SendOtpAsync(string email, string otp, CancellationToken cancellationToken = default)
    {
        var logicAppUrl = _configuration["LOGIC_APP_URL"];
        if (string.IsNullOrEmpty(logicAppUrl))
        {
            _logger.LogWarning("LOGIC_APP_URL is not configured — OTP email not sent for {Email}.", email);
            return false;
        }

        try
        {
            var payload = new
            {
                to = email,
                subject = "Your Secure Upload Portal OTP",
                body = $"<p>Your one-time password is: <strong>{otp}</strong></p><p>This code expires in 10 minutes. Do not share it with anyone.</p>"
            };
            var json = System.Text.Json.JsonSerializer.Serialize(payload);
            using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync(logicAppUrl, content, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Logic App OTP trigger returned {StatusCode} for {Email}.",
                    response.StatusCode, email);
                return false;
            }

            _logger.LogInformation("OTP sent to {Email} via Logic App.", email);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to dispatch OTP email for {Email}.", email);
            return false;
        }
    }
}
