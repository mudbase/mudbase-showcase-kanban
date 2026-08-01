package dev.mudbase.showcase.kanban.service;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.config.MudbaseProperties;
import dev.mudbase.showcase.kanban.domain.BoardList;
import dev.mudbase.showcase.kanban.mudbase.DocumentMapper;
import dev.mudbase.showcase.kanban.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.kanban.support.ForbiddenActionException;
import dev.mudbase.showcase.kanban.support.RoleSupport;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `lists` collection (board columns). Every mutation here is owner-only,
 * checked with {@link RoleSupport#canManageLists} before any Mudbase call is attempted - the
 * app's own independent enforcement layer described in {@link ForbiddenActionException}.
 */
@Service
public class ListService {

  private static final int MAX_LISTS = 100;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final ActivityService activityService;
  private final CardService cardService;

  public ListService(
      MudbaseDataClient dataClient, MudbaseProperties properties, ActivityService activityService, CardService cardService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.activityService = activityService;
    this.cardService = cardService;
  }

  /** All lists for the single shared board, ascending by column order. */
  public List<BoardList> listsForBoard(AuthSession viewer) {
    return dataClient
        .list(viewer.getToken(), properties.getListsCollectionId(), boardFilter(), "position", 1, MAX_LISTS)
        .stream()
        .map(BoardList::fromDocument)
        .sorted(Comparator.comparingInt(BoardList::getPosition))
        .toList();
  }

  /** Owner-only: creates a new column at the end of the board. */
  public BoardList createList(AuthSession actor, String name) {
    requireCanManageLists(actor, "create a list");
    List<BoardList> existing = listsForBoard(actor);
    int nextPosition = existing.isEmpty() ? 0 : existing.get(existing.size() - 1).getPosition() + 1;

    Map<String, Object> body = new LinkedHashMap<>();
    body.put("boardId", properties.getBoardId());
    body.put("name", name);
    body.put("position", nextPosition);
    BoardList created = BoardList.fromDocument(dataClient.create(actor.getToken(), properties.getListsCollectionId(), body));

    activityService.record(actor, "created_list", null, null, name);
    return created;
  }

  /** Owner-only: renames a column. */
  public void renameList(AuthSession actor, String listId, String newName) {
    requireCanManageLists(actor, "rename a list");
    Map<String, Object> current = dataClient.get(actor.getToken(), properties.getListsCollectionId(), listId);
    String oldName = DocumentMapper.getString(current, "name", "Untitled");

    dataClient.update(actor.getToken(), properties.getListsCollectionId(), listId, Map.of("name", newName));
    activityService.record(actor, "renamed_list", null, oldName, newName);
  }

  /** Owner-only: swaps this list's position with the previous one (move left). */
  public void moveLeft(AuthSession actor, String listId) {
    reorder(actor, listId, true);
  }

  /** Owner-only: swaps this list's position with the next one (move right). */
  public void moveRight(AuthSession actor, String listId) {
    reorder(actor, listId, false);
  }

  private void reorder(AuthSession actor, String listId, boolean towardStart) {
    requireCanManageLists(actor, "reorder lists");
    List<BoardList> lists = listsForBoard(actor);
    int index = -1;
    for (int i = 0; i < lists.size(); i++) {
      if (lists.get(i).getId().equals(listId)) {
        index = i;
        break;
      }
    }
    int neighborIndex = towardStart ? index - 1 : index + 1;
    if (index < 0 || neighborIndex < 0 || neighborIndex >= lists.size()) {
      // Already at the edge - the button is disabled client-side for this case too; a no-op is
      // the correct response to a raw request past that disabled state, not an error.
      return;
    }
    BoardList moved = lists.get(index);
    BoardList neighbor = lists.get(neighborIndex);
    dataClient.update(actor.getToken(), properties.getListsCollectionId(), moved.getId(), Map.of("position", neighbor.getPosition()));
    dataClient.update(actor.getToken(), properties.getListsCollectionId(), neighbor.getId(), Map.of("position", moved.getPosition()));
    // List reorder is not logged to the activity feed, matching the reference web app's
    // useReorderList (only create/rename/delete are).
  }

  /**
   * Owner-only: deletes a column and cascades to every card inside it - a list's cards have
   * nowhere else to live once the column is gone, there's no "uncategorized" list to fall back to.
   */
  public void deleteList(AuthSession actor, String listId) {
    requireCanManageLists(actor, "delete a list");
    Map<String, Object> list = dataClient.get(actor.getToken(), properties.getListsCollectionId(), listId);
    String name = DocumentMapper.getString(list, "name", "Untitled");

    cardService.deleteAllInList(actor, listId);
    dataClient.delete(actor.getToken(), properties.getListsCollectionId(), listId);
    activityService.record(actor, "deleted_list", null, name, null);
  }

  private void requireCanManageLists(AuthSession actor, String action) {
    if (!RoleSupport.canManageLists(actor.getRole())) {
      throw new ForbiddenActionException("Only the board owner can " + action + ".");
    }
  }

  private Map<String, Object> boardFilter() {
    return Map.of("boardId", properties.getBoardId());
  }
}
