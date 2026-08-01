using System.Text.Json.Serialization;

namespace MudbaseShowcase.Kanban.Models;

/// <summary>
/// Maps a document from the "activity" Mudbase collection - the audit/history feed. `FromList`/
/// `ToList` are list *names*, not ids (a deleted list's name should still read correctly in old
/// history rows). See Services/ActivityActions.cs for the fixed set of `Action` values this app
/// writes, and Services/ActivityText.cs for rendering one row as a readable sentence.
/// </summary>
public sealed class ActivityDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("boardId")]
    public string BoardId { get; set; } = string.Empty;

    [JsonPropertyName("actorId")]
    public string ActorId { get; set; } = string.Empty;

    [JsonPropertyName("actorName")]
    public string ActorName { get; set; } = string.Empty;

    [JsonPropertyName("action")]
    public string Action { get; set; } = string.Empty;

    [JsonPropertyName("cardTitle")]
    public string? CardTitle { get; set; }

    [JsonPropertyName("fromList")]
    public string? FromList { get; set; }

    [JsonPropertyName("toList")]
    public string? ToList { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
