// Package server wires the app's HTTP surface: routing, session handling, and every
// server-rendered page handler, on top of internal/store's domain services.
package server

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/config"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/session"
	"github.com/mudbase/mudbase-showcase-kanban/go/internal/store"
)

// App bundles every dependency the HTTP handlers need.
type App struct {
	cfg       *config.Config
	sessions  *session.Store
	mudbase   *mbase.Client
	lists     *store.ListService
	cards     *store.CardService
	activity  *store.ActivityService
	templates *Templates
}

// New builds the App and its full dependency graph from cfg.
func New(cfg *config.Config) (*App, error) {
	templates, err := loadTemplates()
	if err != nil {
		return nil, fmt.Errorf("server: loading templates: %w", err)
	}

	client := mbase.New(cfg)
	activity := store.NewActivityService(client, cfg.ActivityCollectionID)
	lists := store.NewListService(client, cfg.ListsCollectionID, activity)
	cards := store.NewCardService(client, cfg.CardsCollectionID, activity)

	return &App{
		cfg:       cfg,
		sessions:  session.New(cfg.SessionSecret, cfg.CookieSecure),
		mudbase:   client,
		lists:     lists,
		cards:     cards,
		activity:  activity,
		templates: templates,
	}, nil
}

// Routes builds the full chi router for this app. Static assets are mounted outside the session
// middleware group - a stylesheet request has no business loading a session cookie.
func (a *App) Routes() http.Handler {
	root := chi.NewRouter()
	root.Use(middleware.Logger)
	root.Use(middleware.Recoverer)

	staticHandler := http.FileServer(http.FS(staticFS))
	root.Get("/static/*", staticHandler.ServeHTTP)

	r := chi.NewRouter()
	r.Use(a.sessionMiddleware)

	r.Get("/login", a.handleLoginShow)
	r.Post("/login", a.handleLoginSubmit)
	r.Post("/logout", a.handleLogout)

	r.With(a.requireSignedIn).Get("/", a.handleBoard)
	r.With(a.requireSignedIn).Get("/board/fragment", a.handleBoardFragment)

	r.With(a.requireSignedIn, a.requireListManager).Post("/lists", a.handleListCreate)
	r.With(a.requireSignedIn, a.requireListManager).Post("/lists/{id}/rename", a.handleListRename)
	r.With(a.requireSignedIn, a.requireListManager).Post("/lists/{id}/reorder", a.handleListReorder)
	r.With(a.requireSignedIn, a.requireListManager).Post("/lists/{id}/delete", a.handleListDelete)

	r.With(a.requireSignedIn, a.requireCardManager).Post("/cards", a.handleCardCreate)
	r.With(a.requireSignedIn, a.requireCardManager).Post("/cards/{id}/edit", a.handleCardEdit)
	r.With(a.requireSignedIn, a.requireCardManager).Post("/cards/{id}/move", a.handleCardMove)
	r.With(a.requireSignedIn, a.requireCardManager).Post("/cards/{id}/reorder", a.handleCardReorder)
	r.With(a.requireSignedIn, a.requireCardManager).Post("/cards/{id}/delete", a.handleCardDelete)

	r.With(a.requireSignedIn).Get("/activity", a.handleActivity)
	r.With(a.requireSignedIn).Get("/activity/fragment", a.handleActivityFragment)

	root.Mount("/", r)
	return root
}
