using Azure.Storage.Blobs;

namespace SecureUploadPortal.Web.Services;

public class BlobUploadService
{
    private readonly BlobServiceClient _blobServiceClient;
    private const string ContainerName = "uploads";

    public BlobUploadService(BlobServiceClient blobServiceClient)
    {
        _blobServiceClient = blobServiceClient;
    }

    public async Task<string> UploadFileAsync(IFormFile file, CancellationToken cancellationToken = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(ContainerName);
        await containerClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken);

        var blobName = $"{Guid.NewGuid()}/{file.FileName}";
        var blobClient = containerClient.GetBlobClient(blobName);

        await using var stream = file.OpenReadStream();
        await blobClient.UploadAsync(stream, overwrite: false, cancellationToken);

        return blobName;
    }
}
