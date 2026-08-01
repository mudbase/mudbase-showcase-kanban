package dev.mudbase.showcase.kanban.service;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.config.MudbaseProperties;
import dev.mudbase.showcase.kanban.domain.BoardCard;
import dev.mudbase.showcase.kanban.mudbase.DocumentMapper;
import dev.mudbase.showcase.kanban.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.kanban.support.ForbiddenActionException;
import dev.mudbase.showcase.kanban.support.PseudoObjectId;
import dev.mudbase.showcase.kanban.support.RoleSupport;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `cards` collection. Every mutation here is owner/member-only, checked with
 * {@link RoleSupport#canManageCards} before any Mudbase call is attempted - see {@link
 * ForbiddenActionException}.
 */
@Service
public class CardService {

  private static final int MAX_CARDS = 500;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final ActivityService activityService;

  public CardService(MudbaseDataClient dataClient, MudbaseProperties properties, ActivityService activityService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.activityService = activityService;
  }

  /** All cards for the single shared board, ascending by in-column order. Group by listId at the call site. */
  public List<BoardCard> cardsForBoard(AuthSession viewer) {
    return dataClient
        .list(viewer.getToken(), properties.getCardsCollectionId(), boardFilter(), "position", 1, MAX_CARDS)
        .stream()
        .map(BoardCard::fromDocument)
        .sorted(Comparator.comparingInt(BoardCard::getPosition))
        .toList();
  }

  private List<BoardCard> cardsInList(AuthSession actor, String listId) {
    return dataClient
        .list(
            actor.getToken(),
            properties.getCardsCollectionId(),
            Map.of("boardId", properties.getBoardId(), "listId", listId),
            "position",
            1,
            MAX_CARDS)
        .stream()
        .map(BoardCard::fromDocument)
        .sorted(Comparator.comparingInt(BoardCard::getPosition))
        .toList();
  }

  /** Owner/member: creates a new card at the end of a column. */
  public BoardCard createCard(AuthSession actor, String listId, String title, String description, String assigneeName) {
    requireCanManageCards(actor, "create a card");
    List<BoardCard> inList = cardsInList(actor, listId);
    int nextPosition = inList.isEmpty() ? 0 : inList.get(inList.size() - 1).getPosition() + 1;

    Map<String, Object> body = new LinkedHashMap<>();
    body.put("boardId", properties.getBoardId());
    body.put("listId", listId);
    body.put("title", title);
    body.put("position", nextPosition);
    if (description != null && !description.isBlank()) {
      body.put("description", description);
    }
    if (assigneeName != null && !assigneeName.isBlank()) {
      body.put("assigneeId", PseudoObjectId.generate(assigneeName));
      body.put("assigneeName", assigneeName.trim());
    }
    body.put("createdById", actor.getUserId());
    body.put("createdByName", actor.getDisplayName());

    BoardCard created = BoardCard.fromDocument(dataClient.create(actor.getToken(), properties.getCardsCollectionId(), body));
    activityService.record(actor, "created_card", title, null, resolveListName(actor, listId));
    return created;
  }

  /**
   * Owner/member: edits a card's title/description/assignee in place. Not itself logged to the
   * activity feed - only creation, movement, and deletion are (matches the reference web app's
   * `useUpdateCard`). {@code assigneeId}/{@code assigneeName} are always sent as `null` (never
   * `""`) to clear - Mudbase validates `assigneeId` as an ObjectId reference and rejects an empty
   * string the same way it would an invalid slug (verified live, see ../web/plan/build-plan.md).
   */
  public void updateCard(AuthSession actor, String cardId, String title, String description, String assigneeName) {
    requireCanManageCards(actor, "edit a card");
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("title", title);
    body.put("description", description != null ? description : "");
    if (assigneeName != null && !assigneeName.isBlank()) {
      body.put("assigneeId", PseudoObjectId.generate(assigneeName));
      body.put("assigneeName", assigneeName.trim());
    } else {
      body.put("assigneeId", null);
      body.put("assigneeName", null);
    }
    dataClient.update(actor.getToken(), properties.getCardsCollectionId(), cardId, body);
  }

  /** Owner/member: deletes a card. */
  public void deleteCard(AuthSession actor, String cardId) {
    requireCanManageCards(actor, "delete a card");
    Map<String, Object> card = dataClient.get(actor.getToken(), properties.getCardsCollectionId(), cardId);
    String title = DocumentMapper.getString(card, "title", "Untitled");
    String listId = DocumentMapper.getString(card, "listId");
    String listName = resolveListName(actor, listId);

    dataClient.delete(actor.getToken(), properties.getCardsCollectionId(), cardId);
    activityService.record(actor, "deleted_card", title, listName, null);
  }

