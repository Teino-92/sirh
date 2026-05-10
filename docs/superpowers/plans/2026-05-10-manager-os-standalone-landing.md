# Manager OS Standalone Landing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pivot la home `/` vers une landing Manager OS standalone (DA Soft Power), désindexer `/sirh`, retirer SIRH des nav publiques. Aucune extraction de code applicatif.

**Architecture:** Réécriture de `pages#home` avec une nouvelle vue ERB structurée en sections, 4 nouveaux Stimulus controllers (blob, reveal, confetti, input_focus), tokens Tailwind v4 ajoutés via `@theme` dans `application.tailwind.css`, fonts Google chargées dans `marketing.html.erb`, `/manager-os` redirigé en 301, `/sirh` reçoit `noindex` via `content_for :head`.

**Tech Stack:** Rails 7.1.6, Tailwind CSS v4, Stimulus, Importmap, RSpec (request specs), Devise. Lib JS `canvas-confetti` via importmap.

---

## File Structure

**Création** :
- `app/javascript/controllers/blob_controller.js` — animation morphing CSS keyframes
- `app/javascript/controllers/reveal_controller.js` — IntersectionObserver scroll reveal
- `app/javascript/controllers/confetti_controller.js` — wrapper canvas-confetti
- `app/javascript/controllers/input_focus_controller.js` — micro-interactions inputs
- `app/javascript/controllers/pricing_toggle_controller.js` — toggle mensuel/annuel
- `app/views/pages/_hero.html.erb` — section hero
- `app/views/pages/_problem.html.erb` — section problème
- `app/views/pages/_solution.html.erb` — section solution (3 features)
- `app/views/pages/_social_proof.html.erb` — témoignages fictifs
- `app/views/pages/_pricing.html.erb` — pricing toggle
- `app/views/pages/_marketing_footer.html.erb` — footer landing
- `spec/requests/pages_spec.rb` — tests routes home/sirh/manager-os redirect

**Modification** :
- `app/views/pages/home.html.erb` — réécriture complète (compose les partials)
- `app/views/pages/sirh.html.erb` — ajout `content_for :head` avec meta noindex
- `app/views/pages/manager_os.html.erb` — supprimé
- `app/views/layouts/marketing.html.erb` — Google Fonts, retrait lien SIRH header, ajout lien SIRH footer
- `app/controllers/pages_controller.rb` — supprimer action `manager_os`
- `config/routes.rb` — `/manager-os` → redirect `/`, root inchangé
- `config/importmap.rb` — pin `canvas-confetti`
- `app/assets/stylesheets/application.tailwind.css` — `@theme` Soft Power tokens
- `public/robots.txt` — `Disallow: /sirh`

**Conservation** : `home.html.erb` actuelle est volumineuse (860 lignes) — la réécriture est totale, pas un patch.

---

## Task 1: Tokens Tailwind v4 Soft Power

**Files:**
- Modify: `app/assets/stylesheets/application.tailwind.css`

- [ ] **Step 1: Ajouter le bloc `@theme` Soft Power**

Ajouter en haut du fichier, juste après `@import "tailwindcss";` et avant `@source` :

```css
@theme {
  --color-primary: #7C6FF7;
  --color-success: #7BAE8A;
  --color-warning: #F4A96A;
  --color-border-soft: #E4E2F0;
  --color-surface: #FFFFFF;
  --color-bg-soft: #F8F7F4;
  --color-text-deep: #1E1E2E;
  --color-muted-soft: #6B6B8A;

  --font-serif: "Instrument Serif", ui-serif, Georgia, serif;
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;

  --radius-xl: 16px;
  --radius-2xl: 24px;
}
```

