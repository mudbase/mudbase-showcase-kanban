package server

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/store"
)

// Field length caps mirror the reference web app's CardDialog zod schema
// (../web/plan/build-plan.md: "Card titles capped at 120 chars, descriptions at 2000" and
// CardDialog.tsx's assigneeName cap of 80).
const (
	cardTitleMaxLen       = 120
	cardDescriptionMaxLen = 2000
	assigneeNameMaxLen    = 80
)

// handleCardCreate adds a new card at the end of a column. Route already gated by
// requireCardManager (owner/member).
func (a *App) handleCardCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	listID := r.FormValue("listId")
	title := strings.TrimSpace(r.FormValue("title"))
	description := strings.TrimSpace(r.FormValue("description"))
	assigneeName := strings.TrimSpace(r.FormValue("assigneeName"))

	if title == "" {
		redirectWithError(w, r, "/", "Card title is required.")
		return
	}
	if len(title) > cardTitleMaxLen {
		redirectWithError(w, r, "/", "Keep the card title under 120 characters.")
		return
	}
	if len(description) > cardDescriptionMaxLen {
		redirectWithError(w, r, "/", "Keep the description under 2000 characters.")
		return
	}
	if len(assigneeName) > assigneeNameMaxLen {
		redirectWithError(w, r, "/", "Keep the assignee name under 80 characters.")
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	list, err := a.lists.ByID(r.Context(), token, listID)
	if err != nil {
		redirectWithError(w, r, "/", "That list couldn't be found.")
		return
	}

	if _, err := a.cards.Create(r.Context(), token, data.UserID(), data.DisplayName(), store.CreateInput{
		ListID:       listID,
		ListName:     list.Name,
		Title:        title,
		Description:  description,
		AssigneeName: assigneeName,
	}); err != nil {
		mutationError(w, r, "/", err, "Couldn't create that card. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleCardEdit edits a card's title/description/assignee in place. Route already gated by
// requireCardManager. Not itself logged to the activity feed, matching the reference web app's
// useUpdateCard.
func (a *App) handleCardEdit(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	title := strings.TrimSpace(r.FormValue("title"))
	description := strings.TrimSpace(r.FormValue("description"))
	assigneeName := strings.TrimSpace(r.FormValue("assigneeName"))

	if title == "" {
		redirectWithError(w, r, "/", "Card title is required.")
		return
	}
	if len(title) > cardTitleMaxLen {
		redirectWithError(w, r, "/", "Keep the card title under 120 characters.")
		return
	}
	if len(description) > cardDescriptionMaxLen {
		redirectWithError(w, r, "/", "Keep the description under 2000 characters.")
		return
	}
	if len(assigneeName) > assigneeNameMaxLen {
		redirectWithError(w, r, "/", "Keep the assignee name under 80 characters.")
		return
	}

	data := sessionFrom(r)
	if _, err := a.cards.Update(r.Context(), data.AccessToken(), id, store.UpdateInput{
		Title:        title,
		Description:  description,
		AssigneeName: assigneeName,
	}); err != nil {
		mutationError(w, r, "/", err, "Couldn't save those changes. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleCardDelete deletes a card. Route already gated by requireCardManager.
func (a *App) handleCardDelete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	card, err := a.cards.ByID(r.Context(), token, id)
	if err != nil {
		redirectWithError(w, r, "/", "That card couldn't be found.")
		return
	}
	list, err := a.lists.ByID(r.Context(), token, card.ListID)
	listName := ""
	if err == nil {
		listName = list.Name
	}

	if err := a.cards.Delete(r.Context(), token, data.UserID(), data.DisplayName(), card, listName); err != nil {
		mutationError(w, r, "/", err, "Couldn't delete that card. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleCardMove moves a card to a different column, appended to its end. Route already gated by
// requireCardManager. Every move writes both `listId` and `position` and appends a `moved`
// activity entry, per the task spec.
func (a *App) handleCardMove(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	toListID := r.FormValue("toListId")
	if toListID == "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	card, err := a.cards.ByID(r.Context(), token, id)
	if err != nil {
		redirectWithError(w, r, "/", "That card couldn't be found.")
		return
	}
	if card.ListID == toListID {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	fromList, err := a.lists.ByID(r.Context(), token, card.ListID)
	if err != nil {
		redirectWithError(w, r, "/", "That card's current list couldn't be found.")
		return
	}
	toList, err := a.lists.ByID(r.Context(), token, toListID)
	if err != nil {
		redirectWithError(w, r, "/", "The target list couldn't be found.")
		return
	}

	if _, err := a.cards.MoveToList(r.Context(), token, data.UserID(), data.DisplayName(), card, fromList.Name, toList); err != nil {
		mutationError(w, r, "/", err, "Couldn't move that card. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleCardReorder moves a card up/down within its own column by swapping `position` with the
// adjacent card given as `neighborId`. Route already gated by requireCardManager. Still logs a
// `moved` activity entry (fromList === toList), matching the reference web app's
// useReorderCardInList.
func (a *App) handleCardReorder(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	neighborID := r.FormValue("neighborId")
	if neighborID == "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	card, err := a.cards.ByID(r.Context(), token, id)
	if err != nil {
		redirectWithError(w, r, "/", "That card couldn't be found.")
		return
	}
	neighbor, err := a.cards.ByID(r.Context(), token, neighborID)
	if err != nil {
		redirectWithError(w, r, "/", "The neighboring card couldn't be found.")
		return
	}
	if card.ListID != neighbor.ListID {
		redirectWithError(w, r, "/", "Cards can only reorder within the same list.")
		return
	}
	list, err := a.lists.ByID(r.Context(), token, card.ListID)
	if err != nil {
		redirectWithError(w, r, "/", "That card's list couldn't be found.")
		return
	}

	if err := a.cards.ReorderInList(r.Context(), token, data.UserID(), data.DisplayName(), card, neighbor, list.Name); err != nil {
		mutationError(w, r, "/", err, "Couldn't reorder that card. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}
