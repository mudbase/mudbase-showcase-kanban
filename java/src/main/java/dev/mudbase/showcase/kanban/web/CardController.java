package dev.mudbase.showcase.kanban.web;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.auth.SessionAuthService;
import dev.mudbase.showcase.kanban.service.CardService;
import dev.mudbase.showcase.kanban.web.dto.CardFormRequest;
import dev.mudbase.showcase.kanban.web.dto.MoveCardRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Owner/member card management: create, edit, delete, move to another column, and reorder
 * (move up/down) within a column. Every handler is gated by {@link AuthGateInterceptor} and then
 * by {@code CardService}'s own {@code RoleSupport.canManageCards} check, which throws {@link
 * dev.mudbase.showcase.kanban.support.ForbiddenActionException} for a {@code viewer} - this app's
 * own server-side enforcement, independent of the Thymeleaf UI hiding these forms for viewers.
 */
@Controller
public class CardController {

  private final CardService cardService;
  private final SessionAuthService sessionAuthService;

  public CardController(CardService cardService, SessionAuthService sessionAuthService) {
    this.cardService = cardService;
    this.sessionAuthService = sessionAuthService;
  }

  @PostMapping("/cards")
  public String create(
      @RequestParam String listId,
      @Valid @ModelAttribute("cardFormRequest") CardFormRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/";
    }
    AuthSession actor = currentUser(session);
    cardService.createCard(actor, listId, form.getTitle().trim(), blankToNull(form.getDescription()), blankToNull(form.getAssigneeName()));
    return "redirect:/";
  }

  @PostMapping("/cards/{id}/edit")
  public String edit(
      @PathVariable String id,
      @Valid @ModelAttribute("cardFormRequest") CardFormRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/";
    }
    cardService.updateCard(currentUser(session), id, form.getTitle().trim(), form.getDescription(), form.getAssigneeName());
    return "redirect:/";
  }

  @PostMapping("/cards/{id}/delete")
  public String delete(@PathVariable String id, HttpSession session) {
    cardService.deleteCard(currentUser(session), id);
    return "redirect:/";
  }

  @PostMapping("/cards/{id}/move")
  public String move(
      @PathVariable String id,
      @Valid @ModelAttribute("moveCardRequest") MoveCardRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/";
    }
    cardService.moveCardToList(currentUser(session), id, form.getToListId());
    return "redirect:/";
  }

  @PostMapping("/cards/{id}/move-up")
  public String moveUp(@PathVariable String id, HttpSession session) {
    cardService.moveUp(currentUser(session), id);
    return "redirect:/";
  }

  @PostMapping("/cards/{id}/move-down")
  public String moveDown(@PathVariable String id, HttpSession session) {
    cardService.moveDown(currentUser(session), id);
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

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value;
  }
}
