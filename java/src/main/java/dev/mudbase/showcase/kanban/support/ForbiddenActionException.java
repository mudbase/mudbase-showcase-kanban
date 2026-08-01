package dev.mudbase.showcase.kanban.support;

/**
 * Thrown by the service layer ({@code ListService}/{@code CardService}) when the acting role
 * fails the {@link RoleSupport} check for the requested mutation - e.g. a `member` posting to
 * create a list, or a `viewer` posting anything at all. This is this Java app's own independent
 * server-side enforcement of the RBAC matrix in plan/build-plan.md: it runs before any call to
 * Mudbase is attempted, so a raw POST to one of this app's own routes that bypasses the
 * Thymeleaf UI's hidden buttons is rejected here - not merely by Mudbase's own collection
 * permissions one layer further down (which independently reject the same request too, per the
 * live smoke test in plan/build-plan.md). Handled by {@code
 * dev.mudbase.showcase.kanban.web.GlobalExceptionHandler}, which renders a 403 error page.
 */
public class ForbiddenActionException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public ForbiddenActionException(String message) {
    super(message);
  }
}
