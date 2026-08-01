namespace MudbaseShowcase.Kanban.Models;

/// <summary>Everything one card needs to render itself - mirrors web/src/components/board/CardItem.tsx's props.</summary>
public sealed class CardItemViewModel
{
    public required CardDocument Card { get; init; }
    public required BoardListViewModel CurrentList { get; init; }

    /// <summary>Every column except the one this card is currently in - populates the "Move to..." dropdown.</summary>
    public required IReadOnlyList<BoardListViewModel> OtherLists { get; init; }

    public required IReadOnlyDictionary<string, int> NextPositionByListId { get; init; }

    /// <summary>The card immediately above this one in the same column, if any.</summary>
    public string? PrevCardId { get; init; }

    /// <summary>The card immediately below this one in the same column, if any.</summary>
    public string? NextCardId { get; init; }

    public bool CanManage { get; init; }
}
