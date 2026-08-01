package dev.mudbase.showcase.kanban.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** The "Move to…" dropdown's submitted target list id - must be a real 24-hex ObjectId. */
public class MoveCardRequest {

  @NotBlank(message = "Choose a list to move to")
  @Pattern(regexp = "^[0-9a-fA-F]{24}$", message = "Invalid list")
  private String toListId = "";

  public String getToListId() {
    return toListId;
  }

  public void setToListId(String toListId) {
    this.toListId = toListId;
  }
}
