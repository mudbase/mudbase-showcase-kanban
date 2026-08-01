namespace MudbaseShowcase.Kanban.Models;

/// <summary>One board column plus its cards, already sorted by `position` - built once per page load in Pages/Index.cshtml.cs, consumed by Pages/Shared/_ListColumn.cshtml.</summary>
public sealed class BoardListViewModel
{
    public required ListDocument List { get; init; }
    public required IReadOnlyList<CardDocument> Cards { get; init; }
}
