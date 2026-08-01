namespace MudbaseShowcase.Kanban.Services;

/// <summary>
/// The fixed set of `action` string values this app writes to the "activity" collection - mirrors
/// web/src/types/activity.ts's ActivityAction union exactly. Only created_card/moved/deleted_card
/// are required by the task ("every move...appends an activity entry"); the three list-level
/// actions are a small superset that makes the log read naturally as a real project history,
/// written by the same owner-only code paths that already call the lists API.
/// </summary>
public static class ActivityActions
{
    public const string CreatedCard = "created_card";
    public const string Moved = "moved";
    public const string DeletedCard = "deleted_card";
    public const string CreatedList = "created_list";
    public const string RenamedList = "renamed_list";
    public const string DeletedList = "deleted_list";
}
