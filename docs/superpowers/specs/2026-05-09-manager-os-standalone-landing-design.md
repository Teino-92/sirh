# Manager OS Standalone — Landing & Marque (Phase 1)

**Date** : 2026-05-09
**Statut** : 📋 Spec — en attente validation
**Phase** : Marque + Landing uniquement (extraction repo gardée en backlog)

---

## Contexte

Le repo `izi-rh` héberge actuellement deux produits côte à côte : **Manager OS** (B2C manager, 19 €/mois) et **SIRH** (B2B Essentiel/Pro). La home `/` actuelle est un hub présentant les deux.

L'objectif business : **vendre Manager OS comme produit autonome**. Le SIRH n'est plus mis en avant publiquement.

Cette phase ne touche pas au code applicatif (domaines, models, billing). Elle pivote uniquement la marque publique et la landing.

---

## Scope

### Inclus
- Pivot home `/` → landing Manager OS standalone, nouvelle DA "Soft Power"
- Page `/sirh` conservée mais retirée des moteurs (`noindex`) et masquée des nav publiques
- Route `/manager-os` redirigée vers `/` (la home **est** désormais la page Manager OS)
- Nouveau design system landing : palette lilas/sage/pêche, Instrument Serif + Inter, animations Stimulus
- Pricing affiché : 19 €/mois sans engagement OU 200 €/an (toggle)

### Exclus (backlog)
- Extraction Manager OS dans repo séparé (Phase 1-2 du `MANAGER_OS_STANDALONE.md`)
- DETACH_AUDIT.md des dépendances Manager OS / SIRH
- Sous-domaine ou domaine custom
- Stripe standalone (les prix existants restent en place)
- Refonte du dashboard interne post-login (DA reste actuelle in-app)

---

## Architecture

### Routes (config/routes.rb)

| Route | Avant | Après |
|---|---|---|
| `/` | `pages#home` (hub 2 produits) | `pages#home` (landing Manager OS standalone) |
| `/manager-os` | `pages#manager_os` | redirect 301 → `/` |
| `/sirh` | `pages#sirh` | inchangé, mais `<meta robots="noindex,nofollow">` |

### Vues touchées

- `app/views/pages/home.html.erb` — **réécriture complète** (nouvelle landing)
- `app/views/pages/manager_os.html.erb` — **supprimé** (contenu absorbé par home)
- `app/views/pages/sirh.html.erb` — ajout meta `noindex`, retrait liens internes vers SIRH dans header global
- `app/views/layouts/application.html.erb` (ou layout marketing dédié) — Google Fonts, retrait lien SIRH du nav, ajout lien discret SIRH en footer

### Design system

Tokens centralisés dans `tailwind.config.js` (ou équivalent v4 selon stack actuelle) :

```js
theme.extend.colors = {
  primary:  '#7C6FF7', // Lilas vif
  success:  '#7BAE8A', // Sage doux
  warning:  '#F4A96A', // Pêche ambre
  border:   '#E4E2F0', // Gris lavande
  surface:  '#FFFFFF',
  bg:       '#F8F7F4', // Blanc brume
  text:     '#1E1E2E', // Ardoise profond
  muted:    '#6B6B8A',
}
theme.extend.fontFamily = {
  serif: ['Instrument Serif', 'serif'],
  sans:  ['Inter', 'sans-serif'],
}
theme.extend.borderRadius = {
  xl:  '16px',
  '2xl': '24px',
}
```

