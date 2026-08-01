using Microsoft.Extensions.Options;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Options;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>Card CRUD, cross-list move, and in-list reorder - direct port of web/src/hooks/useCards.ts's server calls. Owner/member writes, enforced both here defensively (Pages/Index.cshtml.cs) and by Mudbase's own collection permissions.</summary>
public sealed class CardsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public CardsService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>Every card on the shared board, ascending by in-column order - fetched once and grouped client-side by listId, rather than one query per column.</summary>
    public Task<MudbaseListResult<CardDocument>> ListForBoardAsync(CancellationToken cancellationToken) =>
        _data.ListAsync<CardDocument>(
            _options.CardsCollectionId,
            new Dictionary<string, object?> { ["boardId"] = _options.BoardId },
            sort: "position",
            page: 1,
            limit: 500,
            cancellationToken: cancellationToken);

    public Task<CardDocument?> GetAsync(string cardId, CancellationToken cancellationToken) =>
        _data.GetAsync<CardDocument>(_options.CardsCollectionId, cardId, cancellationToken);

    /// <summary>Creates a new card at the end of a column. `description`/`assigneeId`/`assigneeName` are omitted entirely (not sent as null) when not provided, mirroring useCreateCard's conditional spread.</summary>
    public Task<CardDocument> CreateAsync(
        string listId,
        string title,
        string? description,
        string? assigneeName,
        string createdById,
        string createdByName,
        int position,
        CancellationToken cancellationToken)
    {
        var data = new Dictionary<string, object?>
        {
            ["boardId"] = _options.BoardId,
            ["listId"] = listId,
            ["title"] = title,
            ["position"] = position,
            ["createdById"] = createdById,
            ["createdByName"] = createdByName,
        };

        if (!string.IsNullOrWhiteSpace(description))
        {
            data["description"] = description;
        }

        if (!string.IsNullOrWhiteSpace(assigneeName))
        {
            data["assigneeId"] = PseudoObjectId.From(assigneeName);
            data["assigneeName"] = assigneeName;
        }

        return _data.CreateAsync<CardDocument>(_options.CardsCollectionId, data, cancellationToken);
    }

    /// <summary>
    /// Edits a card's title/description/assignee in place. `description` clears to `""` (not
    /// null) when left blank, but `assigneeId`/`assigneeName` clear to `null` - `assigneeId` is
    /// validated server-side as an ObjectId reference, so an empty string fails that check the
    /// same way an invalid slug would ("Invalid ObjectId format for assigneeId"); `null` is the
    /// value that actually clears it. Matches web/src/hooks/useCards.ts's useUpdateCard exactly.
    /// Not itself logged to the activity feed - only creation, movement, and deletion are.
    /// </summary>
    public Task<CardDocument> UpdateDetailsAsync(
        string cardId, string title, string? description, string? assigneeName, CancellationToken cancellationToken)
    {
        bool hasAssignee = !string.IsNullOrWhiteSpace(assigneeName);
        var data = new Dictionary<string, object?>
        {
            ["title"] = title,
            ["description"] = description ?? string.Empty,
            ["assigneeId"] = hasAssignee ? PseudoObjectId.From(assigneeName!) : null,
            ["assigneeName"] = hasAssignee ? assigneeName : null,
        };

        return _data.UpdateAsync<CardDocument>(_options.CardsCollectionId, cardId, data, cancellationToken);
    }

    /// <summary>Moves a card to a different column, appended to the end of it. Writes both `listId` and `position` - the caller is responsible for also logging a `moved` activity entry.</summary>
    public Task<CardDocument> MoveToListAsync(string cardId, string toListId, int newPosition, CancellationToken cancellationToken) =>
        _data.UpdateAsync<CardDocument>(
            _options.CardsCollectionId,
            cardId,
            new Dictionary<string, object?> { ["listId"] = toListId, ["position"] = newPosition },
            cancellationToken);

    /// <summary>Up/down reorder within the same column: swaps this card's position with an adjacent one.</summary>
    public Task SwapPositionsAsync(CardDocument a, CardDocument b, CancellationToken cancellationToken) =>
        Task.WhenAll(
            _data.UpdateAsync<CardDocument>(
                _options.CardsCollectionId, a.Id, new Dictionary<string, object?> { ["position"] = b.Position }, cancellationToken),
            _data.UpdateAsync<CardDocument>(
                _options.CardsCollectionId, b.Id, new Dictionary<string, object?> { ["position"] = a.Position }, cancellationToken));

    public Task DeleteAsync(string cardId, CancellationToken cancellationToken) =>
        _data.DeleteAsync(_options.CardsCollectionId, cardId, cancellationToken);
}
