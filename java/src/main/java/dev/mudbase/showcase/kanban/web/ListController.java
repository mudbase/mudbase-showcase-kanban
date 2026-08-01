package dev.mudbase.showcase.kanban.web;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.auth.SessionAuthService;
import dev.mudbase.showcase.kanban.service.ListService;
import dev.mudbase.showcase.kanban.web.dto.CreateListRequest;
import dev.mudbase.showcase.kanban.web.dto.RenameListRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Owner-only column management: create, rename, delete, and reorder (move left/right) board
 * lists. Every handler is gated by {@link AuthGateInterceptor} (so {@code viewer} must be
 * signed-in first) and then by {@code ListService}'s own {@code RoleSupport.canManageLists}
 * check, which throws {@link dev.mudbase.showcase.kanban.support.ForbiddenActionException} for a
 * non-owner - this app's own server-side enforcement, independent of the Thymeleaf UI hiding
 * these forms for anyone but the owner.
 */
@Controller
public class ListController {

  private final ListService listService;
  private final SessionAuthService sessionAuthService;

  public ListController(ListService listService, SessionAuthService sessionAuthService) {
    this.listService = listService;
    this.sessionAuthService = sessionAuthService;
  }

  @PostMapping("/lists")
  public String create(
      @Valid @ModelAttribute("createListRequest") CreateListRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/";
    }
    listService.createList(currentUser(session), form.getName().trim());
    return "redirect:/";
  }

  @PostMapping("/lists/{id}/rename")
  public String rename(
      @PathVariable String id,
      @Valid @ModelAttribute("renameListRequest") RenameListRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/";
    }
    listService.renameList(currentUser(session), id, form.getName().trim());
    return "redirect:/";
  }

  @PostMapping("/lists/{id}/delete")
  public String delete(@PathVariable String id, HttpSession session) {
    listService.deleteList(currentUser(session), id);
    return "redirect:/";
  }

  @PostMapping("/lists/{id}/move-left")
  public String moveLeft(@PathVariable String id, HttpSession session) {
    listService.moveLeft(currentUser(session), id);
    return "redirect:/";
  }

  @PostMapping("/lists/{id}/move-right")
  public String moveRight(@PathVariable String id, HttpSession session) {
    listService.moveRight(currentUser(session), id);
    return "redirect:/";
  }

  private AuthSession currentUser(HttpSession session) {
    return sessionAuthService.current(session).orElseThrow(IllegalStateException::new);
  }

  private String firstError(BindingResult bindingResult) {
    return bindingResult.getFieldErrors().stream()
        .findFirst()
        .map(error -> error.getDefaultMessage())
        .orElse("Invalid input.");
  }
}
