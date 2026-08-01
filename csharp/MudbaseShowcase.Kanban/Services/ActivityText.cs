using MudbaseShowcase.Kanban.Models;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>Renders one activity row as a plain, readable sentence for the feed - direct port of web/src/lib/activity-text.ts's describeActivity.</summary>
public static class ActivityText
{
    public static string Describe(ActivityDocument entry)
    {
        string who = string.IsNullOrWhiteSpace(entry.ActorName) ? "Someone" : entry.ActorName;

        return entry.Action switch
        {
            ActivityActions.CreatedCard =>
                $"{who} created card \"{entry.CardTitle ?? "Untitled"}\" in {entry.ToList ?? "a list"}",

            ActivityActions.Moved when entry.FromList is not null && entry.ToList is not null && entry.FromList == entry.ToList =>
                $"{who} reordered \"{entry.CardTitle ?? "a card"}\" within {entry.ToList}",

            ActivityActions.Moved =>
                $"{who} moved \"{entry.CardTitle ?? "a card"}\" from {entry.FromList ?? "?"} to {entry.ToList ?? "?"}",

            ActivityActions.DeletedCard =>
                $"{who} deleted card \"{entry.CardTitle ?? "Untitled"}\" from {entry.FromList ?? "a list"}",

            ActivityActions.CreatedList =>
                $"{who} created list \"{entry.ToList ?? "Untitled"}\"",

            ActivityActions.RenamedList =>
                $"{who} renamed list \"{entry.FromList ?? "?"}\" to \"{entry.ToList ?? "?"}\"",

            ActivityActions.DeletedList =>
                $"{who} deleted list \"{entry.FromList ?? "Untitled"}\"",

            _ => $"{who} did something on the board",
        };
    }
}
