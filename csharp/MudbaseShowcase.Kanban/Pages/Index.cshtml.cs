using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Services;

namespace MudbaseShowcase.Kanban.Pages;

/// <summary>
/// The board: lists (columns) + cards, role-aware CRUD, cross-list move, in-list reorder, and an
/// activity-log entry per create/move/delete. Mirrors web/src/components/board/BoardView.tsx plus
/// its useLists.ts/useCards.ts mutation hooks. Every mutating handler re-checks the caller's role
/// server-side via <see cref="Rbac"/> before calling Mudbase at all - this is defense-in-depth on
/// top of (not a replacement for) Mudbase's own collection permissions, which are the real
/// enforcement boundary (see plan/build-plan.md's live smoke test).
/// </summary>
public sealed class IndexModel : PageModel
{
    private readonly ListsService _lists;
    private readonly CardsService _cards;
    private readonly ActivityService _activity;
    private readonly MudbaseSessionAccessor _session;

    public IndexModel(ListsService lists, CardsService cards, ActivityService activity, MudbaseSessionAccessor session)
    {
        _lists = lists;
        _cards = cards;
        _activity = activity;
        _session = session;
    }

    public IReadOnlyList<BoardListViewModel> Lists { get; private set; } = Array.Empty<BoardListViewModel>();

    public IReadOnlyDictionary<string, int> NextPositionByListId { get; private set; } = new Dictionary<string, int>();

    public int NextListPosition { get; private set; }

    public string? LoadError { get; private set; }

    [TempData]
    public string? FlashError { get; set; }

    private string? CurrentRole => _session.CurrentUser?.CustomRole;

    public bool CanManageListsFlag => Rbac.CanManageLists(CurrentRole);

    public bool CanManageCardsFlag => Rbac.CanManageCards(CurrentRole);

    public bool IsReadOnlyFlag => Rbac.IsReadOnly(CurrentRole);

    public string RoleLabelText => Rbac.RoleLabel(CurrentRole);

    public async Task OnGetAsync(CancellationToken cancellationToken) => await LoadBoardAsync(cancellationToken);

    public async Task<IActionResult> OnPostCreateListAsync(string name, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageLists(user.CustomRole))
        {
            FlashError = "Only the board owner can add lists.";
            return RedirectToPage();
        }

