<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#FAF8F4">
    <meta name="description" content="Connexion sécurisée au back-office Béninfood.">
    <title>Connexion administrateur — Béninfood Back-office</title>
    <link rel="icon" href="{{ asset('assets/img/favicon-beninfood.jpeg') }}" type="image/jpeg">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="{{ asset('assets/css/login.css') }}">
</head>
<body class="login-page">
    <a class="skip-link" href="#login-form">Aller au formulaire de connexion</a>

    <main class="login-shell">
        <section class="login-showcase" aria-labelledby="showcase-title">
            <div class="showcase-wash showcase-wash--green" aria-hidden="true"></div>
            <div class="showcase-wash showcase-wash--orange" aria-hidden="true"></div>

            <svg class="decor decor-route" viewBox="0 0 560 300" fill="none" aria-hidden="true">
                <path d="M-12 246C76 184 112 268 202 210C292 152 328 58 454 86C506 98 536 132 582 108"
                      stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="2 11"/>
                <circle cx="202" cy="210" r="4" fill="currentColor"/>
                <circle cx="454" cy="86" r="4" fill="currentColor"/>
            </svg>

            <svg class="decor decor-pin" viewBox="0 0 64 80" fill="none" aria-hidden="true">
                <path d="M32 75C32 75 55 48.5 55 30C55 17.3 44.7 7 32 7C19.3 7 9 17.3 9 30C9 48.5 32 75 32 75Z"
                      stroke="currentColor" stroke-width="2.2"/>
                <circle cx="32" cy="30" r="8.5" stroke="currentColor" stroke-width="2.2"/>
            </svg>

            <svg class="decor decor-leaf" viewBox="0 0 180 220" fill="none" aria-hidden="true">
                <path d="M24 202C55 152 89 113 154 77" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                <path d="M92 134C65 133 45 116 42 88C70 88 91 105 92 134Z" stroke="currentColor" stroke-width="1.8"/>
                <path d="M117 105C115 77 131 57 159 52C163 81 146 102 117 105Z" stroke="currentColor" stroke-width="1.8"/>
                <path d="M71 162C52 158 38 142 38 120C61 123 75 139 71 162Z" stroke="currentColor" stroke-width="1.8"/>
            </svg>

            <header class="showcase-brand">
                <img src="{{ asset('assets/img/logo-beninfood.jpeg') }}"
                     class="showcase-logo"
                     width="200"
                     height="200"
                     alt="Logo Béninfood"
                     fetchpriority="high"
                     decoding="async">
                <span class="brand-badge">Back-office</span>
            </header>

            <div class="showcase-content">
                <p class="eyebrow"><span class="eyebrow-dot" aria-hidden="true"></span>Plateforme de gestion Béninfood</p>
                <h1 id="showcase-title">Bienvenue dans votre <span>espace d’administration</span></h1>
                <p class="showcase-lead">Pilotez votre activité Béninfood en toute simplicité.</p>

                <ul class="feature-list" aria-label="Fonctionnalités du back-office">
                    <li class="feature">
                        <span class="feature-icon feature-icon--green" aria-hidden="true">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="5" y="4" width="14" height="17" rx="2.5"/>
                                <path d="M9 4.5V3h6v1.5M9 9h6M9 13h6M9 17h4"/>
                            </svg>
                        </span>
                        <div class="feature-copy">
                            <h2>Gestion des commandes</h2>
                            <p>Suivez et gérez toutes vos commandes en temps réel.</p>
                        </div>
                    </li>
                    <li class="feature">
                        <span class="feature-icon feature-icon--orange" aria-hidden="true">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                <circle cx="5.5" cy="17.5" r="2.7"/>
                                <circle cx="18.5" cy="17.5" r="2.7"/>
                                <path d="M8.2 17.5h7.6l1.5-7H20M10.8 13.5V9.2H8M13 9.2h2.2l1.1 5.1"/>
                            </svg>
                        </span>
                        <div class="feature-copy">
                            <h2>Suivi des livraisons</h2>
                            <p>Visualisez l’état des livraisons et optimisez vos opérations.</p>
                        </div>
                    </li>
                    <li class="feature">
                        <span class="feature-icon feature-icon--green" aria-hidden="true">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M4 20V5M4 20h16"/>
                                <path d="M7.5 16.5v-4M12 16.5V8.5M16.5 16.5V6.5M21 16.5V11"/>
                                <path d="M6.5 8.5l4-3 4 2 5-4"/>
                            </svg>
                        </span>
                        <div class="feature-copy">
                            <h2>Pilotage des revenus</h2>
                            <p>Analysez vos performances et développez votre activité.</p>
                        </div>
                    </li>
                </ul>
            </div>

            <footer class="showcase-footer">
                <span>Béninfood Back-office</span>
                <span class="footer-dot" aria-hidden="true"></span>
                <span>Cotonou, Bénin</span>
            </footer>
        </section>

        <section class="login-panel" aria-labelledby="login-title">
            <div class="panel-grid" aria-hidden="true"></div>

            <div class="login-card">
                <header class="login-card-header">
                    <span class="security-orb" aria-hidden="true">
                        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M16 3.5l10 4.2v7.2c0 6.3-4.2 11.4-10 13.6C10.2 26.3 6 21.2 6 14.9V7.7L16 3.5Z"/>
                            <circle cx="16" cy="13.2" r="3.1"/>
                            <path d="M10.6 22c.8-2.7 2.9-4.2 5.4-4.2s4.6 1.5 5.4 4.2"/>
                        </svg>
                    </span>
                    <p class="card-eyebrow">Espace sécurisé</p>
                    <h2 id="login-title">Connexion administrateur</h2>
                    <p class="card-subtitle">Accédez à votre tableau de bord Béninfood.</p>
                </header>

                <form id="login-form" class="login-form" method="POST" action="{{ route('login.post') }}" data-login-form>
                    @csrf

                    <div class="form-field {{ $errors->has('email') ? 'has-error' : '' }}">
                        <label for="email">Adresse e-mail</label>
                        <div class="input-shell">
                            <span class="input-icon" aria-hidden="true">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                    <rect x="3" y="5" width="18" height="14" rx="2.5"/>
                                    <path d="m4.5 7 7.5 6 7.5-6"/>
                                </svg>
                            </span>
                            <input id="email"
                                   type="email"
                                   name="email"
                                   value="{{ old('email') }}"
                                   placeholder="Entrez votre adresse e-mail"
                                   autocomplete="username"
                                   inputmode="email"
                                   spellcheck="false"
                                   required
                                   autofocus
                                   @error('email') aria-invalid="true" aria-describedby="email-error" @enderror>
                        </div>
                        @error('email')
                            <p class="field-error" id="email-error">{{ $message }}</p>
                        @enderror
                    </div>

                    <div class="form-field {{ $errors->has('password') ? 'has-error' : '' }}">
                        <label for="password">Mot de passe</label>
                        <div class="input-shell">
                            <span class="input-icon" aria-hidden="true">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                    <rect x="4.5" y="10" width="15" height="10.5" rx="2.5"/>
                                    <path d="M8 10V7.5a4 4 0 0 1 8 0V10M12 14.2v2.4"/>
                                </svg>
                            </span>
                            <input id="password"
                                   type="password"
                                   name="password"
                                   placeholder="Entrez votre mot de passe"
                                   autocomplete="current-password"
                                   required
                                   @error('password') aria-invalid="true" aria-describedby="password-error" @enderror>
                            <button class="password-toggle"
                                    type="button"
                                    data-password-toggle
                                    aria-label="Afficher le mot de passe"
                                    aria-pressed="false"
                                    aria-controls="password"
                                    hidden>
                                <svg class="icon-eye" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                                    <path d="M2.8 12S6.5 5.8 12 5.8 21.2 12 21.2 12 17.5 18.2 12 18.2 2.8 12 2.8 12Z"/>
                                    <circle cx="12" cy="12" r="3.1"/>
                                </svg>
                                <svg class="icon-eye-off" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                                    <path d="m4 4 16 16M9.8 6.2A10.9 10.9 0 0 1 12 5.8c5.5 0 9.2 6.2 9.2 6.2a17.8 17.8 0 0 1-3.1 3.8M6.9 7.6A17.4 17.4 0 0 0 2.8 12s3.7 6.2 9.2 6.2c1.3 0 2.5-.4 3.6-1"/>
                                    <path d="M10.3 10.3a2.4 2.4 0 0 0 3.4 3.4"/>
                                </svg>
                            </button>
                        </div>
                        @error('password')
                            <p class="field-error" id="password-error">{{ $message }}</p>
                        @enderror
                    </div>

                    <div class="form-meta">
                        <label class="check-field" for="remember">
                            <input id="remember" type="checkbox" name="remember" value="1" @checked(old('remember'))>
                            <span class="check-box" aria-hidden="true">
                                <svg viewBox="0 0 12 10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="m1 5.2 3.1 3.1L11 1.5"/>
                                </svg>
                            </span>
                            <span>Se souvenir de moi</span>
                        </label>

                        @if (Route::has('password.request'))
                            <a class="quiet-link" href="{{ route('password.request') }}">Mot de passe oublié ?</a>
                        @else
                            <span class="reset-note">Réinitialisation via l’administrateur</span>
                        @endif
                    </div>

                    <button class="submit-button" type="submit" data-submit-button>
                        <span class="submit-spinner" aria-hidden="true"></span>
                        <span class="submit-label" data-submit-label>Se connecter</span>
                        <svg class="submit-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                            <path d="M5 12h13M13 6.5 18.5 12 13 17.5"/>
                        </svg>
                    </button>
                </form>

                <div class="card-divider" aria-hidden="true"></div>

                <p class="security-note">
                    <span class="security-shield" aria-hidden="true">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M12 3l7.5 3v5.4c0 4.7-3.2 8.6-7.5 10.2C7.7 20 4.5 16.1 4.5 11.4V6L12 3Z"/>
                            <path d="m8.8 11.7 2.2 2.2 4.3-4.6"/>
                        </svg>
                    </span>
                    Accès sécurisé réservé aux administrateurs Béninfood.
                </p>
            </div>

            <p class="panel-footnote">© {{ date('Y') }} Béninfood. Tous droits réservés.</p>
        </section>
    </main>

    <script src="{{ asset('assets/js/login.js') }}" defer></script>
</body>
</html>
