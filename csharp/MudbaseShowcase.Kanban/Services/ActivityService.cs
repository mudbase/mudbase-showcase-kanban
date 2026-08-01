using Microsoft.Extensions.Options;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Options;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>Reads and appends to the "activity" collection - the board's audit/history feed. Direct port of web/src/hooks/useActivity.ts's server calls.</summary>
public sealed class ActivityService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public ActivityService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>Newest-first, paginated.</summary>
    public Task<MudbaseListResult<ActivityDocument>> ListForBoardAsync(int page, int limit, CancellationToken cancellationToken) =>
        _data.ListAsync<ActivityDocument>(
            _options.ActivityCollectionId,
            new Dictionary<string, object?> { ["boardId"] = _options.BoardId },
            sort: "-createdAt",
            page: page,
            limit: limit,
            cancellationToken: cancellationToken);

    /// <summary>Appends one row. `cardTitle`/`fromList`/`toList` are omitted (not sent as null) when not applicable to the given action, mirroring the reference app's conditional field writes.</summary>
    public Task<ActivityDocument> LogAsync(
        string actorId, string actorName, string action, string? cardTitle, string? fromList, string? toList, CancellationToken cancellationToken)
    {
        var data = new Dictionary<string, object?>
        {
            ["boardId"] = _options.BoardId,
            ["actorId"] = actorId,
            ["actorName"] = actorName,
            ["action"] = action,
        };

        if (cardTitle is not null) data["cardTitle"] = cardTitle;
        if (fromList is not null) data["fromList"] = fromList;
        if (toList is not null) data["toList"] = toList;

        return _data.CreateAsync<ActivityDocument>(_options.ActivityCollectionId, data, cancellationToken);
    }
}
