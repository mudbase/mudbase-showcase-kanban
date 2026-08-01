package server

import (
	"net/http"
	"sort"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/models"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/rbac"
)

// Base holds the fields every page's layout needs (header nav, role badge, flash banner). It is
// embedded in every page-specific data struct so templates can read `.IsSignedIn`, `.Flash`, etc.
// directly at the top level via Go's promoted-field rules.
type Base struct {
	Title        string
	IsSignedIn   bool
	DisplayName  string
	Role         string
	RoleLabel    string
	FlashError   string
	FlashSuccess string
}

// baseView builds the Base fields shared by every page from the current request's session.
func (a *App) baseView(r *http.Request, title string) Base {
	data := sessionFrom(r)
	return Base{
		Title:       title,
		IsSignedIn:  data.IsSignedIn(),
		DisplayName: data.DisplayName(),
		Role:        data.Role(),
		RoleLabel:   rbac.Label(data.Role()),
	}
}

// CardItemView is a display-ready card: every derived/precomputed value (assignee initials,
// sibling ids for the up/down reorder buttons, the "move to" target list options) is computed once
// here instead of in the template, since html/template's nested {{template}} scoping makes reaching
// back to an ancestor's data awkward - denormalizing onto the leaf view is simpler and mirrors the
// reference web app's CardItemProps (prevCard/nextCard/otherLists passed down from BoardView).
type CardItemView struct {
	models.Card
	AssigneeDisplay  string
	AssigneeInitials string
	HasPrev          bool
	HasNext          bool
	PrevID           string
	NextID           string
	CanManage        bool
	OtherLists       []models.List
}

// ListColumnView is a display-ready board column.
type ListColumnView struct {
	models.List
	Cards          []CardItemView
	HasPrev        bool
	HasNext        bool
	CanManageLists bool
	CanManageCards bool
}

// BoardBodyView is the poll-refreshed part of the board page shared by the full page and its
// fragment.
type BoardBodyView struct {
	Lists          []ListColumnView
	CanManageLists bool
	ReadOnly       bool
}

// buildBoardView groups cards by list and computes every per-item display/permission field the
// templates need, given the raw lists/cards this request's role may see (every role can read
// every list/card - see plan/build-plan.md "RBAC Matrix" - only writes are role-gated).
func buildBoardView(lists []models.List, cards []models.Card, role string) BoardBodyView {
	sortedLists := make([]models.List, len(lists))
	copy(sortedLists, lists)
	sort.Slice(sortedLists, func(i, j int) bool { return sortedLists[i].Position < sortedLists[j].Position })

	cardsByList := make(map[string][]models.Card, len(sortedLists))
	for _, c := range cards {
		cardsByList[c.ListID] = append(cardsByList[c.ListID], c)
	}
	for listID, bucket := range cardsByList {
		sorted := make([]models.Card, len(bucket))
		copy(sorted, bucket)
		sort.Slice(sorted, func(i, j int) bool { return sorted[i].Position < sorted[j].Position })
		cardsByList[listID] = sorted
	}

	manageLists := rbac.CanManageLists(role)
	manageCards := rbac.CanManageCards(role)

	listViews := make([]ListColumnView, 0, len(sortedLists))
	for i, l := range sortedLists {
		otherLists := make([]models.List, 0, len(sortedLists)-1)
		for _, other := range sortedLists {
			if other.ID != l.ID {
				otherLists = append(otherLists, other)
			}
		}

		bucket := cardsByList[l.ID]
		cardViews := make([]CardItemView, 0, len(bucket))
		for j, c := range bucket {
			cv := CardItemView{
				Card:             c,
				AssigneeDisplay:  c.AssigneeDisplay(),
				AssigneeInitials: initials(c.AssigneeDisplay()),
				CanManage:        manageCards,
				OtherLists:       otherLists,
			}
			if j > 0 {
				cv.HasPrev = true
				cv.PrevID = bucket[j-1].ID
			}
			if j < len(bucket)-1 {
				cv.HasNext = true
				cv.NextID = bucket[j+1].ID
			}
			cardViews = append(cardViews, cv)
		}

		lv := ListColumnView{
			List:           l,
			Cards:          cardViews,
			CanManageLists: manageLists,
			CanManageCards: manageCards,
		}
		if i > 0 {
			lv.HasPrev = true
		}
		if i < len(sortedLists)-1 {
			lv.HasNext = true
		}
		listViews = append(listViews, lv)
	}

	return BoardBodyView{
		Lists:          listViews,
		CanManageLists: manageLists,
		ReadOnly:       rbac.IsReadOnly(role),
	}
}

// ActivityItemView is a display-ready activity row.
type ActivityItemView struct {
	models.Activity
	Text         string
	CreatedLabel string
}

// ActivityBodyView is the poll-refreshed part of the activity page shared by the full page and its
// fragment.
type ActivityBodyView struct {
	Entries []ActivityItemView
}

func buildActivityView(entries []models.Activity) ActivityBodyView {
	views := make([]ActivityItemView, 0, len(entries))
	for _, e := range entries {
		views = append(views, ActivityItemView{
			Activity:     e,
			Text:         describeActivity(e),
			CreatedLabel: formatDate(e.CreatedAt),
		})
	}
	return ActivityBodyView{Entries: views}
}
