package dev.mudbase.showcase.kanban.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class RenameListRequest {

  @NotBlank(message = "List name is required")
  @Size(max = 60, message = "Keep the list name under 60 characters")
  private String name = "";

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }
}
