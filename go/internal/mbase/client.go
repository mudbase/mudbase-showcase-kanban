// Package mbase wraps the real Mudbase Go SDK (github.com/mudbase/mudbase-sdk/go) with this app's
// auth and collection-data operations. It intentionally stays thin: every method maps to one real
// SDK call. This is a direct sibling of mudbase-showcase-social/go's internal/mbase package - same
// client shape, same 401 -> refresh -> retry wiring (refresh.go) - trimmed to what this app needs:
// no anonymous/guest session (every role, including viewer, must sign in - see
// plan/build-plan.md), no self-registration (the task's three pre-provisioned demo accounts are
// used as-is).
package mbase

import (
	"context"
	"net/http"
	"time"

	mudbase "github.com/mudbase/mudbase-sdk/go"

	"github.com/mudbase/mudbase-showcase-kanban/go/internal/config"
)

// Client bundles the generated SDK client with the project configuration every call needs.
type Client struct {
	SDK *mudbase.APIClient
	cfg *config.Config
}

// New builds a Client from the app configuration, wiring the SDK to point at the configured
// Mudbase server exactly as documented: NewConfiguration() then override Servers.
func New(cfg *config.Config) *Client {
	sdkCfg := mudbase.NewConfiguration()
	sdkCfg.Servers = mudbase.ServerConfigurations{
		{URL: cfg.MudbaseURL},
	}
	sdkCfg.HTTPClient = &http.Client{Timeout: 15 * time.Second}

	return &Client{
		SDK: mudbase.NewAPIClient(sdkCfg),
		cfg: cfg,
	}
}

// ProjectID returns the configured Mudbase project ID.
func (c *Client) ProjectID() string {
	return c.cfg.ProjectID
}

// BoardID returns the single shared board's document id every list/card/activity row scopes to.
func (c *Client) BoardID() string {
	return c.cfg.BoardID
}

// authedContext attaches a bearer token to ctx the way the generated SDK expects it
// (context.WithValue(ctx, mudbase.ContextAccessToken, token)) - confirmed against
// mudbase-sdk/go/configuration.go and client.go's prepareRequest, which reads exactly this key.
func authedContext(ctx context.Context, token string) context.Context {
	if token == "" {
		return ctx
	}
	return context.WithValue(ctx, mudbase.ContextAccessToken, token)
}
