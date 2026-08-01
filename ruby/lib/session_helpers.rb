# frozen_string_literal: true

require_relative "mudbase/errors"
require_relative "mudbase/auth_service"

# Sinatra helpers for reading/writing the signed-in user's state. Unlike the sibling
# `mudbase-showcase-social` port, this app has **no anonymous/guest session** - every page
# except `/login` requires a real signed-in account, for all three roles
# (`owner`/`member`/`viewer`), since Mudbase's own collection permissions 401 an unauthenticated
# request on every collection here (see plan/build-plan.md "Auth Model"). The Mudbase-issued JWT
# is held only inside the Rack session cookie (encrypted + signed + httponly via
# `Rack::Session::Cookie`, configured in app.rb) - never rendered into a page or exposed to
# client-side JavaScript.
#
# Refresh-token rotation: every route that calls Mudbase routes its access token through
# `with_access_token`, which proactively refreshes a token that's within
# `TOKEN_REFRESH_MARGIN_SECONDS` of its tracked expiry, and - the same as the reference Next.js
# app's `MudbaseClient#request` - reactively refreshes and retries exactly once on a real 401
# from the server. Only when the refresh token itself is rejected (expired/already
# rotated-away/revoked) does the session actually get torn down, via `MudbaseSDK::ApiError`
# bubbling up to app.rb's global 401 handler, which calls `clear_auth_session!` and redirects to
# `/login`.
module SessionHelpers
  TOKEN_REFRESH_MARGIN_SECONDS = 60

  def store_auth_session!(auth_session)
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    session[:user] = auth_session.user
  end

  def clear_auth_session!
    session.clear
  end

  def access_token
    session[:token]
  end

  def current_user
    session[:user]
  end

  def logged_in?
    !current_user.nil?
  end

  # Wraps every Mudbase call this app makes (every read and every write goes through a signed-in
  # user's own token - there is no separate guest path). If no refresh token is stored, or the
  # refresh token itself is rejected, the original `MudbaseSDK::ApiError` propagates to app.rb's
  # global handler, which logs the session out.
  def with_access_token
    refresh_access_token! if token_expiring_soon?
    yield session[:token]
  rescue MudbaseSDK::ApiError => e
    failure = Mudbase::ApiFailure.from(e)
    raise e unless failure.status == 401
    raise e unless refresh_access_token!

    yield session[:token]
  end

  def token_expiring_soon?
    session[:expires_at].nil? || Time.now.to_i >= session[:expires_at] - TOKEN_REFRESH_MARGIN_SECONDS
  end

  # @return [Boolean] whether the refresh succeeded and `session[:token]` is now fresh.
  def refresh_access_token!
    return false unless session[:refresh_token]

    auth_session = Mudbase::AuthService.refresh!(session[:refresh_token])
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    true
  rescue Mudbase::AuthError
    false
  end

  # ── Role helpers (RBAC matrix, plan/build-plan.md) ──────────────────────────────────────
  # Mudbase's own collection permissions are the real enforcement boundary (confirmed live -
  # see plan/build-plan.md "Live smoke test results" for a raw-fetch write attempt as a
  # non-owner/viewer that the UI never exposes a button for). These helpers are this app's own
  # *additional* server-side gate: every mutating route calls `require_owner!`/
  # `require_write_access!` before ever calling Mudbase, rather than only hiding buttons in the
  # view - "don't rely on UI-only gating".

  def current_role
    current_user && current_user[:customRole]
  end

  def owner?
    current_role == "owner"
  end

  def member?
    current_role == "member"
  end

  def viewer?
    current_role == "viewer"
  end

  def can_manage_lists?
    owner?
  end

  def can_manage_cards?
    owner? || member?
  end

  def require_login!
    return if logged_in?

    session[:return_to] = request.path_info
    redirect "/login"
  end

  # Server-side gate for list restructuring (create/rename/delete/reorder) - owner only.
  def require_owner!
    require_login!
    return if owner?

    flash_error("Only the board owner can manage lists.")
    redirect back_or("/")
  end

  # Server-side gate for card writes (create/edit/delete/move) - owner or member.
  def require_write_access!
    require_login!
    return if can_manage_cards?

    flash_error("You're signed in as Viewer - the board is read-only for you.")
    redirect back_or("/")
  end

  def consume_return_to
    session.delete(:return_to) || "/"
  end

  # For "set then redirect" flows: written to the session so the *next* request's `before`
  # filter (which runs before the route body, and so before any `flash_error`/`flash_notice`
  # call made this request) can pick it up via pop_flash_notice/pop_flash_error.
  def flash_notice(message)
    session[:flash_notice] = message
  end

  def flash_error(message)
    session[:flash_error] = message
  end

  def pop_flash_notice
    session.delete(:flash_notice)
  end

  def pop_flash_error
    session.delete(:flash_error)
  end

  # For "validate, then re-render the same page in this same response" flows (a failed
  # login/form submission). `@flash_error`/`@flash_notice` are already populated for this
  # request by the `before` filter *before* the route body runs, so a form-validation failure
  # has to set the ivar directly - writing to session here would only become visible on the
  # *following* request, leaving this response's re-rendered form with no visible error.
  def show_error_now(message)
    @flash_error = message
  end

  def show_notice_now(message)
    @flash_notice = message
  end
end
