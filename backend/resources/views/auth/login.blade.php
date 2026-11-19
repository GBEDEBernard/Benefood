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
    <style>
        .social-auth { margin: 4px 0 18px; }
        .social-auth-label {
            margin: 0 0 12px;
            text-align: center;
            font-size: 13px;
            font-weight: 700;
            color: #5f5f66;
            letter-spacing: .1px;
        }
        .social-auth-row {
            display: flex;
            justify-content: center;
            gap: 14px;
        }
        .social-btn {
            width: 48px;
            height: 48px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-radius: 12px;
            border: 1px solid #e3e3e8;
            background: #fff;
            text-decoration: none;
            transition: transform .15s ease, box-shadow .15s ease, border-color .15s ease;
            box-shadow: 0 1px 0 rgba(0,0,0,.02);
        }
        .social-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 14px rgba(0,0,0,.06);
            border-color: #d8d8de;
        }
        .social-btn--facebook { background: #1877F2; border-color: #1877F2; }
        .social-btn--facebook svg path { fill: #fff; }
        .social-btn--linkedin { background: #0A66C2; border-color: #0A66C2; }
        .social-btn--linkedin svg path { fill: #fff; }
        .social-mark { display: inline-flex; }
        .social-divider {
            display: flex;
            align-items: center;
            gap: 12px;
            margin: 16px 0 2px;
            color: #8a8a92;
            font-size: 12.5px;
            font-weight: 600;
        }
        .social-divider::before,
        .social-divider::after {
            content: "";
            flex: 1;
            height: 1px;
            background: #e8e8ec;
        }
        .social-divider span { white-space: nowrap; }
    </style>
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

                <div class="social-auth" aria-label="Connexion avec un réseau social">
                    <p class="social-auth-label">Continuer avec</p>
                    <div class="social-auth-row">
                        <a class="social-btn social-btn--google" href="{{ route('auth.social.redirect', ['provider' => 'google']) }}" aria-label="Continuer avec Google" title="Continuer avec Google">
                            <span class="social-mark" aria-hidden="true">
                                <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false">
                                    <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                                    <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                                    <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                                    <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                                </svg>
                            </span>
                        </a>
                        <a class="social-btn social-btn--facebook" href="{{ route('auth.social.redirect', ['provider' => 'facebook']) }}" aria-label="Continuer avec Facebook" title="Continuer avec Facebook">
                            <span class="social-mark" aria-hidden="true">
                                <svg viewBox="0 0 24 24" width="20" height="20" fill="#1877F2">
                                    <path d="M24 12.073C24 5.405 18.627 0 12 0S0 5.405 0 12.073C0 18.1 4.388 23.094 10.125 24v-8.437H7.078v-3.49h3.047V9.41c0-3.025 1.792-4.697 4.533-4.697 1.312 0 2.686.236 2.686.236v2.97h-1.513c-1.491 0-1.956.93-1.956 1.886v2.267h3.328l-.532 3.49h-2.796V24C19.612 23.094 24 18.1 24 12.073z"/>
                                </svg>
                            </span>
                        </a>
                        <a class="social-btn social-btn--linkedin" href="{{ route('auth.social.redirect', ['provider' => 'linkedin']) }}" aria-label="Continuer avec LinkedIn" title="Continuer avec LinkedIn">
                            <span class="social-mark" aria-hidden="true">
                                <svg viewBox="0 0 24 24" width="20" height="20" fill="#0A66C2">
                                    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.266 2.37 4.266 5.455v6.286zM5.337 7.433a2.062 2.062 0 1 1 0-4.124 2.062 2.062 0 0 1 0 4.124zM6.814 20.452H3.861V9h2.953v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
                                </svg>
                            </span>
                        </a>
                    </div>
                    <div class="social-divider" role="separator"><span>ou avec votre e-mail</span></div>
                </div>

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