  /** Owner-only call path (via ListService#deleteList): removes every card in a list with no activity entry of its own - the list's own deletion entry covers it. */
  void deleteAllInList(AuthSession actor, String listId) {
    for (BoardCard card : cardsInList(actor, listId)) {
      dataClient.delete(actor.getToken(), properties.getCardsCollectionId(), card.getId());
    }
  }

  /**
   * Owner/member: moves a card to a different column, appended to the end of it. Every move
   * writes both `listId` and `position` and appends a `moved` activity entry, per the task spec.
   */
  public void moveCardToList(AuthSession actor, String cardId, String toListId) {
    requireCanManageCards(actor, "move a card");
    Map<String, Object> card = dataClient.get(actor.getToken(), properties.getCardsCollectionId(), cardId);
    String title = DocumentMapper.getString(card, "title", "Untitled");
    String fromListId = DocumentMapper.getString(card, "listId");
    if (toListId.equals(fromListId)) {
      return;
    }
    String fromListName = resolveListName(actor, fromListId);
    String toListName = resolveListName(actor, toListId);
    List<BoardCard> inTarget = cardsInList(actor, toListId);
    int newPosition = inTarget.isEmpty() ? 0 : inTarget.get(inTarget.size() - 1).getPosition() + 1;

    dataClient.update(
        actor.getToken(), properties.getCardsCollectionId(), cardId, Map.of("listId", toListId, "position", newPosition));
    activityService.record(actor, "moved", title, fromListName, toListName);
  }

  /** Owner/member: moves a card one position toward the top of its own column. */
  public void moveUp(AuthSession actor, String cardId) {
    reorderWithinList(actor, cardId, true);
  }

  /** Owner/member: moves a card one position toward the bottom of its own column. */
  public void moveDown(AuthSession actor, String cardId) {
    reorderWithinList(actor, cardId, false);
  }

  /**
   * Reorders a card up/down within its own column by swapping `position` with the adjacent card.
   * Still logs a `moved` activity entry (fromList === toList) per the task's "every
   * move...appends an activity entry" requirement, matching the reference web app's
   * `useReorderCardInList`.
   */
  private void reorderWithinList(AuthSession actor, String cardId, boolean towardStart) {
    requireCanManageCards(actor, "reorder cards");
    Map<String, Object> cardDoc = dataClient.get(actor.getToken(), properties.getCardsCollectionId(), cardId);
    String listId = DocumentMapper.getString(cardDoc, "listId");
    String title = DocumentMapper.getString(cardDoc, "title", "Untitled");
    List<BoardCard> inList = cardsInList(actor, listId);

    int index = -1;
    for (int i = 0; i < inList.size(); i++) {
      if (inList.get(i).getId().equals(cardId)) {
        index = i;
        break;
      }
    }
    int neighborIndex = towardStart ? index - 1 : index + 1;
    if (index < 0 || neighborIndex < 0 || neighborIndex >= inList.size()) {
      // Already at the edge - a no-op, matching the disabled up/down button in the UI.
      return;
    }
    BoardCard moved = inList.get(index);
    BoardCard neighbor = inList.get(neighborIndex);
    dataClient.update(actor.getToken(), properties.getCardsCollectionId(), moved.getId(), Map.of("position", neighbor.getPosition()));
    dataClient.update(actor.getToken(), properties.getCardsCollectionId(), neighbor.getId(), Map.of("position", moved.getPosition()));

    String listName = resolveListName(actor, listId);
    activityService.record(actor, "moved", title, listName, listName);
  }

  private String resolveListName(AuthSession actor, String listId) {
    if (listId == null) {
      return null;
    }
    try {
      Map<String, Object> list = dataClient.get(actor.getToken(), properties.getListsCollectionId(), listId);
      return DocumentMapper.getString(list, "name", "Untitled");
    } catch (RuntimeException e) {
      return "Untitled";
    }
  }

  private void requireCanManageCards(AuthSession actor, String action) {
    if (!RoleSupport.canManageCards(actor.getRole())) {
      throw new ForbiddenActionException("Only the board owner or a member can " + action + ".");
    }
  }

  private Map<String, Object> boardFilter() {
    return Map.of("boardId", properties.getBoardId());
  }
}
