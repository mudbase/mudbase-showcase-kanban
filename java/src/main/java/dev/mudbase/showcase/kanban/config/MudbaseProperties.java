package dev.mudbase.showcase.kanban.config;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Every ID this app needs to talk to a provisioned Mudbase project. See java/.env.example for the
 * full list and where each value comes from. {@code boardId} is not a secret - it is the id of
 * the single document in a small `boards` collection, used as a constant everywhere a `boardId`
 * field is needed (this is a single-board demo, not multi-tenant) precisely because Mudbase's
 * query sanitizer validates any field ending in `Id` as a real 24-hex-char ObjectId - a plain
 * slug like "main-board" is rejected server-side. See ../web/plan/build-plan.md "Real platform
 * finding" for the full story.
 */
@ConfigurationProperties(prefix = "mudbase")
public class MudbaseProperties {

  private String baseUrl;
  private String projectId;
  private String listsCollectionId;
  private String cardsCollectionId;
  private String activityCollectionId;
  private String boardId;

  @PostConstruct
  void validate() {
    requireNonBlank(projectId, "mudbase.project-id (MUDBASE_PROJECT_ID)");
    requireNonBlank(listsCollectionId, "mudbase.lists-collection-id (MUDBASE_LISTS_COLLECTION_ID)");
    requireNonBlank(cardsCollectionId, "mudbase.cards-collection-id (MUDBASE_CARDS_COLLECTION_ID)");
    requireNonBlank(activityCollectionId, "mudbase.activity-collection-id (MUDBASE_ACTIVITY_COLLECTION_ID)");
    requireNonBlank(boardId, "mudbase.board-id (MUDBASE_BOARD_ID)");
    if (!boardId.matches("^[0-9a-fA-F]{24}$")) {
      throw new IllegalStateException(
          "mudbase.board-id (MUDBASE_BOARD_ID) must be a 24-hex-character ObjectId, got: " + boardId);
    }
  }

  private static void requireNonBlank(String value, String name) {
    if (value == null || value.isBlank()) {
      throw new IllegalStateException("Missing required configuration value: " + name);
    }
  }

  public String getBaseUrl() {
    return baseUrl;
  }

  public void setBaseUrl(String baseUrl) {
    this.baseUrl = baseUrl;
  }

  public String getProjectId() {
    return projectId;
  }

  public void setProjectId(String projectId) {
    this.projectId = projectId;
  }

  public String getListsCollectionId() {
    return listsCollectionId;
  }

  public void setListsCollectionId(String listsCollectionId) {
    this.listsCollectionId = listsCollectionId;
  }

  public String getCardsCollectionId() {
    return cardsCollectionId;
  }

  public void setCardsCollectionId(String cardsCollectionId) {
    this.cardsCollectionId = cardsCollectionId;
  }

  public String getActivityCollectionId() {
    return activityCollectionId;
  }

  public void setActivityCollectionId(String activityCollectionId) {
    this.activityCollectionId = activityCollectionId;
  }

  public String getBoardId() {
    return boardId;
  }

  public void setBoardId(String boardId) {
    this.boardId = boardId;
  }
}
