package dev.mudbase.showcase.kanban.service;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.config.MudbaseProperties;
import dev.mudbase.showcase.kanban.domain.ActivityEntry;
import dev.mudbase.showcase.kanban.mudbase.MudbaseDataClient;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

/** Reads and writes the `activity` collection - the board's audit trail. */
@Service
public class ActivityService {

  private static final int FEED_LIMIT = 200;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;

  public ActivityService(MudbaseDataClient dataClient, MudbaseProperties properties) {
    this.dataClient = dataClient;
    this.properties = properties;
  }

  /** Reverse-chronological activity feed for the shared board. */
  public List<ActivityEntry> feed(AuthSession viewer) {
    return dataClient
        .list(
            viewer.getToken(),
            properties.getActivityCollectionId(),
            Map.of("boardId", properties.getBoardId()),
            "-createdAt",
            1,
            FEED_LIMIT)
        .stream()
        .map(ActivityEntry::fromDocument)
        .sorted(Comparator.comparing(ActivityEntry::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
        .toList();
  }

  /**
   * Appends one row to the activity log. {@code action} is one of {@code created_card}/{@code
   * moved}/{@code deleted_card}/{@code created_list}/{@code renamed_list}/{@code deleted_list} -
   * see {@link ActivityEntry#getDescription()} for how each renders.
   */
  public void record(AuthSession actor, String action, String cardTitle, String fromList, String toList) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("boardId", properties.getBoardId());
    body.put("actorId", actor.getUserId());
    body.put("actorName", actor.getDisplayName());
    body.put("action", action);
    if (cardTitle != null) {
      body.put("cardTitle", cardTitle);
    }
    if (fromList != null) {
      body.put("fromList", fromList);
    }
    if (toList != null) {
      body.put("toList", toList);
    }
    dataClient.create(actor.getToken(), properties.getActivityCollectionId(), body);
  }
}
