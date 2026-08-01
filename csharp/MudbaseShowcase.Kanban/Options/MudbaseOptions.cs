namespace MudbaseShowcase.Kanban.Options;

/// <summary>
/// Every config value this app needs to talk to a provisioned Mudbase project. Bound from the
/// "Mudbase" section of appsettings.json / environment variables - see appsettings.Example.json
/// at the repo root for the full list with descriptions. None of these values are secrets (a
/// project/collection/board id is not sensitive), so, unlike a real credential, they are checked
/// into appsettings.json directly - see README.md.
/// </summary>
public sealed class MudbaseOptions
{
    public const string SectionName = "Mudbase";

    /// <summary>Mudbase API base URL. Defaults to the public cloud endpoint.</summary>
    public string BaseUrl { get; set; } = "https://cloud.mudbase.dev";

    /// <summary>The Mudbase project ID this app is provisioned against.</summary>
    public string ProjectId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "lists" collection (board columns).</summary>
    public string ListsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "cards" collection.</summary>
    public string CardsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "activity" collection (the audit/history feed).</summary>
    public string ActivityCollectionId { get; set; } = string.Empty;

    /// <summary>
    /// This is a single shared-board demo, not multi-tenant - every boardId field on every
    /// lists/cards/activity document is this one constant. Must be a real 24-hex-char ObjectId
    /// (the id of the single document in a small `boards` collection), not an arbitrary slug like
    /// "main-board" - Mudbase's query sanitizer rejects any top-level filter field ending in "Id"
    /// that isn't a real ObjectId format. See plan/build-plan.md.
    /// </summary>
    public string BoardId { get; set; } = string.Empty;

    /// <summary>
    /// Throws with a clear, specific message if any required value was left unset, so a
    /// misconfigured deployment fails at startup instead of surfacing confusing errors deep
    /// inside a request handler.
    /// </summary>
    public void Validate()
    {
        var missing = new List<string>();

        if (string.IsNullOrWhiteSpace(BaseUrl)) missing.Add(nameof(BaseUrl));
        if (string.IsNullOrWhiteSpace(ProjectId)) missing.Add(nameof(ProjectId));
        if (string.IsNullOrWhiteSpace(ListsCollectionId)) missing.Add(nameof(ListsCollectionId));
        if (string.IsNullOrWhiteSpace(CardsCollectionId)) missing.Add(nameof(CardsCollectionId));
        if (string.IsNullOrWhiteSpace(ActivityCollectionId)) missing.Add(nameof(ActivityCollectionId));
        if (string.IsNullOrWhiteSpace(BoardId)) missing.Add(nameof(BoardId));

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"Missing required Mudbase configuration values: {string.Join(", ", missing)}. " +
                "Set them under the \"Mudbase\" section of appsettings.json, appsettings.Development.json, " +
                "or the corresponding Mudbase__<Key> environment variables. See appsettings.Example.json.");
        }
    }
}
