package dev.mudbase.showcase.kanban.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Shared shape for both "create card" and "edit card" forms - title/description/assignee caps
 * match the reference web app's zod schema exactly (title 120, description 2000). {@code
 * assigneeName} is a free-typed display name, converted to a pseudo-ObjectId server-side (see
 * {@code dev.mudbase.showcase.kanban.support.PseudoObjectId}) - blank clears the assignee.
 */
public class CardFormRequest {

  @NotBlank(message = "Card title is required")
  @Size(max = 120, message = "Keep the title under 120 characters")
  private String title = "";

  @Size(max = 2000, message = "Keep the description under 2000 characters")
  private String description = "";

  @Size(max = 80, message = "Keep the assignee name under 80 characters")
  private String assigneeName = "";

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public String getDescription() {
    return description;
  }

  public void setDescription(String description) {
    this.description = description;
  }

  public String getAssigneeName() {
    return assigneeName;
  }

  public void setAssigneeName(String assigneeName) {
    this.assigneeName = assigneeName;
  }
}
