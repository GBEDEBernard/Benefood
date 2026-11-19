<?php

namespace App\Http\Controllers\Auth;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Services\SocialAuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;

/**
 * Connexion sociale web (back-office) via redirection OAuth.
 */
class SocialLoginController extends Controller
{
    public function __construct(private readonly SocialAuthService $socialAuth) {}

    public function redirect(Request $request, string $provider): RedirectResponse
    {
        try {
            $provider = $this->socialAuth->normalizeProviderName($provider);
        } catch (DomainException $e) {
            return $this->redirectWithError($e->getMessage());
        }

        if (! $this->socialAuth->isConfiguredForWeb($provider)) {
            return $this->redirectWithError('La connexion avec '.ucfirst($provider).' n’est pas encore configurée.');
        }

        $state = Str::random(40);
        $request->session()->put('oauth_state_'.$provider, $state);
        $request->session()->put('oauth_remember_'.$provider, $request->boolean('remember'));

        try {
            $url = $this->socialAuth->authorizationUrl($provider, $state);
        } catch (DomainException $e) {
            return $this->redirectWithError($e->getMessage());
        }

        return redirect()->away($url);
    }

    public function callback(Request $request, string $provider): RedirectResponse
    {
        try {
            $provider = $this->socialAuth->normalizeProviderName($provider);
        } catch (DomainException $e) {
            return $this->redirectWithError($e->getMessage());
        }

        if ($request->filled('error')) {
            $description = trim((string) $request->query('error_description', ''));
            $message = $description !== '' ? $description : 'La connexion a été annulée ou refusée.';

            return $this->redirectWithError($message);
        }

        $expectedState = (string) $request->session()->pull('oauth_state_'.$provider, '');
        $state = (string) $request->query('state', '');
        $remember = (bool) $request->session()->pull('oauth_remember_'.$provider, false);

        if ($expectedState === '' || $state === '' || ! hash_equals($expectedState, $state)) {
            return $this->redirectWithError('La session de connexion a expiré. Veuillez réessayer.');
        }

        $code = trim((string) $request->query('code', ''));
        if ($code === '') {
            return $this->redirectWithError('Code d’autorisation manquant. Veuillez réessayer.');
        }

        try {
            $resolved = $this->socialAuth->resolveAuthenticatedUser($provider, [
                'code' => $code,
                'redirect_uri' => $this->socialAuth->webRedirectUri($provider),
            ]);

            Auth::login($resolved['user'], $remember);
            $request->session()->regenerate();

            return redirect()->intended(route('admin.dashboard'));
        } catch (DomainException $e) {
            return $this->redirectWithError($e->getMessage());
        } catch (\Throwable) {
            return $this->redirectWithError('Connexion impossible pour le moment. Veuillez réessayer.');
        }
    }

    private function redirectWithError(string $message): RedirectResponse
    {
        return redirect()->route('login')->withErrors(['email' => $message])->withInput();
    }
}
