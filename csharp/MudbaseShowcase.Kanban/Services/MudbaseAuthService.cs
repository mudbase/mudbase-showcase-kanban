using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Mudbase.Sdk.Api;
using Mudbase.Sdk.Model;
using MudbaseShowcase.Kanban.Models;
using MudbaseShowcase.Kanban.Options;

namespace MudbaseShowcase.Kanban.Services;

/// <summary>
/// Login, session refresh, and logout only - no anonymous/guest bootstrap and no self-registration.
/// Unlike the social/ecommerce showcases, this app's Auth Model has no public read at all: every
/// one of the three roles (owner/member/viewer) must sign in with a real account before seeing
/// anything, because Mudbase's own collection permissions 401 an unauthenticated request on this
/// project (see plan/build-plan.md). Registration isn't exposed in this reference app either - the
/// task's three demo accounts already exist and are pre-verified, so RegisterWithRoleAsync/email
/// verification are simply out of scope here.
///
/// Every call here goes through the generated SDK directly - no raw-HttpClient workarounds.
/// </summary>
public sealed class MudbaseAuthService
{
    private readonly IAuthenticationApi _authApi;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;
    private readonly ILogger<MudbaseAuthService> _logger;

    public MudbaseAuthService(
        IAuthenticationApi authApi,
        MudbaseSessionAccessor session,
        IOptions<MudbaseOptions> options,
        ILogger<MudbaseAuthService> logger)
    {
        _authApi = authApi;
        _session = session;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<AuthOutcome> LoginAsync(string email, string password, CancellationToken cancellationToken)
    {
        LoginLocalUserRequest request = new(email, password, _options.ProjectId);
        ILoginLocalUserApiResponse response = await _authApi.LoginLocalUserAsync(request, cancellationToken);

        if (!response.TryOk(out LoginLocalUser200Response? body) || body?.Token is not { Length: > 0 } token)
        {
            return AuthOutcome.Failure(MudbaseApiException.From(response).Message);
        }

        _session.SetTokens(token, body.RefreshToken);
        await RefreshSessionAsync(cancellationToken);
        return AuthOutcome.Success();
    }

    /// <summary>
    /// Fetches the full, authoritative session user (including customRole, which the login
    /// response's typed model doesn't expose) and caches it in session state. Call after every
    /// token change (login, refresh) - mirrors refreshSession() in web/src/lib/mudbase-provider.tsx.
    /// </summary>
    public async Task RefreshSessionAsync(CancellationToken cancellationToken)
    {
        if (!_session.HasToken)
        {
            _session.ClearUser();
            return;
        }

        IGetLocalSessionApiResponse response = await _authApi.GetLocalSessionAsync(_options.ProjectId, cancellationToken);

        if (!response.TryOk(out GetLocalSession200Response? body) || body?.User is not JsonElement userElement)
        {
            _session.ClearToken();
            _session.ClearUser();
            return;
        }

        MudbaseSessionUser? user = JsonSerializer.Deserialize<MudbaseSessionUser>(userElement.GetRawText(), MudbaseJson.Options);
        _session.SetUser(user ?? new MudbaseSessionUser());
    }

    public async Task LogoutAsync(CancellationToken cancellationToken)
    {
        if (_session.HasToken)
        {
            try
            {
                await _authApi.LogoutLocalUserAsync(cancellationToken);
            }
            catch (HttpRequestException ex)
            {
                // Best-effort: the browser's session is cleared regardless so the user is signed
                // out locally even if Mudbase couldn't be reached to revoke server-side.
                _logger.LogWarning(ex, "Mudbase logout call failed; clearing local session anyway");
            }
        }

        _session.ClearToken();
        _session.ClearUser();
    }
}
