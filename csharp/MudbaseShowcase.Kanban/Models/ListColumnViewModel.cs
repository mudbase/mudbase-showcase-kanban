namespace MudbaseShowcase.Kanban.Models;

/// <summary>Everything one board column needs to render itself and its cards - mirrors web/src/components/board/ListColumn.tsx's props.</summary>
public sealed class ListColumnViewModel
{
    public required BoardListViewModel Column { get; init; }

    /// <summary>The list immediately to the left, if any - lets the "move left" button target the correct neighbor without a client-side query.</summary>
    public string? PrevListId { get; init; }

    /// <summary>The list immediately to the right, if any.</summary>
    public string? NextListId { get; init; }

    /// <summary>Every column on the board, including this one - needed so each card's "Move to..." dropdown can list every *other* column.</summary>
    public required IReadOnlyList<BoardListViewModel> AllLists { get; init; }

    /// <summary>Next available `position` for a new or moved-in card, per target list id.</summary>
    public required IReadOnlyDictionary<string, int> NextPositionByListId { get; init; }

    public bool CanManageLists { get; init; }
    public bool CanManageCards { get; init; }
}
