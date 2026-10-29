using TransitCore.Application.Interfaces;

namespace TransitCore.Infrastructure.Files;

public class LocalFileStorageService : IFileStorageService
{
    private readonly string _webRootPath;

    // Takes the content root as a plain string (passed from Program.cs's
    // builder.Environment.ContentRootPath) rather than depending on
    // IWebHostEnvironment directly - that type lives in an ASP.NET Core
    // hosting package this project (a plain class library) doesn't
    // otherwise need to reference.
    public LocalFileStorageService(string contentRootPath)
    {
        _webRootPath = Path.Combine(contentRootPath, "wwwroot");
    }

    public async Task<string> SaveFileAsync(Stream content, string originalFileName, string category, CancellationToken cancellationToken = default)
    {
        var safeCategory = string.IsNullOrWhiteSpace(category) ? "misc" : category;
        var extension = Path.GetExtension(originalFileName);
        var fileName = $"{Guid.NewGuid():N}{extension}";

        var directory = Path.Combine(_webRootPath, "uploads", safeCategory);
        Directory.CreateDirectory(directory);

        var fullPath = Path.Combine(directory, fileName);
        await using (var fileStream = new FileStream(fullPath, FileMode.Create))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        // Forward slashes always - this is a URL path, not a filesystem path.
        return $"/uploads/{safeCategory}/{fileName}";
    }
}
