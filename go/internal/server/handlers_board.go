package server

import "net/http"

// boardBodyView fetches the current lists+cards and builds the role-aware BoardBodyView shared by
// the full board page and its poll-refreshed fragment.
func (a *App) boardBodyView(r *http.Request) (BoardBodyView, error) {
	data := sessionFrom(r)
	token := data.AccessToken()

	lists, err := a.lists.All(r.Context(), token)
	if err != nil {
		return BoardBodyView{}, err
	}
	cards, err := a.cards.All(r.Context(), token)
	if err != nil {
		return BoardBodyView{}, err
	}

	return buildBoardView(lists, cards, data.Role()), nil
}

// BoardPageData is the / page's content payload.
type BoardPageData struct {
	Base
	BoardBodyView
}

// handleBoard renders the full board page: every list/column and its cards, an owner-only "add
// list" control, and a read-only notice for the viewer role - mirrors the reference web app's
// BoardView.tsx.
func (a *App) handleBoard(w http.ResponseWriter, r *http.Request) {
	board, err := a.boardBodyView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := BoardPageData{
		Base:          a.baseView(r, "Board"),
		BoardBodyView: board,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "board.html", view)
}

// handleBoardFragment renders just the board's list/card body (no layout, no header), polled every
// few seconds by a small inline script on the board page - this app's stand-in for the reference
// web app's Socket.IO `subscribe:collection` realtime feed (useBoardLive): there is no official
// Mudbase Go realtime client, so the board refreshes via polling instead of a push subscription,
// functionally equivalent for this demo (see README "Known limitations").
func (a *App) handleBoardFragment(w http.ResponseWriter, r *http.Request) {
	board, err := a.boardBodyView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	a.renderFragment(w, r, http.StatusOK, "board_fragment.html", board)
}
