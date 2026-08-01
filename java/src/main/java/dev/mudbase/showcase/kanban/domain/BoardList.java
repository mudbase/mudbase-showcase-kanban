package dev.mudbase.showcase.kanban.domain;

import dev.mudbase.showcase.kanban.mudbase.DocumentMapper;
import java.util.Map;

/** Mirrors one row of the `lists` collection - a single board column. */
public class BoardList {

  private final String id;
  private final String name;
  private final int position;

  private BoardList(String id, String name, int position) {
    this.id = id;
    this.name = name;
    this.position = position;
  }

  public static BoardList fromDocument(Map<String, Object> doc) {
    return new BoardList(DocumentMapper.getId(doc), DocumentMapper.getString(doc, "name", "Untitled"), DocumentMapper.getInt(doc, "position", 0));
  }

  public String getId() {
    return id;
  }

  public String getName() {
    return name;
  }

  public int getPosition() {
    return position;
  }
}
