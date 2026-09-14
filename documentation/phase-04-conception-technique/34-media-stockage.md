# J34 — Stratégie fichiers / media

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J34

---

## 1. Types de fichiers gérés

| Type | Propriétaire | Exemples |
|------|--------------|----------|
| Produit | image principale + secondaires | jpg/png/webp produits |
| Boutique | logo + couverture | jpg/png |
| Document vendeur | pièce d'identité, registre commerce, photo boutique | pdf/jpg/png |
| Document livreur | pièce d'identité, permis, assurance | pdf/jpg/png |
| Preuve livraison | photo de preuve (livreur) | jpg/webp |
| Attachements réclamation | photos client | jpg/png |

## 2. Pipeline médias (upload → livraison)

```
Upload (multipart) → Validation (mime, taille) → Compression/optimisation
  → stockage (disk) → URL sécurisée → variantes éventuelles (thumbnail)
```

## 3. Règles d'upload

| Règle | Valeur |
|-------|--------|
| Taille max | Image : 5 Mo ; PDF : 10 Mo |
| MIME autorisés | jpeg, png, webp ; pdf pour documents |
| Détection MIME | via le contenu (pas seulement l'extension) |
| Auth | uploads accessibles seulement connecté (sauf images publiques via URL signée/stable) |
| Anti-virus | optionnel (scan si solution dispo) — au minimum validation stricte MIME |

## 4. Compression & variantes

- **Image principale produit** : redim à `800x800` (cover), avatar `400x400` si thumbnail ; WebP préféré si supporté.
- Standard `intervention/image` (Php 8 : intervention/image v3) ou `spatie/laravel-image-optimizer`.
- Conserver l'original pendant X jours puis purge (option).

## 5. Stockage

| Env | Disk | Note |
|-----|------|------|
| local/dev | `local` + `public` | lien symbolique `php artisan storage:link` |
| staging/prod | `s3`-compatible ou `public/disk` | config via `FILESYSTEM_DISK` |

- Chemin normalisé : `/{entity}/{id}/{uuid}.{ext}` (ex. `products/shop-abc/img1.webp`).
- Uploads non publics (documents) stockés sur disk privé, servis par endpoint sécurisé (contrôle policy + expirable).

## 6. URLs

- **Images publiques** (produits/boutiques) : URL stable `/storage/...` sous CDN optionnel en prod.
- **Documents privés** : pas d'URL directe — endpoint `GET /api/v1/files/{file}` avec policy (propriétaire ou admin) ; jamais exposé publiquement.
- Jetage : `signed URL` (Laravel `URL::temporarySignedRoute`) possible pour partage temporaire.

## 7. Media via adapter

- `StorageGateway` (interface) → implémentation `LocalStorageGateway`, `S3Gateway` (plus tard).
- Le domaine ne dépend que de l'interface (réversibilité de si Quoi).

## 8. Ouverture/fermeture (uploads par rôle)

| Ressource | Qui upload |
|-----------|-----------|
| Products/images | Vendeur (propriétaire), Admin |
| Boutique logo/cover | Vendeur, Admin |
| Documents vendeur | Vendeur (validation par porteuse) |
| Documents livreur | Livreur (validation par porteuse) |
| Preuve livraison | Livreur |
| Attachements réclamation | Client/Livreur |

## 9. Critères d'acceptation

- [ ] Validation stricte (mime, taille) au niveau serveur
- [ ] Compression/redim automatique
- [ ] Documents privés jamais servis publiquement (endpoint protégé)
- [ ] URLs stables + option CDN en prod
- [ ] Stockage/adapter isolé (StorageGateway)