package dev.mudbase.showcase.kanban.domain;

import dev.mudbase.showcase.kanban.mudbase.DocumentMapper;
import java.util.Map;

/** Mirrors one row of the `cards` collection. */
public class BoardCard {

  private final String id;
  private final String listId;
  private final String title;
  private final String description;
  private final int position;
  private final String assigneeName;
  private final String createdByName;

  private BoardCard(
      String id, String listId, String title, String description, int position, String assigneeName, String createdByName) {
    this.id = id;
    this.listId = listId;
    this.title = title;
    this.description = description;
    this.position = position;
    this.assigneeName = assigneeName;
    this.createdByName = createdByName;
  }

  public static BoardCard fromDocument(Map<String, Object> doc) {
    return new BoardCard(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "listId"),
        DocumentMapper.getString(doc, "title", "Untitled"),
        DocumentMapper.getString(doc, "description"),
        DocumentMapper.getInt(doc, "position", 0),
        DocumentMapper.getString(doc, "assigneeName"),
        DocumentMapper.getString(doc, "createdByName", "Someone"));
  }

  public String getId() {
    return id;
  }

  public String getListId() {
    return listId;
  }

  public String getTitle() {
    return title;
  }

  public String getDescription() {
    return description;
  }

  public boolean isHasDescription() {
    return description != null && !description.isBlank();
  }

  public int getPosition() {
    return position;
  }

  public String getAssigneeName() {
    return assigneeName;
  }

  public boolean isHasAssignee() {
    return assigneeName != null && !assigneeName.isBlank();
  }

  public String getCreatedByName() {
    return createdByName;
  }
}