        string trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length is 0 or > 60)
        {
            FlashError = "List name must be 1-60 characters.";
            return RedirectToPage();
        }

        try
        {
            MudbaseListResult<ListDocument> existing = await _lists.ListForBoardAsync(cancellationToken);
            int position = existing.Items.Count == 0 ? 0 : existing.Items.Max(l => l.Position) + 1;
            await _lists.CreateAsync(trimmed, position, cancellationToken);
            await _activity.LogAsync(user.Id, user.DisplayName, ActivityActions.CreatedList, null, null, trimmed, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't create the list. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRenameListAsync(string listId, string newName, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageLists(user.CustomRole))
        {
            FlashError = "Only the board owner can rename lists.";
            return RedirectToPage();
        }

        string trimmed = (newName ?? string.Empty).Trim();
        if (trimmed.Length is 0 or > 60)
        {
            FlashError = "List name must be 1-60 characters.";
            return RedirectToPage();
        }

        try
        {
            ListDocument? list = await _lists.GetAsync(listId, cancellationToken);
            if (list is not null && list.Name != trimmed)
            {
                await _lists.RenameAsync(listId, trimmed, cancellationToken);
                await _activity.LogAsync(user.Id, user.DisplayName, ActivityActions.RenamedList, null, list.Name, trimmed, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't rename the list. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostReorderListAsync(string listId, string neighborListId, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageLists(user.CustomRole))
        {
            FlashError = "Only the board owner can reorder lists.";
            return RedirectToPage();
        }

        try
        {
            ListDocument? a = await _lists.GetAsync(listId, cancellationToken);
            ListDocument? b = await _lists.GetAsync(neighborListId, cancellationToken);
            if (a is not null && b is not null)
            {
                await _lists.SwapPositionsAsync(a, b, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't reorder the list. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostDeleteListAsync(string listId, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageLists(user.CustomRole))
        {
            FlashError = "Only the board owner can delete lists.";
            return RedirectToPage();
        }

        try
        {
            ListDocument? list = await _lists.GetAsync(listId, cancellationToken);
            if (list is not null)
            {
                MudbaseListResult<CardDocument> allCards = await _cards.ListForBoardAsync(cancellationToken);
                foreach (CardDocument card in allCards.Items.Where(c => c.ListId == listId))
                {
                    await _cards.DeleteAsync(card.Id, cancellationToken);
                }

                await _lists.DeleteAsync(listId, cancellationToken);
                await _activity.LogAsync(user.Id, user.DisplayName, ActivityActions.DeletedList, null, list.Name, null, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't delete the list. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostCreateCardAsync(
        string listId, string title, string? description, string? assigneeName, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageCards(user.CustomRole))
        {
            FlashError = "Only the owner or a member can add cards.";
            return RedirectToPage();
        }

        string trimmedTitle = (title ?? string.Empty).Trim();
        if (trimmedTitle.Length is 0 or > 120)
        {
            FlashError = "Card title must be 1-120 characters.";
            return RedirectToPage();
        }

        string? trimmedDescription = description?.Trim();
        string? trimmedAssignee = assigneeName?.Trim();

        try
        {
            ListDocument? list = await _lists.GetAsync(listId, cancellationToken);
            if (list is null)
            {
                FlashError = "That list no longer exists.";
                return RedirectToPage();
            }

            MudbaseListResult<CardDocument> allCards = await _cards.ListForBoardAsync(cancellationToken);
            List<CardDocument> inList = allCards.Items.Where(c => c.ListId == listId).ToList();
            int position = inList.Count == 0 ? 0 : inList.Max(c => c.Position) + 1;

            await _cards.CreateAsync(listId, trimmedTitle, trimmedDescription, trimmedAssignee, user.Id, user.DisplayName, position, cancellationToken);
            await _activity.LogAsync(user.Id, user.DisplayName, ActivityActions.CreatedCard, trimmedTitle, null, list.Name, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't create the card. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostEditCardAsync(
        string cardId, string title, string? description, string? assigneeName, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageCards(user.CustomRole))
        {
            FlashError = "Only the owner or a member can edit cards.";
            return RedirectToPage();
        }

        string trimmedTitle = (title ?? string.Empty).Trim();
        if (trimmedTitle.Length is 0 or > 120)
        {
            FlashError = "Card title must be 1-120 characters.";
            return RedirectToPage();
        }

        string? trimmedDescription = description?.Trim();
        string? trimmedAssignee = assigneeName?.Trim();

        if (trimmedDescription is { Length: > 2000 })
        {
            FlashError = "Description must be under 2000 characters.";
            return RedirectToPage();
        }

        if (trimmedAssignee is { Length: > 80 })
        {
            FlashError = "Assignee name must be under 80 characters.";
            return RedirectToPage();
        }

        try
        {
            await _cards.UpdateDetailsAsync(cardId, trimmedTitle, trimmedDescription, trimmedAssignee, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't update the card. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostDeleteCardAsync(string cardId, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageCards(user.CustomRole))
        {
            FlashError = "Only the owner or a member can delete cards.";
            return RedirectToPage();
        }

        try
        {
            CardDocument? card = await _cards.GetAsync(cardId, cancellationToken);
            if (card is not null)
            {
                ListDocument? list = await _lists.GetAsync(card.ListId, cancellationToken);
                await _cards.DeleteAsync(cardId, cancellationToken);
                await _activity.LogAsync(user.Id, user.DisplayName, ActivityActions.DeletedCard, card.Title, list?.Name, null, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't delete the card. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostMoveCardAsync(string cardId, string toListId, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageCards(user.CustomRole))
        {
            FlashError = "Only the owner or a member can move cards.";
            return RedirectToPage();
        }

        try
        {
            CardDocument? card = await _cards.GetAsync(cardId, cancellationToken);
            ListDocument? toList = await _lists.GetAsync(toListId, cancellationToken);
            if (card is not null && toList is not null)
            {
                ListDocument? fromList = await _lists.GetAsync(card.ListId, cancellationToken);
                MudbaseListResult<CardDocument> allCards = await _cards.ListForBoardAsync(cancellationToken);
                List<CardDocument> inTarget = allCards.Items.Where(c => c.ListId == toListId).ToList();
                int position = inTarget.Count == 0 ? 0 : inTarget.Max(c => c.Position) + 1;

                await _cards.MoveToListAsync(cardId, toListId, position, cancellationToken);
                await _activity.LogAsync(
                    user.Id, user.DisplayName, ActivityActions.Moved, card.Title, fromList?.Name, toList.Name, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't move the card. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostReorderCardAsync(string cardId, string neighborCardId, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is null) return RedirectToPage("/Login", new { ReturnUrl = "/" });
        if (!Rbac.CanManageCards(user.CustomRole))
        {
            FlashError = "Only the owner or a member can reorder cards.";
            return RedirectToPage();
        }

        try
        {
            CardDocument? a = await _cards.GetAsync(cardId, cancellationToken);
            CardDocument? b = await _cards.GetAsync(neighborCardId, cancellationToken);
            if (a is not null && b is not null)
            {
                ListDocument? list = await _lists.GetAsync(a.ListId, cancellationToken);
                await _cards.SwapPositionsAsync(a, b, cancellationToken);
                await _activity.LogAsync(
                    user.Id, user.DisplayName, ActivityActions.Moved, a.Title, list?.Name, list?.Name, cancellationToken);
            }
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't reorder the card. (" + ex.Message + ")";
        }

        return RedirectToPage();
    }

    private async Task LoadBoardAsync(CancellationToken cancellationToken)
    {
        try
        {
            MudbaseListResult<ListDocument> listsResult = await _lists.ListForBoardAsync(cancellationToken);
            MudbaseListResult<CardDocument> cardsResult = await _cards.ListForBoardAsync(cancellationToken);

            List<ListDocument> sortedLists = listsResult.Items.OrderBy(l => l.Position).ToList();
            ILookup<string, CardDocument> cardsByList = cardsResult.Items.ToLookup(c => c.ListId);

            Lists = sortedLists
                .Select(list => new BoardListViewModel
                {
                    List = list,
                    Cards = cardsByList[list.Id].OrderBy(c => c.Position).ToList(),
                })
                .ToList();

            Dictionary<string, int> nextPositions = new();
            foreach (BoardListViewModel vm in Lists)
            {
                nextPositions[vm.List.Id] = vm.Cards.Count == 0 ? 0 : vm.Cards.Max(c => c.Position) + 1;
            }

            NextPositionByListId = nextPositions;
            NextListPosition = sortedLists.Count == 0 ? 0 : sortedLists.Max(l => l.Position) + 1;
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load the board right now. Try refreshing. (" + ex.Message + ")";
        }
    }
}
