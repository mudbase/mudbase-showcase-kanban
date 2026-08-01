package models

// Card mirrors the `cards` Mudbase collection schema. AssigneeID/AssigneeName are pointers, not
// plain strings, because `null` is a real, distinct wire value here (an explicitly-cleared
// assignee - see internal/store/cards.go's Update) from "the field was simply never set" - a
// plain string field cannot represent that distinction and a JSON `null` fails to unmarshal into
// one.
type Card struct {
	ID            string  `json:"_id"`
	CreatedAt     string  `json:"createdAt"`
	UpdatedAt     string  `json:"updatedAt"`
	BoardID       string  `json:"boardId"`
	ListID        string  `json:"listId"`
	Title         string  `json:"title"`
	Description   string  `json:"description"`
	Position      int     `json:"position"`
	AssigneeID    *string `json:"assigneeId"`
	AssigneeName  *string `json:"assigneeName"`
	CreatedByID   string  `json:"createdById"`
	CreatedByName string  `json:"createdByName"`
}

// AssigneeDisplay renders the assignee name, or "" when unassigned - a convenience over
// nil-checking *AssigneeName at every call site.
func (c Card) AssigneeDisplay() string {
	if c.AssigneeName == nil {
		return ""
	}
	return *c.AssigneeName
}
