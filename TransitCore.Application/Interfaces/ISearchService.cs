using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface ISearchService
{
    Task<IReadOnlyList<SearchResultDto>> SearchAsync(string term, CancellationToken cancellationToken = default);
}
