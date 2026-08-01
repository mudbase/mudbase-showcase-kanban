package store

import (
	"context"
	"fmt"
	"sort"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
)

// CardService implements every operation the app needs against the `cards` collection.
type CardService struct {
	client       *mbase.Client
	collectionID string
	activity     *ActivityService
}

// NewCardService builds a CardService bound to the given cards collection ID.
func NewCardService(client *mbase.Client, cardsCollectionID string, activity *ActivityService) *CardService {
	return &CardService{client: client, collectionID: cardsCollectionID, activity: activity}
}

// All returns every card on the shared board, ascending by position (in-column order) - fetched
// once and grouped by ListID by the caller (see server/view_board.go), rather than one query per
// column, matching the reference web app's useBoardCards.
func (s *CardService) All(ctx context.Context, token string) ([]models.Card, error) {
	result, err := mbase.List[models.Card](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"boardId": s.client.BoardID()},
		Sort:   "position",
		Limit:  500,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing cards: %w", err)
	}
	sort.Slice(result.Data, func(i, j int) bool { return result.Data[i].Position < result.Data[j].Position })
	return result.Data, nil
}

// ByID fetches a single card by its Mudbase document ID.
func (s *CardService) ByID(ctx context.Context, token, id string) (models.Card, error) {
	card, err := mbase.Get[models.Card](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.Card{}, fmt.Errorf("store: fetching card %s: %w", id, err)
	}
	return card, nil
}

// nextPositionInList returns one past the highest position among cards already in listID, 0 if
// there are none yet.
func nextPositionInList(cards []models.Card, listID string) int {
	max := -1
	for _, c := range cards {
		if c.ListID == listID && c.Position > max {
			max = c.Position
		}
	}
	return max + 1
}

// CreateInput bundles a new card's user-supplied fields.
type CreateInput struct {
	ListID       string
	ListName     string
	Title        string
	Description  string
	AssigneeName string
}

// Create adds a new card at the end of listID and logs a created_card activity row.
// Owner/member - enforced by internal/server/middleware.go's requireRole before this is ever
// called, and independently by Mudbase's own collection permissions server-side.
func (s *CardService) Create(ctx context.Context, token, actorID, actorName string, input CreateInput) (models.Card, error) {
	existing, err := s.All(ctx, token)
	if err != nil {
		return models.Card{}, err
	}

	body := map[string]interface{}{
		"boardId":       s.client.BoardID(),
		"listId":        input.ListID,
		"title":         input.Title,
		"position":      nextPositionInList(existing, input.ListID),
		"createdById":   actorID,
		"createdByName": actorName,
	}
	if input.Description != "" {
		body["description"] = input.Description
	}
	if input.AssigneeName != "" {
		body["assigneeId"] = pseudoObjectID(input.AssigneeName)
		body["assigneeName"] = input.AssigneeName
	}

	created, err := mbase.Create[models.Card](ctx, s.client, token, s.collectionID, body)
	if err != nil {
		return models.Card{}, fmt.Errorf("store: creating card: %w", err)
	}

	if err := s.activity.Log(ctx, token, actorID, actorName, models.ActionCreatedCard, input.Title, "", input.ListName); err != nil {
		return models.Card{}, err
	}
	return created, nil
}

// UpdateInput bundles a card edit's user-supplied fields.
type UpdateInput struct {
	Title        string
	Description  string
	AssigneeName string
}

// Update edits a card's title/description/assignee in place. Not itself logged to the activity
// feed - only creation, movement, and deletion are (matches the reference web app's
// useUpdateCard). `assigneeId`/`assigneeName` are sent as explicit JSON `null` when AssigneeName
// is empty - Mudbase validates assigneeId as an ObjectId reference server-side, and an empty
// string fails that check the same way an invalid slug would ("Invalid ObjectId format for
// assigneeId"); `null` is the value that actually clears it (confirmed live). Owner/member.
func (s *CardService) Update(ctx context.Context, token, cardID string, input UpdateInput) (models.Card, error) {
	body := map[string]interface{}{
		"title":       input.Title,
		"description": input.Description,
	}
	if input.AssigneeName != "" {
		body["assigneeId"] = pseudoObjectID(input.AssigneeName)
		body["assigneeName"] = input.AssigneeName
	} else {
		body["assigneeId"] = nil
		body["assigneeName"] = nil
	}

	updated, err := mbase.Update[models.Card](ctx, s.client, token, s.collectionID, cardID, body)
	if err != nil {
		return models.Card{}, fmt.Errorf("store: updating card %s: %w", cardID, err)
	}
	return updated, nil
}

// Delete removes a card and logs a deleted_card activity row. Owner/member.
func (s *CardService) Delete(ctx context.Context, token, actorID, actorName string, card models.Card, listName string) error {
	if err := mbase.Delete(ctx, s.client, token, s.collectionID, card.ID); err != nil {
		return fmt.Errorf("store: deleting card %s: %w", card.ID, err)
	}
	return s.activity.Log(ctx, token, actorID, actorName, models.ActionDeletedCard, card.Title, listName, "")
}

// MoveToList moves card to the end of toList (a different column) and logs a moved activity row.
// Every move writes both `listId` and `position`, per the task spec. Owner/member.
func (s *CardService) MoveToList(ctx context.Context, token, actorID, actorName string, card models.Card, fromListName string, toList models.List) (models.Card, error) {
	existing, err := s.All(ctx, token)
	if err != nil {
		return models.Card{}, err
	}

	updated, err := mbase.Update[models.Card](ctx, s.client, token, s.collectionID, card.ID, map[string]interface{}{
		"listId":   toList.ID,
		"position": nextPositionInList(existing, toList.ID),
	})
	if err != nil {
		return models.Card{}, fmt.Errorf("store: moving card %s to list %s: %w", card.ID, toList.ID, err)
	}

	if err := s.activity.Log(ctx, token, actorID, actorName, models.ActionMoved, card.Title, fromListName, toList.Name); err != nil {
		return models.Card{}, err
	}
	return updated, nil
}

// ReorderInList swaps card's position with neighbor's (both must already be in the same column) -
// an up/down move within a column. Still logs a moved activity entry (fromList == toList), per the
// task's "every move...appends an activity entry" requirement (matches the reference web app's
// useReorderCardInList). Owner/member.
func (s *CardService) ReorderInList(ctx context.Context, token, actorID, actorName string, card, neighbor models.Card, listName string) error {
	if _, err := mbase.Update[models.Card](ctx, s.client, token, s.collectionID, card.ID, map[string]interface{}{
		"position": neighbor.Position,
	}); err != nil {
		return fmt.Errorf("store: reordering card %s: %w", card.ID, err)
	}
	if _, err := mbase.Update[models.Card](ctx, s.client, token, s.collectionID, neighbor.ID, map[string]interface{}{
		"position": card.Position,
	}); err != nil {
		return fmt.Errorf("store: reordering card %s: %w", neighbor.ID, err)
	}

	return s.activity.Log(ctx, token, actorID, actorName, models.ActionMoved, card.Title, listName, listName)
}
