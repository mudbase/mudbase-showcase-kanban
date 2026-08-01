// Package store implements every domain operation this app needs against the three Mudbase
// collections (lists, cards, activity), on top of internal/mbase's generic CRUD helpers. Every
// mutating method here also writes the corresponding `activity` row itself, so a handler can never
// forget to log an action - mirrors the reference web app's src/hooks/useLists.ts /
// src/hooks/useCards.ts, which pair every mutation with an activity write in the same hook.
package store

import (
	"context"
	"fmt"
	"sort"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
)

// ListService implements every operation the app needs against the `lists` collection.
type ListService struct {
	client       *mbase.Client
	collectionID string
	activity     *ActivityService
}

// NewListService builds a ListService bound to the given lists collection ID.
func NewListService(client *mbase.Client, listsCollectionID string, activity *ActivityService) *ListService {
	return &ListService{client: client, collectionID: listsCollectionID, activity: activity}
}

// All returns every column on the shared board, ascending by position (column order).
func (s *ListService) All(ctx context.Context, token string) ([]models.List, error) {
	result, err := mbase.List[models.List](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"boardId": s.client.BoardID()},
		Sort:   "position",
		Limit:  200,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing lists: %w", err)
	}
	sort.Slice(result.Data, func(i, j int) bool { return result.Data[i].Position < result.Data[j].Position })
	return result.Data, nil
}

// ByID fetches a single list by its Mudbase document ID.
func (s *ListService) ByID(ctx context.Context, token, id string) (models.List, error) {
	list, err := mbase.Get[models.List](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.List{}, fmt.Errorf("store: fetching list %s: %w", id, err)
	}
	return list, nil
}

// nextPosition returns one past the highest position currently in use, 0 if there are none yet.
func nextPosition(lists []models.List) int {
	if len(lists) == 0 {
		return 0
	}
	max := lists[0].Position
	for _, l := range lists[1:] {
		if l.Position > max {
			max = l.Position
		}
	}
	return max + 1
}

// Create adds a new column at the end of the board and logs a created_list activity row.
// Owner-only - enforced by internal/server/middleware.go's requireRole before this is ever
// called, and independently by Mudbase's own collection permissions server-side.
func (s *ListService) Create(ctx context.Context, token, actorID, actorName, name string) (models.List, error) {
	existing, err := s.All(ctx, token)
	if err != nil {
		return models.List{}, err
	}

	created, err := mbase.Create[models.List](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"boardId":  s.client.BoardID(),
		"name":     name,
		"position": nextPosition(existing),
	})
	if err != nil {
		return models.List{}, fmt.Errorf("store: creating list: %w", err)
	}

	if err := s.activity.Log(ctx, token, actorID, actorName, models.ActionCreatedList, "", "", name); err != nil {
		return models.List{}, err
	}
	return created, nil
}

// Rename updates a column's name and logs a renamed_list activity row. Owner-only.
func (s *ListService) Rename(ctx context.Context, token, actorID, actorName string, list models.List, newName string) (models.List, error) {
	updated, err := mbase.Update[models.List](ctx, s.client, token, s.collectionID, list.ID, map[string]interface{}{
		"name": newName,
	})
	if err != nil {
		return models.List{}, fmt.Errorf("store: renaming list %s: %w", list.ID, err)
	}

	if err := s.activity.Log(ctx, token, actorID, actorName, models.ActionRenamedList, "", list.Name, newName); err != nil {
		return models.List{}, err
	}
	return updated, nil
}

// Reorder swaps list's position with neighbor's - a left/right column move. Not itself logged to
// the activity feed, matching the reference web app's useReorderList. Owner-only.
func (s *ListService) Reorder(ctx context.Context, token string, list, neighbor models.List) error {
	if _, err := mbase.Update[models.List](ctx, s.client, token, s.collectionID, list.ID, map[string]interface{}{
		"position": neighbor.Position,
	}); err != nil {
		return fmt.Errorf("store: reordering list %s: %w", list.ID, err)
	}
	if _, err := mbase.Update[models.List](ctx, s.client, token, s.collectionID, neighbor.ID, map[string]interface{}{
		"position": list.Position,
	}); err != nil {
		return fmt.Errorf("store: reordering list %s: %w", neighbor.ID, err)
	}
	return nil
}

// Delete removes a column and every card inside it - a list's cards have nowhere else to live
// once the column is gone, there's no "uncategorized" list to fall back to (matches the reference
// web app's useDeleteList). Logs a deleted_list activity row. Owner-only.
func (s *ListService) Delete(ctx context.Context, token, actorID, actorName string, list models.List, cardsInList []models.Card, cards *CardService) error {
	for _, card := range cardsInList {
		if err := mbase.Delete(ctx, s.client, token, cards.collectionID, card.ID); err != nil {
			return fmt.Errorf("store: deleting card %s while deleting list %s: %w", card.ID, list.ID, err)
		}
	}
	if err := mbase.Delete(ctx, s.client, token, s.collectionID, list.ID); err != nil {
		return fmt.Errorf("store: deleting list %s: %w", list.ID, err)
	}

	return s.activity.Log(ctx, token, actorID, actorName, models.ActionDeletedList, "", list.Name, "")
}