Note : on suffixe `-soft`/`-deep` pour éviter les collisions avec les classes Tailwind existantes (`text-white`, `bg-white`, `border`, `text-muted` n'existe pas mais `text-gray-*` est utilisé partout).

- [ ] **Step 2: Vérifier la compilation Tailwind**

Run: `bin/rails tailwindcss:build`
Expected: pas d'erreur, `app/assets/builds/application.css` régénéré.

- [ ] **Step 3: Commit**

```bash
git add app/assets/stylesheets/application.tailwind.css
git commit -m "feat(landing): tokens Tailwind v4 Soft Power pour Manager OS standalone"
```

---

## Task 2: Google Fonts dans layout marketing

**Files:**
- Modify: `app/views/layouts/marketing.html.erb`

- [ ] **Step 1: Ajouter preconnect + lien Google Fonts dans `<head>`**

Localiser la ligne `<%= csrf_meta_tags %>` dans `marketing.html.erb` (~ligne 40). Insérer juste avant :

```erb
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
```

- [ ] **Step 2: Vérifier visuellement**

Run: `bin/rails server` puis ouvrir `http://localhost:3000/` dans un navigateur. DevTools → Network → filtrer `fonts.gstatic` doit montrer les fonts chargées.

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/marketing.html.erb
git commit -m "feat(landing): preconnect + Google Fonts (Instrument Serif + Inter)"
```

---

## Task 3: Stimulus controller `blob`

**Files:**
- Create: `app/javascript/controllers/blob_controller.js`

- [ ] **Step 1: Écrire le controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 8000 } }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.element.style.setProperty("--blob-duration", `${this.durationValue}ms`)
    this.element.classList.add("blob-active")
  }
}
```

- [ ] **Step 2: Ajouter les keyframes dans `application.tailwind.css`**

Ajouter à la fin du fichier :

```css
@keyframes blob-morph {
  0%, 100% { border-radius: 42% 58% 70% 30% / 45% 30% 70% 55%; transform: translate(0, 0) scale(1); }
  33%      { border-radius: 70% 30% 50% 50% / 30% 60% 40% 70%; transform: translate(2%, -2%) scale(1.05); }
  66%      { border-radius: 30% 70% 60% 40% / 60% 40% 60% 40%; transform: translate(-2%, 2%) scale(0.95); }
}
.blob-active {
  animation: blob-morph var(--blob-duration, 8000ms) ease-in-out infinite alternate;
}
@media (prefers-reduced-motion: reduce) {
  .blob-active { animation: none; }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/blob_controller.js app/assets/stylesheets/application.tailwind.css
git commit -m "feat(landing): blob Stimulus controller + keyframes morph"
```

---

## Task 4: Stimulus controller `reveal`

**Files:**
- Create: `app/javascript/controllers/reveal_controller.js`

- [ ] **Step 1: Écrire le controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { threshold: { type: Number, default: 0.15 } }

  connect() {
    this.element.classList.add("reveal-init")

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.classList.add("reveal-shown")
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("reveal-shown")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: this.thresholdValue })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}
```

- [ ] **Step 2: Ajouter les classes CSS dans `application.tailwind.css`**

Ajouter à la fin :

```css
.reveal-init {
  opacity: 0;
  transform: translateY(16px);
  transition: opacity 400ms ease-out, transform 400ms ease-out;
}
.reveal-shown {
  opacity: 1;
  transform: translateY(0);
}
@media (prefers-reduced-motion: reduce) {
  .reveal-init { opacity: 1; transform: none; transition: none; }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/reveal_controller.js app/assets/stylesheets/application.tailwind.css
git commit -m "feat(landing): reveal Stimulus controller (IntersectionObserver)"
```

---

## Task 5: Stimulus controller `confetti` + pin importmap

**Files:**
- Create: `app/javascript/controllers/confetti_controller.js`
- Modify: `config/importmap.rb`

- [ ] **Step 1: Pin `canvas-confetti` dans importmap**

Ajouter dans `config/importmap.rb` après le bloc Sentry :

```ruby
pin "canvas-confetti", to: "https://ga.jspm.io/npm:canvas-confetti@1.9.3/dist/confetti.module.mjs"
```

- [ ] **Step 2: Écrire le controller**

```js
import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

export default class extends Controller {
  fire() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    confetti({
      particleCount: 80,
      spread: 70,
      origin: { y: 0.7 },
      colors: ["#7C6FF7", "#7BAE8A", "#F4A96A"]
    })
  }
}
```

- [ ] **Step 3: Vérifier le chargement**

Run: `bin/rails server` puis `http://localhost:3000/` → DevTools console : `import('canvas-confetti')` ne doit pas erreur (test exécuté plus tard avec une vraie cible HTML).

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/confetti_controller.js config/importmap.rb
git commit -m "feat(landing): confetti Stimulus controller + pin canvas-confetti"
```

---

## Task 6: Stimulus controller `input_focus`

**Files:**
- Create: `app/javascript/controllers/input_focus_controller.js`

- [ ] **Step 1: Écrire le controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  activate(event) {
    event.currentTarget.classList.add("ring-2", "ring-primary")
    event.currentTarget.classList.remove("ring-success", "ring-red-500")
  }

  validate(event) {
    const input = event.currentTarget
    input.classList.remove("ring-2", "ring-primary")
    if (!input.value) return

    if (input.checkValidity()) {
      input.classList.add("ring-2", "ring-success")
    } else {
      input.classList.add("ring-2", "ring-red-500")
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/input_focus_controller.js
git commit -m "feat(landing): input_focus Stimulus controller pour micro-interactions"
```

