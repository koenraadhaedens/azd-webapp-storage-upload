namespace SecureUploadPortal.Web.Services;

public static class OtpGenerator
{
    public static string Generate()
    {
        // Use a cryptographically secure random number generator
        return System.Security.Cryptography.RandomNumberGenerator.GetInt32(100000, 999999).ToString();
    }
}
