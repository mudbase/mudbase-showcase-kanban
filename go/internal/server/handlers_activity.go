package server

import "net/http"

func (a *App) activityBodyView(r *http.Request) (ActivityBodyView, error) {
	data := sessionFrom(r)
	entries, err := a.activity.Feed(r.Context(), data.AccessToken())
	if err != nil {
		return ActivityBodyView{}, err
	}
	return buildActivityView(entries), nil
}

// ActivityPageData is the /activity page's content payload.
type ActivityPageData struct {
	Base
	ActivityBodyView
}

// handleActivity renders the full reverse-chronological activity log. Every signed-in role
// (including viewer) can read it, per the RBAC matrix in plan/build-plan.md.
func (a *App) handleActivity(w http.ResponseWriter, r *http.Request) {
	feed, err := a.activityBodyView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := ActivityPageData{
		Base:             a.baseView(r, "Activity"),
		ActivityBodyView: feed,
	}
	a.render(w, r, http.StatusOK, "activity.html", view)
}

// handleActivityFragment renders just the activity list (no layout), polled every few seconds by
// a small inline script on the activity page - see handlers_board.go's handleBoardFragment doc
// comment for why this app polls instead of subscribing to a push realtime feed.
func (a *App) handleActivityFragment(w http.ResponseWriter, r *http.Request) {
	feed, err := a.activityBodyView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	a.renderFragment(w, r, http.StatusOK, "activity_fragment.html", feed)
}
