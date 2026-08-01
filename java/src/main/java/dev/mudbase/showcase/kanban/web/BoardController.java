package dev.mudbase.showcase.kanban.web;

import dev.mudbase.showcase.kanban.auth.AuthSession;
import dev.mudbase.showcase.kanban.auth.SessionAuthService;
import dev.mudbase.showcase.kanban.domain.BoardCard;
import dev.mudbase.showcase.kanban.domain.BoardList;
import dev.mudbase.showcase.kanban.service.CardService;
import dev.mudbase.showcase.kanban.service.ListService;
import dev.mudbase.showcase.kanban.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * The board page (`GET /`) - lists in column order, each list's cards in position order. Every
 * mutation (list CRUD, card CRUD, moves) lives in {@link ListController}/{@link CardController};
 * this controller only assembles the read model via {@link BoardViewAssembler}.
 */
@Controller
public class BoardController {

  private final ListService listService;
  private final CardService cardService;
  private final BoardViewAssembler boardViewAssembler;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public BoardController(
      ListService listService,
      CardService cardService,
      BoardViewAssembler boardViewAssembler,
      ViewModelHelper viewModelHelper,
      SessionAuthService sessionAuthService) {
    this.listService = listService;
    this.cardService = cardService;
    this.boardViewAssembler = boardViewAssembler;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @GetMapping("/")
  public String board(Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession viewer = sessionAuthService.current(session).orElseThrow(IllegalStateException::new);

    List<BoardList> lists = listService.listsForBoard(viewer);
    List<BoardCard> cards = cardService.cardsForBoard(viewer);
    BoardViewAssembler.BoardViewModel board = boardViewAssembler.assemble(lists, cards);

    model.addAttribute("board", board);
    return "index";
  }
}