Google Fonts dans `<head>` du layout :
```html
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

Hiérarchie typo : `h1`/`h2`/`h3` → Instrument Serif. Body, UI, labels → Inter.

### Stimulus controllers

Quatre nouveaux controllers dans `app/javascript/controllers/` :

| Controller | Rôle | Dépendance |
|---|---|---|
| `blob_controller.js` | Animation morphing CSS keyframes en background hero. CSS custom properties anime border-radius, durée 8s, ease-in-out infinite alternate. | Aucune |
| `reveal_controller.js` | Scroll reveal via IntersectionObserver natif. Classes `opacity-0 translate-y-4` → `opacity-100 translate-y-0`, transition 400ms ease-out. | Aucune |
| `confetti_controller.js` | Feedback positif (bouton CTA, validation). Couleurs primary/success/warning. | `canvas-confetti` (~3kb) via importmap |
| `input_focus_controller.js` | Micro-interactions form newsletter/contact : pulse border primary au focus, success/error visuel au blur. | Aucune |

**canvas-confetti** : ajouter `pin "canvas-confetti", to: "https://ga.jspm.io/npm:canvas-confetti@1.9.3/dist/confetti.module.mjs"` dans `config/importmap.rb`.

---

## Landing — Sections

Toutes les sections sauf Hero portent `data-controller="reveal"`.

### 1. Hero
- Background : `<div data-controller="blob">` formes morphantes lilas/pêche, opacité ~0.3
- Headline serif H1 : *"Le manager OS qui remplace votre Excel."* (à raffiner copy)
- Sous-titre Inter muted : positionnement court (1:1, objectifs, onboarding équipe)
- CTA primaire : "Essayer gratuitement" → checkout Manager OS
- CTA secondaire : "Voir comment ça marche" → ancre #solution
- Confetti déclenché sur clic CTA primaire

### 2. Problème
- Titre serif : *"Vous managez avec Excel ?"*
- 3 punchlines courtes (Excel, Slack noyé, post-it perdus)
- Visuel/illustration light

### 3. Solution
- 3 cards features avec scroll reveal séquentiel :
  - **1:1 structurés** — modèle d'agenda, suivi, historique
  - **Objectifs & OKR** — alignement équipe, revue trimestrielle
  - **Onboarding** — checklist nouveaux entrants, first 90 days
- Chaque card : icône, titre serif, 2 lignes Inter

### 4. Social proof
- 3 témoignages **fictifs** (personas réalistes) :
  - Manager startup tech (équipe 8)
  - Lead retail (équipe 12)
  - Responsable agence (équipe 6)
- Format card : photo placeholder, nom, rôle, citation 2-3 lignes

### 5. Pricing
- Toggle **Mensuel / Annuel** (Stimulus simple)
- **Mensuel** : `19 €/mois` — sans engagement
- **Annuel** : `200 €/an` — économise 28 € (≈ 2 mois offerts)
- Bullet list : *6 membres inclus · +2 €/mois par membre supplémentaire · Sans engagement · Annulation en 1 clic*
- CTA : "Commencer maintenant"

### 6. Footer
- Liens légaux : CGU, Politique confidentialité, Mentions légales
- Lien discret "SIRH pour entreprise" → `/sirh` (nofollow)
- Logo Izi-RH (marque parapluie) en petit

---

## Comportement multi-pages

### Header global
- Retirer le lien SIRH du nav (visible uniquement sur `/sirh`)
- Logo → home `/`
- CTA header : "Essayer Manager OS"

### Page `/sirh`
```erb
<% content_for :head do %>
  <meta name="robots" content="noindex, nofollow">
<% end %>
```
Conservée intacte côté contenu. Plus de lien depuis nav publique. Accès direct via URL ou commerciaux.

### Sitemap & robots.txt
- Retirer `/sirh` du sitemap public
- `robots.txt` : `Disallow: /sirh` (par sécurité, en plus du meta)

---

## Données / I18n

Aucune donnée DB touchée. Tout le copy landing vit dans des fichiers I18n FR :
- `config/locales/marketing.fr.yml` (nouveau) — sections home Manager OS
- Pas de traduction EN cette phase

---

## Tests

### RSpec (`spec/features/`)
- `home_spec.rb` : visite `/` → présence headline, CTA, sections clés
- `sirh_noindex_spec.rb` : `/sirh` retourne meta `robots=noindex`
- `manager_os_redirect_spec.rb` : `/manager-os` retourne 301 vers `/`

### Manuel
- DevTools mobile 375px : toutes sections lisibles, blob ne déborde pas
- Lighthouse : score perf ≥ 85, a11y ≥ 95
- Animations désactivées si `prefers-reduced-motion: reduce`

---

## Multi-tenant & sécurité

Aucun impact. Routes publiques `/`, `/sirh` ne touchent pas aux données tenant. Pundit non concerné.

---

## Risques & mitigations

| Risque | Mitigation |
|---|---|
| SEO existant `/manager-os` | Redirect 301 → préserve link juice |
| SEO existant `/sirh` ranké | Acceptable : volonté de désindexer |
| Clients SIRH existants confus par pivot home | Email comm + lien SIRH conservé en footer |
| Performance fonts Google | `display=swap` + preconnect |
| Accessibilité animations | `prefers-reduced-motion` désactive blob/reveal |

---

## Critères d'acceptation

- [ ] Home `/` affiche landing Manager OS standalone (6 sections)
- [ ] DA Soft Power appliquée (palette, fonts, radius) sur la home
- [ ] 4 Stimulus controllers fonctionnels (blob, reveal, confetti, input_focus)
- [ ] Pricing toggle mensuel/annuel **visuellement** fonctionnel (affichage 19 €/mois ou 200 €/an). CTA pointe vers checkout mensuel existant tant que le prix Stripe annuel n'est pas créé (suivi en backlog).
- [ ] `/manager-os` → 301 vers `/`
- [ ] `/sirh` retourne `<meta robots="noindex,nofollow">`
- [ ] Lien SIRH retiré du header global, présent uniquement en footer (nofollow)
- [ ] `robots.txt` interdit `/sirh`
- [ ] Tests features verts
- [ ] Lighthouse mobile : perf ≥ 85, a11y ≥ 95
- [ ] `prefers-reduced-motion` respecté

---

## Hors scope (backlog Phase 2+)

- Extraction code Manager OS → repo séparé (`MANAGER_OS_STANDALONE.md` Phase 1-2)
- DETACH_AUDIT.md des dépendances inter-domaines
- Sous-domaine `manager-os.izi-rh.com` ou domaine custom
- Stripe standalone / nouveau compte
- Page tarif annuel Stripe (création prix `manager_os_yearly_200_eur`) — peut nécessiter prix Stripe avant CTA fonctionnel
- Refonte DA dashboard post-login (in-app)
- Versions EN
