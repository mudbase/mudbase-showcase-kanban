package dev.mudbase.showcase.kanban.web;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.auth.SessionAuthService;
import dev.mudbase.showcase.kanban.domain.ActivityEntry;
import dev.mudbase.showcase.kanban.service.ActivityService;
import dev.mudbase.showcase.kanban.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/** Full reverse-chronological activity feed for the shared board (`GET /activity`). */
@Controller
public class ActivityController {

  private final ActivityService activityService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public ActivityController(ActivityService activityService, ViewModelHelper viewModelHelper, SessionAuthService sessionAuthService) {
    this.activityService = activityService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @GetMapping("/activity")
  public String feed(Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession viewer = sessionAuthService.current(session).orElseThrow(IllegalStateException::new);
    List<ActivityEntry> entries = activityService.feed(viewer);
    model.addAttribute("entries", entries);
    return "activity/feed";
  }
}
