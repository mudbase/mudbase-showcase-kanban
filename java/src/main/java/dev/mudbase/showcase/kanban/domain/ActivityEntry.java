package dev.mudbase.showcase.kanban.domain;

import dev.mudbase.showcase.kanban.mudbase.DocumentMapper;
import dev.mudbase.showcase.kanban.support.Formatting;
import java.util.Map;

/**
 * Mirrors one row of the `activity` collection. {@code action} values written by this app:
 * {@code created_card}, {@code moved} (covers both cross-list moves and same-list reorders),
 * {@code deleted_card}, {@code created_list}, {@code renamed_list}, {@code deleted_list} - matches
 * the reference web app's `ActivityAction` union exactly (see ../web/src/types/activity.ts).
 */
public class ActivityEntry {

  private final String id;
  private final String actorName;
  private final String action;
  private final String cardTitle;
  private final String fromList;
  private final String toList;
  private final String createdAt;

  private ActivityEntry(
      String id, String actorName, String action, String cardTitle, String fromList, String toList, String createdAt) {
    this.id = id;
    this.actorName = actorName;
    this.action = action;
    this.cardTitle = cardTitle;
    this.fromList = fromList;
    this.toList = toList;
    this.createdAt = createdAt;
  }

  public static ActivityEntry fromDocument(Map<String, Object> doc) {
    return new ActivityEntry(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "actorName", "Someone"),
        DocumentMapper.getString(doc, "action", ""),
        DocumentMapper.getString(doc, "cardTitle"),
        DocumentMapper.getString(doc, "fromList"),
        DocumentMapper.getString(doc, "toList"),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getCreatedAt() {
    return createdAt;
  }

  public String getFormattedCreatedAt() {
    return Formatting.formatDate(createdAt);
  }

  /** Renders this row as a plain, readable sentence for the feed - mirrors the reference web
   * app's `describeActivity` (src/lib/activity-text.ts) exactly. */
  public String getDescription() {
    String who = actorName != null && !actorName.isBlank() ? actorName : "Someone";
    String card = cardTitle != null && !cardTitle.isBlank() ? cardTitle : "a card";
    return switch (action) {
      case "created_card" -> who + " created card \"" + (cardTitle != null ? cardTitle : "Untitled") + "\" in "
          + (toList != null ? toList : "a list");
      case "moved" -> {
        if (fromList != null && fromList.equals(toList)) {
          yield who + " reordered \"" + card + "\" within " + toList;
        }
        yield who + " moved \"" + card + "\" from " + (fromList != null ? fromList : "?") + " to "
            + (toList != null ? toList : "?");
      }
      case "deleted_card" -> who + " deleted card \"" + (cardTitle != null ? cardTitle : "Untitled") + "\" from "
          + (fromList != null ? fromList : "a list");
      case "created_list" -> who + " created list \"" + (toList != null ? toList : "Untitled") + "\"";
      case "renamed_list" -> who + " renamed list \"" + (fromList != null ? fromList : "?") + "\" to \""
          + (toList != null ? toList : "?") + "\"";
      case "deleted_list" -> who + " deleted list \"" + (fromList != null ? fromList : "Untitled") + "\"";
      default -> who + " did something on the board";
    };
  }
}
