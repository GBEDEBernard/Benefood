# J19 — Maquette : Inscription / Connexion / Contexte actif

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J19

> Wireframe fonctionnel (spec). Les maquettes visuelles (Figma) seront alignées sur ce document.

---

## 1. Flux global

```
Splash ──▶ [Session exists?] ──► Router (contexte actif ou sélecteur)
                  │ no
                  ▼
              Landing (Connexion / Inscription)
                  │
            ┌─────┴─────┐
            ▼           ▼
        Connexion   Inscription
            │           └──▶ choix rôle initial (facultatif)
            ▼
      Récupération rôles (GET /me)
            │
            ├── 1 rôle      → Router vers contexte
            └── plusieurs   → Écran "Sélection du contexte"
```

## 2. Écrans

### 2.1 Splash
- Logo Béninfood (asset `Logo.jpeg`)
- Restauration de session : lecture du token sécurisé (`flutter_secure_storage`)
- Redirection : si session valide → accueil du contexte actif (ou sélecteur si multi-rôles) ; sinon → Landing
- Durée max ~2s ; bouton d'erreur réseau éventuel (J24)

### 2.2 Landing
| Composant | Détail |
|-----------|--------|
| Logo | Centré |
| Title | « Bienvenue sur Béninfood » |
| Bouton **Se connecter** | Primaire, pleine largeur |
| Bouton **Créer un compte** | Secondaire, pleine largeur |
| Lien « Mot de passe oublié ? » | redirige vers reset |

### 2.3 Connexion
| Champ | Type | Validation |
|-------|------|-----------|
| Numéro de téléphone OU email | Text | présent, format |
| Mot de passe | Password | présent, ≥6 |
| Bouton « Se connecter » | Submit | envoi POST /auth/login |
| Lien « Mot de passe oublié ? » | — | → écran reset |
| Retour | — | → Landing |

Erreurs (J24) : identifiants invalides (401), compte non vérifié, compte suspendu, erreur réseau.

### 2.4 Inscription
**Étape 1 — Coordonnées**
| Champ | Validation |
|-------|-----------|
| Nom complet | obligatoire |
| Numéro de téléphone | obligatoire, format (228 XX XX XX XX) |
| Email | optionnel, format |
| Mot de passe | ≥8, confirmation |

**Étape 2 — Rôle(s) souhaité(s)**
- Choix du/des rôles : Client (défaut coché) / Vendeur / Livreur
- L'utilisateur peut choisir plusieurs rôles (ex. Client + Vendeur)
- Textes d'aide courts par rôle

**Étape 3 — Validation / OTP**
- Envoi d'un code de vérification par SMS/email selon les règles Phase 06
- Écran de saisie du code + « Renvoyer le code » (timer)

**Étape 4 — Succès**
- Message de confirmation
- Bouton « Continuer » → connexion automatique ou retour Login selon la règle
- Si rôle Vendeur/Livreur coché : proposition de poursuivre l'activation (J20/J21/J22)

### 2.5 Mot de passe oublié / reset
- Écran demande : saisie téléphone/email → envoi code
- Écran code OTP
- Écran nouveau mot de passe (≥8, confirmation)
- Succès → retour login

### 2.6 Sélection du contexte actif (multi-rôles)
| Composant | Détail |
|-----------|--------|
| Title | « Quel espace voulez-vous ouvrir ? » |
| Cartes | Client / Vendeur / Livreur (avec icône + description courte), une par rôle disponible |
| Bouton mémoire | « Se souvenir de ce mode » (optionnel : persist = dernier contexte) |
| Footer | Bouton « Déconnexion » |

Règles :
- Cet écran s'affiche à la connexion **si l'utilisateur a >1 rôle**.
- Le choix **ne modifie pas les permissions** : il ne fait que définir le contexte d'expérience (`POST /me/active-role`).
- La bascule de mode est possible depuis le menu latéral à tout moment (voir composants J24).

## 3. Navigation
- Splash → (session) → Router
- Landing ↔ Login ↔ Inscription ↔ Mot de passe oublié
- Connexion OK → Sélecteur (si multi-rôles) sinon Accueil du contexte

## 4. Règles UX
- Champs mono-ligne, labels persistants (floating labels)
- Boutons : hauteur min 48px, pleine largeur sur mobile
- États chargement : spinner dans le bouton (désactivé pendant l'appel)
- Erreurs : message inline sous le champ + toast pour les erreurs globales

## 5. Critères de validation (J25 appliqué à ce parcours)
- [ ] Parcours Inscription complète (coordonnées → rôles → OTP)
- [ ] Connexion + restauration de session OK
- [ ] Sélecteur de contexte visible pour multi-rôles
- [ ] Changement de mode accessible ensuite (J24)
- [ ] Tous les états d'erreur définis