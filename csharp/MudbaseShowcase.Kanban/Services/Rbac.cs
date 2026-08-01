namespace MudbaseShowcase.Kanban.Services;

/// <summary>
/// Client-/server-side mirror of the RBAC matrix Mudbase's own collection permissions already
/// enforce server-side on the real project (see plan/build-plan.md). Used both to hide/disable
/// controls a role cannot use (with a clear reason) in the Razor views, and as a second,
/// server-side check inside Pages/Index.cshtml.cs's handlers before ever calling Mudbase - it is
/// NOT the real security boundary by itself. A raw API call bypassing this app's UI entirely is
/// still rejected by the platform; see plan/build-plan.md's live smoke test.
/// </summary>
public static class Rbac
{
    public const string Owner = "owner";
    public const string Member = "member";
    public const string Viewer = "viewer";

    public static bool CanManageLists(string? role) => role == Owner;

    public static bool CanManageCards(string? role) => role == Owner || role == Member;

    public static bool IsReadOnly(string? role) => role == Viewer || role is null;

    public static string RoleLabel(string? role) => role switch
    {
        Owner => "Owner",
        Member => "Member",
        Viewer => "Viewer",
        _ => "Unknown",
    };
}
