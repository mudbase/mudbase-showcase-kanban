using Microsoft.Extensions.Options;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Options;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>Board column (list) CRUD - direct port of web/src/hooks/useLists.ts's server calls. Owner-only writes, enforced both here defensively (Pages/Index.cshtml.cs) and by Mudbase's own collection permissions.</summary>
public sealed class ListsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public ListsService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>Every list on the shared board, ascending by column order.</summary>
    public Task<MudbaseListResult<ListDocument>> ListForBoardAsync(CancellationToken cancellationToken) =>
        _data.ListAsync<ListDocument>(
            _options.ListsCollectionId,
            new Dictionary<string, object?> { ["boardId"] = _options.BoardId },
            sort: "position",
            page: 1,
            limit: 200,
            cancellationToken: cancellationToken);

    public Task<ListDocument?> GetAsync(string listId, CancellationToken cancellationToken) =>
        _data.GetAsync<ListDocument>(_options.ListsCollectionId, listId, cancellationToken);

    public Task<ListDocument> CreateAsync(string name, int position, CancellationToken cancellationToken) =>
        _data.CreateAsync<ListDocument>(
            _options.ListsCollectionId,
            new Dictionary<string, object?>
            {
                ["boardId"] = _options.BoardId,
                ["name"] = name,
                ["position"] = position,
            },
            cancellationToken);

    public Task<ListDocument> RenameAsync(string listId, string newName, CancellationToken cancellationToken) =>
        _data.UpdateAsync<ListDocument>(
            _options.ListsCollectionId, listId, new Dictionary<string, object?> { ["name"] = newName }, cancellationToken);

    /// <summary>Left/right reorder: swaps this list's position with an adjacent one.</summary>
    public Task SwapPositionsAsync(ListDocument a, ListDocument b, CancellationToken cancellationToken) =>
        Task.WhenAll(
            _data.UpdateAsync<ListDocument>(
                _options.ListsCollectionId, a.Id, new Dictionary<string, object?> { ["position"] = b.Position }, cancellationToken),
            _data.UpdateAsync<ListDocument>(
                _options.ListsCollectionId, b.Id, new Dictionary<string, object?> { ["position"] = a.Position }, cancellationToken));

    public Task DeleteAsync(string listId, CancellationToken cancellationToken) =>
        _data.DeleteAsync(_options.ListsCollectionId, listId, cancellationToken);
}
