using System.Text.Json.Serialization;

namespace MudbaseShowcase.Kanban.Models;

/// <summary>
/// Maps a document from the "lists" Mudbase collection (a board column). Field names mirror the
/// reference Next.js implementation's `lists` schema exactly (see web/src/types/list.ts) so this
/// is a faithful port, not a reinterpretation.
/// </summary>
public sealed class ListDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("boardId")]
    public string BoardId { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    /// <summary>Ascending order within the board row. Reordering swaps this value between two adjacent lists rather than renumbering the whole board.</summary>
    [JsonPropertyName("position")]
    public int Position { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
