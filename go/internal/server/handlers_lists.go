package server

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
)

// filterCardsByList returns the subset of cards whose ListID matches listID - used by
// handleListDelete to find the cards that cascade-delete along with their column.
func filterCardsByList(cards []models.Card, listID string) []models.Card {
	out := make([]models.Card, 0, len(cards))
	for _, c := range cards {
		if c.ListID == listID {
			out = append(out, c)
		}
	}
	return out
}

// listNameMaxLen mirrors the reference web app's AddListForm/ListColumn zod schema
// (../web/plan/build-plan.md: "list names at 60 [chars]").
const listNameMaxLen = 60

// mutationError redirects to path with a message appropriate to err: Mudbase's own collection
// permissions rejecting the write (mbase.IsForbidden - the real RBAC enforcement, independent of
// this app's own requireRole middleware) get a specific, honest message; everything else gets a
// generic one so no internal detail (collection IDs, SDK error shapes) leaks to the page.
func mutationError(w http.ResponseWriter, r *http.Request, path string, err error, genericMessage string) {
	if mbase.IsForbidden(err) {
		redirectWithError(w, r, path, "The server rejected this action: your role doesn't have permission to do that.")
		return
	}
	redirectWithError(w, r, path, genericMessage)
}

// handleListCreate adds a new column at the end of the board. Route already gated by
// requireListManager (owner-only).
func (a *App) handleListCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	if name == "" {
		redirectWithError(w, r, "/", "List name is required.")
		return
	}
	if len(name) > listNameMaxLen {
		redirectWithError(w, r, "/", "Keep the list name under 60 characters.")
		return
	}

	data := sessionFrom(r)
	if _, err := a.lists.Create(r.Context(), data.AccessToken(), data.UserID(), data.DisplayName(), name); err != nil {
		mutationError(w, r, "/", err, "Couldn't create that list. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleListRename renames a column. Route already gated by requireListManager.
func (a *App) handleListRename(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	newName := strings.TrimSpace(r.FormValue("name"))
	if newName == "" {
		redirectWithError(w, r, "/", "List name is required.")
		return
	}
	if len(newName) > listNameMaxLen {
		redirectWithError(w, r, "/", "Keep the list name under 60 characters.")
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	list, err := a.lists.ByID(r.Context(), token, id)
	if err != nil {
		redirectWithError(w, r, "/", "That list couldn't be found.")
		return
	}
	if list.Name == newName {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	if _, err := a.lists.Rename(r.Context(), token, data.UserID(), data.DisplayName(), list, newName); err != nil {
		mutationError(w, r, "/", err, "Couldn't rename that list. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleListReorder swaps a column's position with an adjacent one (left/right move). Route
// already gated by requireListManager. Not itself logged to the activity feed, matching the
// reference web app's useReorderList.
func (a *App) handleListReorder(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	direction := r.FormValue("direction")

	data := sessionFrom(r)
	token := data.AccessToken()

	lists, err := a.lists.All(r.Context(), token)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	index := -1
	for i, l := range lists {
		if l.ID == id {
			index = i
			break
		}
	}
	if index == -1 {
		redirectWithError(w, r, "/", "That list couldn't be found.")
		return
	}

	var neighborIndex int
	switch direction {
	case "left":
		neighborIndex = index - 1
	case "right":
		neighborIndex = index + 1
	default:
		redirectWithError(w, r, "/", "Invalid move direction.")
		return
	}
	if neighborIndex < 0 || neighborIndex >= len(lists) {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	if err := a.lists.Reorder(r.Context(), token, lists[index], lists[neighborIndex]); err != nil {
		mutationError(w, r, "/", err, "Couldn't reorder that list. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleListDelete deletes a column and every card inside it. Route already gated by
// requireListManager.
func (a *App) handleListDelete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	list, err := a.lists.ByID(r.Context(), token, id)
	if err != nil {
		redirectWithError(w, r, "/", "That list couldn't be found.")
		return
	}

	cards, err := a.cards.All(r.Context(), token)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	if err := a.lists.Delete(r.Context(), token, data.UserID(), data.DisplayName(), list, filterCardsByList(cards, list.ID), a.cards); err != nil {
		mutationError(w, r, "/", err, "Couldn't delete that list. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}
