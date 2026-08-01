using System.Text.Json.Serialization;

namespace MudbaseShowcase.Kanban.Models;

/// <summary>
/// Maps a document from the "cards" Mudbase collection. Field names mirror the reference Next.js
/// implementation's `cards` schema exactly (see web/src/types/card.ts). `AssigneeId`/`AssigneeName`
/// are nullable rather than merely optional - `null` is a real, explicitly-cleared state (see
/// Services/CardsService.cs's UpdateDetailsAsync), distinct from the field never having been set.
/// `AssigneeId` is schema-validated server-side as an ObjectId reference - a free-typed assignee
/// name is converted to a deterministic pseudo-ObjectId before being sent (see Services/PseudoObjectId.cs).
/// </summary>
public sealed class CardDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("boardId")]
    public string BoardId { get; set; } = string.Empty;

    [JsonPropertyName("listId")]
    public string ListId { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    /// <summary>Ascending order within its column.</summary>
    [JsonPropertyName("position")]
    public int Position { get; set; }

    [JsonPropertyName("assigneeId")]
    public string? AssigneeId { get; set; }

    [JsonPropertyName("assigneeName")]
    public string? AssigneeName { get; set; }

    [JsonPropertyName("createdById")]
    public string CreatedById { get; set; } = string.Empty;

    [JsonPropertyName("createdByName")]
    public string CreatedByName { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
