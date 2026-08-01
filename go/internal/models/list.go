// Package models holds this app's typed views of the three Mudbase collections it reads and
// writes (lists, cards, activity) - see plan/build-plan.md for the full schema.
package models

// List mirrors the `lists` Mudbase collection schema - one board column.
type List struct {
	ID        string `json:"_id"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
	BoardID   string `json:"boardId"`
	Name      string `json:"name"`
	Position  int    `json:"position"`
}
