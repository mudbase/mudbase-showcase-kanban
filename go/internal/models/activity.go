package models

// ActivityAction enumerates every value this app writes to `activity.action`. Only
// created_card/moved/deleted_card are required by the task; the three list-level actions are a
// small superset that makes the log read naturally as a real project history, written by the
// same owner-only code paths that already call the lists API - matches the reference web app
// (see ../web/plan/build-plan.md).
type ActivityAction string

const (
	ActionCreatedCard ActivityAction = "created_card"
	ActionMoved       ActivityAction = "moved"
	ActionDeletedCard ActivityAction = "deleted_card"
	ActionCreatedList ActivityAction = "created_list"
	ActionRenamedList ActivityAction = "renamed_list"
	ActionDeletedList ActivityAction = "deleted_list"
)

// Activity mirrors the `activity` Mudbase collection schema - one reverse-chronological log row.
type Activity struct {
	ID        string         `json:"_id"`
	CreatedAt string         `json:"createdAt"`
	BoardID   string         `json:"boardId"`
	ActorID   string         `json:"actorId"`
	ActorName string         `json:"actorName"`
	Action    ActivityAction `json:"action"`
	CardTitle string         `json:"cardTitle"`
	FromList  string         `json:"fromList"`
	ToList    string         `json:"toList"`
}