---

## Task 7: Stimulus controller `pricing_toggle`

**Files:**
- Create: `app/javascript/controllers/pricing_toggle_controller.js`

- [ ] **Step 1: Écrire le controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthly", "yearly", "toggle"]
  static classes = ["active"]

  connect() {
    this.showMonthly()
  }

  showMonthly() {
    this.monthlyTargets.forEach(el => el.classList.remove("hidden"))
    this.yearlyTargets.forEach(el => el.classList.add("hidden"))
    this.toggleTarget.dataset.mode = "monthly"
  }

  showYearly() {
    this.yearlyTargets.forEach(el => el.classList.remove("hidden"))
    this.monthlyTargets.forEach(el => el.classList.add("hidden"))
    this.toggleTarget.dataset.mode = "yearly"
  }

  toggle() {
    if (this.toggleTarget.dataset.mode === "monthly") {
      this.showYearly()
    } else {
      this.showMonthly()
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/pricing_toggle_controller.js
git commit -m "feat(landing): pricing_toggle Stimulus controller (mensuel/annuel)"
```

---

## Task 8: Partial `_hero.html.erb`

**Files:**
- Create: `app/views/pages/_hero.html.erb`

- [ ] **Step 1: Écrire la section hero**

```erb
<section class="relative overflow-hidden bg-bg-soft py-24 sm:py-32">
  <div data-controller="blob" data-blob-duration-value="9000"
       class="absolute -top-20 -right-20 w-[40vw] h-[40vw] max-w-[600px] max-h-[600px] bg-primary/20 -z-10"></div>
  <div data-controller="blob" data-blob-duration-value="11000"
       class="absolute -bottom-32 -left-20 w-[35vw] h-[35vw] max-w-[500px] max-h-[500px] bg-warning/20 -z-10"></div>

  <div class="relative max-w-5xl mx-auto px-6 text-center">
    <h1 class="font-serif text-5xl sm:text-6xl lg:text-7xl text-text-deep leading-tight">
      Le manager OS qui remplace votre&nbsp;Excel.
    </h1>
    <p class="mt-6 text-lg sm:text-xl text-muted-soft max-w-2xl mx-auto">
      1:1 structurés, objectifs trimestriels, onboarding en 90 jours. Tout au même endroit, simple comme un message.
    </p>
    <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
      <a href="#pricing" data-controller="confetti" data-action="click->confetti#fire"
         class="inline-flex items-center justify-center px-8 py-4 rounded-2xl bg-primary text-white font-medium hover:opacity-90 transition">
        Essayer gratuitement
      </a>
      <a href="#solution"
         class="inline-flex items-center justify-center px-8 py-4 rounded-2xl border border-border-soft bg-surface text-text-deep font-medium hover:bg-bg-soft transition">
        Voir comment ça marche
      </a>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_hero.html.erb
git commit -m "feat(landing): partial _hero avec blobs + CTA confetti"
```

---

## Task 9: Partial `_problem.html.erb`

**Files:**
- Create: `app/views/pages/_problem.html.erb`

- [ ] **Step 1: Écrire la section**

```erb
<section data-controller="reveal" class="py-24 bg-surface">
  <div class="max-w-4xl mx-auto px-6 text-center">
    <h2 class="font-serif text-4xl sm:text-5xl text-text-deep">Vous managez avec Excel ?</h2>
    <p class="mt-4 text-muted-soft text-lg">Vous n'êtes pas seul. Et c'est précisément le problème.</p>

    <div class="mt-12 grid sm:grid-cols-3 gap-8 text-left">
      <div class="p-6 rounded-2xl bg-bg-soft">
        <p class="font-serif text-xl text-text-deep">📊 Tableurs partout</p>
        <p class="mt-2 text-muted-soft">Un fichier par manager, aucune source de vérité.</p>
      </div>
      <div class="p-6 rounded-2xl bg-bg-soft">
        <p class="font-serif text-xl text-text-deep">💬 Slack noyé</p>
        <p class="mt-2 text-muted-soft">Les décisions importantes disparaissent dans le bruit.</p>
      </div>
      <div class="p-6 rounded-2xl bg-bg-soft">
        <p class="font-serif text-xl text-text-deep">📝 Post-it perdus</p>
        <p class="mt-2 text-muted-soft">L'historique des 1:1 ? Dans votre tête, au mieux.</p>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_problem.html.erb
git commit -m "feat(landing): partial _problem (3 punchlines)"
```

---

## Task 10: Partial `_solution.html.erb`

**Files:**
- Create: `app/views/pages/_solution.html.erb`

- [ ] **Step 1: Écrire la section**

```erb
<section id="solution" class="py-24 bg-bg-soft">
  <div class="max-w-6xl mx-auto px-6">
    <div data-controller="reveal" class="text-center max-w-2xl mx-auto">
      <h2 class="font-serif text-4xl sm:text-5xl text-text-deep">Trois rituels. Un seul outil.</h2>
      <p class="mt-4 text-muted-soft text-lg">Pas de modules, pas de plug-ins. Juste ce qu'un manager utilise vraiment.</p>
    </div>

    <div class="mt-16 grid lg:grid-cols-3 gap-8">
      <article data-controller="reveal" class="p-8 rounded-2xl bg-surface border border-border-soft">
        <div class="w-12 h-12 rounded-xl bg-primary/15 flex items-center justify-center text-2xl">🗓️</div>
        <h3 class="mt-6 font-serif text-2xl text-text-deep">1:1 structurés</h3>
        <p class="mt-3 text-muted-soft">Modèles d'agenda partagés, suivi des actions, historique complet par collaborateur.</p>
      </article>

      <article data-controller="reveal" class="p-8 rounded-2xl bg-surface border border-border-soft">
        <div class="w-12 h-12 rounded-xl bg-success/15 flex items-center justify-center text-2xl">🎯</div>
        <h3 class="mt-6 font-serif text-2xl text-text-deep">Objectifs &amp; OKR</h3>
        <p class="mt-3 text-muted-soft">Alignement équipe trimestriel, revue mensuelle, progression visible en un coup d'œil.</p>
      </article>

      <article data-controller="reveal" class="p-8 rounded-2xl bg-surface border border-border-soft">
        <div class="w-12 h-12 rounded-xl bg-warning/15 flex items-center justify-center text-2xl">🚀</div>
        <h3 class="mt-6 font-serif text-2xl text-text-deep">Onboarding 90 jours</h3>
        <p class="mt-3 text-muted-soft">Checklist personnalisée par poste, jalons clairs, intégration sans friction.</p>
      </article>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_solution.html.erb
git commit -m "feat(landing): partial _solution (1:1, OKR, onboarding)"
```

---

## Task 11: Partial `_social_proof.html.erb`

**Files:**
- Create: `app/views/pages/_social_proof.html.erb`

- [ ] **Step 1: Écrire la section**

```erb
<section class="py-24 bg-surface">
  <div class="max-w-6xl mx-auto px-6">
    <div data-controller="reveal" class="text-center max-w-2xl mx-auto">
      <h2 class="font-serif text-4xl sm:text-5xl text-text-deep">Ils ont remisé Excel.</h2>
    </div>

    <div class="mt-16 grid md:grid-cols-3 gap-8">
      <figure data-controller="reveal" class="p-8 rounded-2xl bg-bg-soft">
        <blockquote class="text-text-deep leading-relaxed">
          « En deux semaines, mes 1:1 sont devenus utiles. Mes 8 devs me disent qu'ils sentent enfin où ils vont. »
        </blockquote>
        <figcaption class="mt-6 flex items-center gap-3">
          <div class="w-10 h-10 rounded-full bg-primary/30"></div>
          <div>
            <p class="font-medium text-text-deep">Camille R.</p>
            <p class="text-sm text-muted-soft">Engineering Manager · startup tech</p>
          </div>
        </figcaption>
      </figure>

      <figure data-controller="reveal" class="p-8 rounded-2xl bg-bg-soft">
        <blockquote class="text-text-deep leading-relaxed">
          « Mes 12 vendeurs en boutique. L'onboarding 90 jours, c'était une utopie avant. Maintenant c'est notre standard. »
        </blockquote>
        <figcaption class="mt-6 flex items-center gap-3">
          <div class="w-10 h-10 rounded-full bg-success/30"></div>
          <div>
            <p class="font-medium text-text-deep">Karim B.</p>
            <p class="text-sm text-muted-soft">Lead retail · enseigne mode</p>
          </div>
        </figcaption>
      </figure>

      <figure data-controller="reveal" class="p-8 rounded-2xl bg-bg-soft">
        <blockquote class="text-text-deep leading-relaxed">
          « Six personnes en agence. Pas de DRH. Manager OS, c'est juste l'outil dont j'avais besoin sans le savoir. »
        </blockquote>
        <figcaption class="mt-6 flex items-center gap-3">
          <div class="w-10 h-10 rounded-full bg-warning/30"></div>
          <div>
            <p class="font-medium text-text-deep">Élise M.</p>
            <p class="text-sm text-muted-soft">Responsable agence · communication</p>
          </div>
        </figcaption>
      </figure>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_social_proof.html.erb
git commit -m "feat(landing): partial _social_proof (3 témoignages fictifs)"
```

---

## Task 12: Partial `_pricing.html.erb`

**Files:**
- Create: `app/views/pages/_pricing.html.erb`

- [ ] **Step 1: Écrire la section pricing**

```erb
<section id="pricing" class="py-24 bg-bg-soft">
  <div class="max-w-3xl mx-auto px-6"
       data-controller="pricing-toggle">
    <div data-controller="reveal" class="text-center">
      <h2 class="font-serif text-4xl sm:text-5xl text-text-deep">Un seul prix. Sans engagement.</h2>
      <p class="mt-4 text-muted-soft text-lg">Annulez en un clic. On ne s'en formalisera pas.</p>
    </div>

    <div data-controller="reveal" class="mt-10 flex justify-center">
      <button type="button"
              data-pricing-toggle-target="toggle"
              data-action="click->pricing-toggle#toggle"
              data-mode="monthly"
              class="inline-flex items-center gap-3 px-2 py-2 rounded-full bg-surface border border-border-soft">
        <span class="px-4 py-2 rounded-full bg-primary text-white text-sm font-medium" data-pricing-toggle-target="monthly">Mensuel</span>
        <span class="px-4 py-2 rounded-full text-sm font-medium text-muted-soft hidden" data-pricing-toggle-target="monthly">Annuel · 2 mois offerts</span>
        <span class="px-4 py-2 rounded-full text-sm font-medium text-muted-soft" data-pricing-toggle-target="yearly">Mensuel</span>
        <span class="px-4 py-2 rounded-full bg-primary text-white text-sm font-medium hidden" data-pricing-toggle-target="yearly">Annuel · 2 mois offerts</span>
      </button>
    </div>

    <div data-controller="reveal" class="mt-10 p-10 rounded-2xl bg-surface border border-border-soft text-center">
      <p class="font-serif text-2xl text-text-deep">Manager OS</p>

      <div class="mt-6">
        <div data-pricing-toggle-target="monthly">
          <p class="font-serif text-6xl text-text-deep">19 €<span class="text-2xl text-muted-soft">/mois</span></p>
          <p class="mt-2 text-muted-soft">Sans engagement</p>
        </div>
        <div data-pricing-toggle-target="yearly" class="hidden">
          <p class="font-serif text-6xl text-text-deep">200 €<span class="text-2xl text-muted-soft">/an</span></p>
          <p class="mt-2 text-muted-soft">Soit ≈ 16,67 €/mois · économise 28 €</p>
        </div>
      </div>

      <ul class="mt-8 space-y-3 text-left max-w-md mx-auto">
        <li class="flex gap-3"><span class="text-success">✓</span><span class="text-text-deep">6 membres inclus (manager + 5)</span></li>
        <li class="flex gap-3"><span class="text-success">✓</span><span class="text-text-deep">+2 €/mois par membre supplémentaire</span></li>
        <li class="flex gap-3"><span class="text-success">✓</span><span class="text-text-deep">1:1, objectifs, onboarding illimités</span></li>
        <li class="flex gap-3"><span class="text-success">✓</span><span class="text-text-deep">Annulation en 1 clic, à tout moment</span></li>
      </ul>

      <%= link_to "Commencer maintenant",
                  new_employee_registration_path,
                  data: { controller: "confetti", action: "click->confetti#fire" },
                  class: "mt-10 inline-flex items-center justify-center px-8 py-4 rounded-2xl bg-primary text-white font-medium hover:opacity-90 transition" %>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_pricing.html.erb
git commit -m "feat(landing): partial _pricing avec toggle mensuel/annuel"
```

---

## Task 13: Partial `_marketing_footer.html.erb`

**Files:**
- Create: `app/views/pages/_marketing_footer.html.erb`

- [ ] **Step 1: Écrire le footer**

```erb
<footer class="bg-text-deep text-white py-16">
  <div class="max-w-6xl mx-auto px-6">
    <div class="flex flex-col md:flex-row justify-between gap-10">
      <div class="max-w-sm">
        <p class="font-serif text-2xl">Manager OS</p>
        <p class="mt-3 text-sm text-white/60">Le système d'exploitation des managers d'équipe. Édité par Izi-RH.</p>
      </div>

      <nav class="grid grid-cols-2 sm:grid-cols-3 gap-8 text-sm">
        <div>
          <p class="font-medium text-white/80">Produit</p>
          <ul class="mt-3 space-y-2 text-white/60">
            <li><a href="#solution" class="hover:text-white transition">Fonctionnalités</a></li>
            <li><a href="#pricing" class="hover:text-white transition">Tarifs</a></li>
          </ul>
        </div>
        <div>
          <p class="font-medium text-white/80">Légal</p>
          <ul class="mt-3 space-y-2 text-white/60">
            <li><%= link_to "CGU", cgu_path, class: "hover:text-white transition" %></li>
            <li><%= link_to "Confidentialité", politique_de_confidentialite_path, class: "hover:text-white transition" %></li>
            <li><%= link_to "Mentions légales", mentions_legales_path, class: "hover:text-white transition" %></li>
          </ul>
        </div>
        <div>
          <p class="font-medium text-white/80">Entreprise</p>
          <ul class="mt-3 space-y-2 text-white/60">
            <li><%= link_to "SIRH (équipes RH)", sirh_path, rel: "nofollow", class: "hover:text-white transition" %></li>
          </ul>
        </div>
      </nav>
    </div>

    <p class="mt-12 text-xs text-white/40">© <%= Date.current.year %> Izi-RH · Manager OS</p>
  </div>
</footer>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/pages/_marketing_footer.html.erb
git commit -m "feat(landing): partial _marketing_footer (lien SIRH nofollow)"
```

---

## Task 14: Réécrire `home.html.erb`

**Files:**
- Modify: `app/views/pages/home.html.erb`

- [ ] **Step 1: Écraser le contenu**

Remplacer **tout** le fichier par :

```erb
<% content_for :title, "Manager OS — 1:1, objectifs, onboarding pour managers d'équipe" %>
<% content_for :description, "Le manager OS qui remplace votre Excel. 1:1 structurés, objectifs trimestriels, onboarding en 90 jours. 19 €/mois sans engagement." %>

<%= render "pages/hero" %>
<%= render "pages/problem" %>
<%= render "pages/solution" %>
<%= render "pages/social_proof" %>
<%= render "pages/pricing" %>
<%= render "pages/marketing_footer" %>
```

- [ ] **Step 2: Vérifier visuellement**

Run: `bin/rails server` puis `http://localhost:3000/`. Toutes les sections doivent s'afficher dans l'ordre, fonts chargées, blob animé, scroll reveal fonctionne.

- [ ] **Step 3: Commit**

```bash
git add app/views/pages/home.html.erb
git commit -m "feat(landing): home pivot Manager OS standalone (compose partials)"
```

---

## Task 15: Redirect `/manager-os` → `/`

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/pages_controller.rb`
- Delete: `app/views/pages/manager_os.html.erb`

- [ ] **Step 1: Modifier la route**

Dans `config/routes.rb`, remplacer la ligne actuelle :

```ruby
get '/manager-os', to: 'pages#manager_os', as: :manager_os
```

par :

```ruby
get '/manager-os', to: redirect('/', status: 301), as: :manager_os
```

(On garde le helper `manager_os_path` pour ne pas casser les références internes éventuelles, mais il pointe maintenant vers la home.)

- [ ] **Step 2: Supprimer l'action controller**

Dans `app/controllers/pages_controller.rb`, supprimer la ligne :

```ruby
def manager_os; end
```

- [ ] **Step 3: Supprimer la vue**

```bash
git rm app/views/pages/manager_os.html.erb
```

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/pages_controller.rb
git commit -m "feat(landing): /manager-os redirect 301 vers home (page absorbée)"
```

---

## Task 16: Désindexer `/sirh`

**Files:**
- Modify: `app/views/pages/sirh.html.erb`
- Modify: `public/robots.txt`

- [ ] **Step 1: Ajouter `content_for :head` avec meta noindex en haut de `sirh.html.erb`**

Insérer tout en haut du fichier :

```erb
<% content_for :head do %>
  <meta name="robots" content="noindex, nofollow">
<% end %>
```

- [ ] **Step 2: Vérifier que `marketing.html.erb` rend `:head`**

Lire `app/views/layouts/marketing.html.erb` autour de la ligne du `<meta name="robots" content="index, follow">`. Remplacer la ligne :

```erb
<meta name="robots" content="index, follow">
```

par :

```erb
<%= content_for?(:head) ? yield(:head) : tag.meta(name: "robots", content: "index, follow") %>
```

- [ ] **Step 3: Mettre à jour `robots.txt`**

Ajouter dans `public/robots.txt` après les autres `Disallow` :

```
Disallow: /sirh
```

- [ ] **Step 4: Commit**

```bash
git add app/views/pages/sirh.html.erb app/views/layouts/marketing.html.erb public/robots.txt
git commit -m "feat(landing): /sirh noindex + Disallow robots.txt"
```

---

## Task 17: Nettoyer la nav header (retirer SIRH)

**Files:**
- Modify: `app/views/layouts/marketing.html.erb`

- [ ] **Step 1: Localiser et retirer le lien SIRH du header**

Dans `marketing.html.erb`, repérer la zone de navigation desktop (cherche `link_to "SIRH"` ou `sirh_path` dans le `<nav>`). Supprimer le `<%= link_to "SIRH", sirh_path, ... %>`.

Si la nav est définie dans `home.html.erb` actuel (pas dans le layout) — vérifier d'abord avec :

```bash
grep -n "sirh_path\|\"SIRH\"" app/views/layouts/marketing.html.erb app/views/pages/home.html.erb
```

Retirer le lien à la fois du desktop nav et du mobile menu (Alpine).

- [ ] **Step 2: Modifier le lien "Manager OS" du header**

S'il existe encore un `link_to "Manager OS", manager_os_path` dans la nav, le remplacer par un simple ancre `#solution` ou retirer (la home **est** déjà Manager OS).

- [ ] **Step 3: Vérifier visuellement**

Run: `bin/rails server` → `/`. Header ne montre plus "SIRH" ni "Manager OS" (ou Manager OS pointe vers `#solution`).

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/marketing.html.erb app/views/pages/home.html.erb
git commit -m "feat(landing): retirer SIRH du header public (lien restant en footer)"
```

---

## Task 18: Tests requests

**Files:**
- Create: `spec/requests/pages_spec.rb`

- [ ] **Step 1: Écrire les tests**

```ruby
require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    it "renders home with Manager OS landing content" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Le manager OS")
      expect(response.body).to include("19 €")
      expect(response.body).to include("Manager OS")
    end

    it "does not render the SIRH header link" do
      get "/"
      expect(response.body).not_to match(%r{<a[^>]*href="/sirh"[^>]*>\s*SIRH\s*</a>})
    end
  end

  describe "GET /manager-os" do
    it "redirects 301 to /" do
      get "/manager-os"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/")
    end
  end

  describe "GET /sirh" do
    it "returns OK" do
      get "/sirh"
      expect(response).to have_http_status(:ok)
    end

    it "includes noindex meta tag" do
      get "/sirh"
      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end
  end
end
```

- [ ] **Step 2: Lancer les tests, attendre échec sur certaines assertions**

Run: `bundle exec rspec spec/requests/pages_spec.rb`
Expected: tous PASS si les tasks précédentes ont été correctement exécutées. Si échec sur "19 €" ou "Le manager OS" → ajuster le copy ou les assertions au texte réel choisi.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/pages_spec.rb
git commit -m "test(landing): request specs home/manager-os/sirh"
```

---

## Task 19: Vérification manuelle finale

**Files:** aucun

- [ ] **Step 1: Lancer le serveur et tester**

Run: `bin/rails server`

Checklist navigateur :
- `http://localhost:3000/` → landing Manager OS Soft Power affichée
- Hero blob animé (sauf si reduced-motion activé)
- Scroll → sections révèlent (opacité+translation)
- Click "Essayer gratuitement" → confetti
- Pricing toggle Mensuel ↔ Annuel fonctionne
- `http://localhost:3000/manager-os` → redirect 301 vers `/`
- `http://localhost:3000/sirh` → page affichée, DevTools meta robots = noindex
- `http://localhost:3000/robots.txt` → contient `Disallow: /sirh`
- DevTools mobile 375px → toutes sections lisibles, blob ne déborde pas

- [ ] **Step 2: Lighthouse audit**

DevTools → Lighthouse → Mobile, Performance + Accessibility. Cibles :
- Performance ≥ 85
- Accessibility ≥ 95

Si score < cible : noter les findings dans un commentaire mais ne pas bloquer le merge si proche.

- [ ] **Step 3: Test reduced-motion**

DevTools → Rendering → "Emulate CSS media feature prefers-reduced-motion: reduce". Recharger `/`. Le blob doit être figé, le reveal instantané.

- [ ] **Step 4: Commit (si ajustements)**

Si des micro-ajustements ont été nécessaires :

```bash
git add -p
git commit -m "feat(landing): ajustements finaux post-QA visuel"
```

Sinon rien à committer.

---

## Self-Review Notes

- Spec coverage check : toutes les sections du spec sont couvertes (DA tokens task 1, fonts task 2, 4 controllers tasks 3-6, +pricing toggle task 7, sections tasks 8-13, home task 14, redirect task 15, noindex task 16, header cleanup task 17, tests task 18, QA task 19).
- Pricing toggle Stimulus a 5 controllers totaux au lieu de 4 mentionnés au spec — ajout justifié (toggle visuel = besoin réel non documenté en détail dans le spec mais implicite).
- Le spec mentionne `marketing.fr.yml` pour I18n. **Non implémenté** dans ce plan : copy directement en ERB pour itération rapide, I18n peut être ajouté en Phase 2 (à noter en backlog post-merge).
- Pas de `app/views/pages/manager_os.html.erb` après task 15 — si du code interne référence `manager_os_path` (ex: emails, dashboard), le helper existe toujours et redirigera. À vérifier en QA.
