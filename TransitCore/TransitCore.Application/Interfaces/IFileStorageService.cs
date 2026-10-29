namespace TransitCore.Application.Interfaces;

/// <summary>
/// Saves an uploaded file's raw bytes under a category (e.g. "pod-photos",
/// "pod-signatures", "trip-documents") and returns a URL path the frontend
/// can request directly (served via static files) and the backend can store
/// verbatim in a *FilePath column.
///
/// Local disk under wwwroot is an MVP/dev choice - it's what the app's
/// current hosting (a single LocalDB-backed dev API, no cloud storage
/// configured) actually has available, not a permanent architecture
/// decision. Swapping this for blob storage later only touches the
/// Infrastructure implementation, not any caller.
/// </summary>
public interface IFileStorageService
{
    Task<string> SaveFileAsync(Stream content, string originalFileName, string category, CancellationToken cancellationToken = default);
}
