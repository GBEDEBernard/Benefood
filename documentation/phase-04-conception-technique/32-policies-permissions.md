# J32 — Policies / Permissions & cumul de rôles

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J32

---

## 1. Principe sécurité

> **Le rôle/mode déclaré par le mobile n'est JAMAIS une autorisation.** L'autorisation est vérifiée côté serveur via Roles/Permissions + **Policies** sur chaque objet. Le « contexte actif » sert uniquement à l'expérience et à la navigation.

## 2. Modèle RBAC

- `roles` → slugs : `porteuse`, `admin-technique`, `vendor`, `client`, `driver-independent`, `driver-beninfood`.
- `permissions` → slugs par module (ex. `orders.vendor.accept`, `orders.client.cancel`, `admin.vendors.suspend`, `payments.refund`).
- `role_permission` : rôle ↔ permission.
- `user_roles` : user ↔ rôle (+ `is_active` = contexte courant).
- Un utilisateur peut avoir **plusieurs rôles** → plusieurs permissions cumulées.

## 3. Matrice rôle → permissions (référence)

| Permission | Porteuse | Admin tech | Vendor | Client | Driver indép. | Driver Béninfood |
|------------|:--------:|:----------:|:------:|:------:|:-------------:|:----------------:|
| auth.* (connexion/profil) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| vendors.manage (son compte) | — | — | ✅ | — | — | — |
| vendors.approve/suspend | ✅ | ✅ | — | — | — | — |
| catalog.create/edit (son) | — | — | ✅ | — | — | — |
| cart.* (le sien) | — | — | — | ✅ | — | — |
| orders.client.view (siennes) | — | — | — | ✅ | — | — |
| orders.vendor.accept/… | — | — | ✅ | — | — | — |
| orders.cancel (règles) | ✅ | ✅ | ✅* | ✅* | — | — |
| payments.refund | ✅ | ✅ | — | — | — | — |
| finance.earnings (son) | — | — | ✅ | — | ✅ | ✅ |
| delivery.manage (courses) | ✅ | ✅ | — | — | ✅ | ✅ |
| driver.availability.toggle | — | — | — | — | ✅ | ✅ |
| admin.* (dashboard, pilotage) | ✅ | ✅ | — | — | — | — |
| audit.view | ✅ | ✅ | — | — | — | — |
| support.resolve (réclamations) | ✅ | ✅ | — | — | — | — |
| * selon statuts J12 | | | | | | |

## 4. Policies Laravel (liste)

| Policy | Méthodes typiques |
|--------|-------------------|
| `VendorPolicy` | view, update, manageDocuments, toggleOpen |
| `ProductPolicy` | view, create, update, delete, uploadImages |
| `CartPolicy` | view, addItem, updateItem, deleteItem, checkout (mono-vendeur de l'utilisateur) |
| `OrderPolicy` | view, create, cancel, accept, reject, prepare, ready (séparées par acteur) |
| `PaymentPolicy` | view, initiate, refund |
| `DeliveryPolicy` | view offers, accept, decline, pickup, deliver, incident |
| `ReviewPolicy` | create (uniquement après livraison), update, delete |
| `ComplaintPolicy` | create, view (sienne), reply (porteuse), resolve |
| `NotificationPolicy` | view (siennes), markRead |
| `AdminPolicy` | accès protégé par rôle porteuse/admin technique + permission |

### Exemple de pattern (OrderPolicy)
```php
public function accept(User $user, Order $order): bool
{
    // le vendeur du vendeur peut accepter, uniquement si statut paid
    return $user->id === $order->vendor->user_id
        && $order->status === OrderStatus::Paid
        && $user->hasPermission('orders.vendor.accept');
}
```

## 5. Cumul de rôles & contexte actif

1. `POST /me/active-role {role_slug}` : enregistre `user_roles.is_active = true` pour ce rôle (et false aux autres) + `last_used_at`.
2. `GET /me/roles` retourne les rôles de l'utilisateur (sans tri par préférences côté serveur — l'app affiche dans l'ordre retourné).
3. **Le contexte actif est utilisé par**: le router Flutter, les deep-links, et éventuellement pour donner un *default scope* (ex. `/vendors/me/orders`), **jamais** pour décider d'une autorisation.
4. Chaque endpoint sensible **révèle le scope** à partir des données (ex. `order.vendor_id == auth()->id()`) et non du contexte déclaré.

## 6. Middleware & Gates

- `auth:sanctum` sur toutes les routes (hors auth/public/webhooks).
- `permission:admin.dashboard` (middleware personnalisé `HasPermission`) sur les routes `/admin/*`.
- Gates ou checks de Policies dans chaque contrôleur (`$this->authorize(...)`).
- Middleware `EnsureActiveRoleExists` optionnel (si l'utilisateur a plusieurs rôles et doit choisir avant usage mobile).

## 7. Tests à prévoir (J53/J185)

- [ ] Accès interdit 403 pour chaque rôle sur les ressources d'autrui (IDOR)
- [ ] `paid` commande : seul le vendeur peut `accept` ; un client ne peut pas
- [ ] Un utilisateur client+vendeur : bascule de mode sans perdre session ni droits
- [ ] Le contexte déclaré ne peut jamais escalader les permissions
- [ ] Cart d'un utilisateur : seuls les siens accessibles

## 8. Critères d'acceptation

- [ ] RBAC user_roles + role_permission en place
- [ ] Policies couvrant les entités sensibles (§4)
- [ ] Cumul de rôles et contexte actif implémentés
- [ ] Le contexte ne constitue pas une autorisation (tests IDOR + mode)
- [ ] Middleware `permission` pour admin