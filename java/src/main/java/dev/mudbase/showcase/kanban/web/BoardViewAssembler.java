package dev.mudbase.showcase.kanban.web;

import dev.mudbase.showcase.kanban.domain.BoardCard;
import dev.mudbase.showcase.kanban.domain.BoardList;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Assembles the raw {@link BoardList}/{@link BoardCard} rows Mudbase returns into the
 * per-template view models {@code index.html} needs - which neighbor card/list a "move up"/"move
 * down"/"move left"/"move right" button should target (so it can be disabled at the edges), and
 * which other lists a card's "Move to…" select should offer. Keeping this computation in one
 * place instead of inline Thymeleaf expressions keeps the template simple and this logic unit
 * testable.
 */
@Component
public class BoardViewAssembler {

  /** One card row plus its up/down neighbor targets (null at an edge, so the button is disabled). */
  public record CardRow(BoardCard card, String prevCardId, String nextCardId) {}

  /** One column: its list, its cards (already positioned), left/right neighbor targets, and every other list (for "Move to…"). */
  public record ListColumn(BoardList list, List<CardRow> cards, String prevListId, String nextListId, List<BoardList> otherLists) {}

  /** The fully assembled board, ready for the template. */
  public record BoardViewModel(List<ListColumn> columns, boolean hasLists) {}

  public BoardViewModel assemble(List<BoardList> lists, List<BoardCard> cards) {
    Map<String, List<BoardCard>> byListId = new LinkedHashMap<>();
    for (BoardCard card : cards) {
      byListId.computeIfAbsent(card.getListId(), k -> new ArrayList<>()).add(card);
    }

    List<ListColumn> columns = new ArrayList<>();
    for (int i = 0; i < lists.size(); i++) {
      BoardList list = lists.get(i);
      List<BoardCard> inList = byListId.getOrDefault(list.getId(), List.of());
      List<CardRow> rows = new ArrayList<>();
      for (int c = 0; c < inList.size(); c++) {
        String prevId = c > 0 ? inList.get(c - 1).getId() : null;
        String nextId = c < inList.size() - 1 ? inList.get(c + 1).getId() : null;
        rows.add(new CardRow(inList.get(c), prevId, nextId));
      }
      String prevListId = i > 0 ? lists.get(i - 1).getId() : null;
      String nextListId = i < lists.size() - 1 ? lists.get(i + 1).getId() : null;
      List<BoardList> otherLists = lists.stream().filter(l -> !l.getId().equals(list.getId())).toList();
      columns.add(new ListColumn(list, rows, prevListId, nextListId, otherLists));
    }
    return new BoardViewModel(columns, !lists.isEmpty());
  }
}
