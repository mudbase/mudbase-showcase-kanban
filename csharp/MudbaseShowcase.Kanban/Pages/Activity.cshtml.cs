using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Services;

namespace MudbaseShowcase.Kanban.Pages;

/// <summary>Full reverse-chronological activity feed, linked from the header nav. Mirrors web/src/app/activity/page.tsx.</summary>
public sealed class ActivityModel : PageModel
{
    private const int PageSize = 20;

    private readonly ActivityService _activity;

    public ActivityModel(ActivityService activity)
    {
        _activity = activity;
    }

    public IReadOnlyList<ActivityDocument> Entries { get; private set; } = Array.Empty<ActivityDocument>();

    public int CurrentPage { get; private set; } = 1;

    public bool HasMore { get; private set; }

    public string? LoadError { get; private set; }

    // NOTE: the query/route parameter is deliberately "pg", not "page" - Razor Pages reserves the
    // route-value key "page" internally for ambient self-redirects. Reusing "page" for pagination
    // here would silently corrupt that ambient value (see the sibling social showcase's
    // Index.cshtml.cs for the live-verified failure mode).
    public async Task OnGetAsync(int? pg, CancellationToken cancellationToken)
    {
        CurrentPage = pg is > 0 ? pg.Value : 1;

        try
        {
            MudbaseListResult<ActivityDocument> result = await _activity.ListForBoardAsync(CurrentPage, PageSize, cancellationToken);
            Entries = result.Items;
            HasMore = CurrentPage < result.TotalPages;
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load the activity log right now. (" + ex.Message + ")";
        }
    }
}
