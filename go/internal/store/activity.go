package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
)

// feedLimit mirrors the reference web app's useActivityFeed FEED_LIMIT
// (../web/src/hooks/useActivity.ts).
const feedLimit = 200

// ActivityService implements every operation the app needs against the `activity` collection.
type ActivityService struct {
	client       *mbase.Client
	collectionID string
}

// NewActivityService builds an ActivityService bound to the given activity collection ID.
func NewActivityService(client *mbase.Client, activityCollectionID string) *ActivityService {
	return &ActivityService{client: client, collectionID: activityCollectionID}
}

// Feed returns the reverse-chronological activity log for the shared board.
func (s *ActivityService) Feed(ctx context.Context, token string) ([]models.Activity, error) {
	result, err := mbase.List[models.Activity](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"boardId": s.client.BoardID()},
		Sort:   "-createdAt",
		Limit:  feedLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing activity: %w", err)
	}
	return result.Data, nil
}

// Log appends one activity row. cardTitle/fromList/toList are written only when non-empty (the
// collection treats them as optional fields) - matches every mutation in the reference web app's
// src/hooks/useLists.ts / useCards.ts, which each write exactly one activity row per action.
func (s *ActivityService) Log(ctx context.Context, token, actorID, actorName string, action models.ActivityAction, cardTitle, fromList, toList string) error {
	body := map[string]interface{}{
		"boardId":   s.client.BoardID(),
		"actorId":   actorID,
		"actorName": actorName,
		"action":    string(action),
	}
	if cardTitle != "" {
		body["cardTitle"] = cardTitle
	}
	if fromList != "" {
		body["fromList"] = fromList
	}
	if toList != "" {
		body["toList"] = toList
	}

	if _, err := mbase.Create[models.Activity](ctx, s.client, token, s.collectionID, body); err != nil {
		return fmt.Errorf("store: logging activity %q: %w", action, err)
	}
	return nil
}
