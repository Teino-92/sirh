# LANDING PAGE MARKETING — EASY-RH

**Date** : 2026-03-01
**Auteur** : @architect
**Statut** : 📋 Documenté — en attente d'implémentation

---

## Objectif

Créer une landing page marketing SEO-optimisée accessible publiquement à `/`,
avec un formulaire d'inscription trial qui crée automatiquement une organisation
+ compte admin et connecte l'utilisateur directement.

**Actuellement** : `/` redirige vers `/employees/sign_in` pour tous les visiteurs.

---

## Décisions produit

| Décision | Choix |
|----------|-------|
| Emplacement | Dans Rails — route publique `/` (layout dédié) |
| Formulaire trial | Complet — crée org + admin + connexion auto |
| Screenshots | Fournis par l'utilisateur (placeholders `<img>` dans la vue) |
| Audience | Généraliste — PME françaises + startups tech |
| Sections | Hero, Features Grid, **Import CSV**, Pricing, FAQ, Form trial |

---

## Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `app/controllers/pages_controller.rb` | Action `home` (landing) |
| `app/controllers/trial_registrations_controller.rb` | Action `create` |
| `app/controllers/admin/employee_imports_controller.rb` | Upload + parsing CSV |
| `app/services/trial_registration_service.rb` | Crée org + employee admin en transaction |
| `app/services/employee_csv_import_service.rb` | Parse + valide + importe le CSV |
| `app/views/layouts/marketing.html.erb` | Layout marketing (sans navbar app) |
| `app/views/pages/home.html.erb` | La landing page complète |
| `app/views/admin/employee_imports/new.html.erb` | UI upload CSV |
| `app/views/admin/employee_imports/result.html.erb` | Résultat import (succès/erreurs) |
| `app/mailers/trial_welcome_mailer.rb` | Email de bienvenue avec mot de passe temporaire |
| `app/views/trial_welcome_mailer/welcome.text.erb` | Vue email bienvenue |
| `public/screenshots/.gitkeep` | Dossier pour les captures utilisateur |
| `public/templates/collaborateurs_template.csv` | Template CSV téléchargeable |

## Fichiers à modifier

| Fichier | Modification |
|---------|-------------|
| `config/routes.rb` | `root to: 'pages#home'` + `resource :trial_registration` + import routes |
| `public/robots.txt` | Allow `/`, Disallow routes privées |
| `config/initializers/rack_attack.rb` | Rate limit 5 req/heure/IP sur trial |

---

## ⭐ IMPORT CSV COLLABORATEURS — Point de force migration

### Pourquoi c'est un avantage compétitif

**Le pain point #1 lors d'un changement d'outil SIRH** : "Comment je transfère mes 80 employés ?"
C'est souvent ce qui bloque la migration. Izi-RH doit résoudre ce problème en 3 clics.

**Proposition de valeur** :
> "Importez tous vos collaborateurs en 2 minutes — copiez-collez depuis Excel ou exportez votre ancien SIRH."

### Format CSV accepté

Colonnes supportées (toutes en français, noms flexibles) :

```csv
Prénom,Nom,Email,Téléphone,Département,Poste,Type de contrat,Date d'entrée,Date de fin,Salaire brut,Manager (email),Rôle
Thomas,Martin,thomas.martin@techcorp.fr,0612345678,Engineering,Lead Backend,CDI,2022-01-15,,58000,alexandre.fontaine@techcorp.fr,manager
Marie,Dupont,marie.dupont@techcorp.fr,,Marketing,Content Manager,CDI,2023-03-01,,42000,,employee
```

**Colonnes obligatoires** : Prénom, Nom, Email, Type de contrat, Date d'entrée
**Colonnes optionnelles** : toutes les autres

**Flexibilité** :
- Accepte les séparateurs `,` et `;` (Excel français utilise `;`)
- Accepte les dates en `DD/MM/YYYY`, `YYYY-MM-DD`, `DD-MM-YYYY`
- Noms de colonnes insensibles à la casse et aux accents
- Colonnes inconnues ignorées silencieusement

### EmployeeCsvImportService

```ruby
# app/services/employee_csv_import_service.rb
class EmployeeCsvImportService
  ImportResult = Struct.new(:imported, :skipped, :errors)

  # Mapping flexible des noms de colonnes
  COLUMN_ALIASES = {
    'first_name'    => %w[prénom prenom firstname first_name],
    'last_name'     => %w[nom lastname last_name],
    'email'         => %w[email mail e-mail],
    'phone'         => %w[téléphone telephone phone mobile],
    'department'    => %w[département departement department dept service],
    'job_title'     => %w[poste titre fonction job_title role_intitulé],
    'contract_type' => %w[contrat type_contrat contract contract_type],
    'start_date'    => %w[date_entrée date_arrivée date_debut start_date],
    'end_date'      => %w[date_fin end_date],
    'gross_salary'  => %w[salaire salaire_brut gross_salary rémunération],
    'manager_email' => %w[manager manager_email responsable],
    'role'          => %w[rôle role profil]
  }.freeze

  CONTRACT_ALIASES = {
    'cdi' => 'CDI', 'cdd' => 'CDD',
    'stage' => 'Stage', 'alternance' => 'Alternance', 'intérim' => 'Interim'
  }.freeze

  def initialize(file, organization)
    @file = file
    @organization = organization
  end

  def call
    rows   = parse_csv
    result = ImportResult.new([], [], [])

    ActiveRecord::Base.transaction do
      rows.each_with_index do |row, i|
        import_row(row, i + 2, result)  # i+2 car ligne 1 = headers
      end
    end

    # Résoudre les managers (2ème passe — tous les employés existent déjà)
    resolve_managers(rows, result)

    result
  rescue CSV::MalformedCSVError => e
    ImportResult.new([], [], ["Fichier CSV invalide : #{e.message}"])
  end

  private

  def parse_csv
    content = @file.read.force_encoding('UTF-8')
    # Auto-detect separator
    sep = content.include?(';') ? ';' : ','
    CSV.parse(content, headers: true, col_sep: sep,
              header_converters: ->(h) { normalize_header(h) })
       .map(&:to_h)
  end

  def normalize_header(header)
    normalized = header.to_s.downcase.strip
                       .gsub(/[éèê]/, 'e').gsub(/[àâ]/, 'a')
                       .gsub(/[îï]/, 'i').gsub(/[ôö]/, 'o')
                       .gsub(/\s+/, '_')
    COLUMN_ALIASES.each do |canonical, aliases|
      return canonical if aliases.include?(normalized)
    end
    normalized
  end

  def import_row(row, line_num, result)
    attrs = build_employee_attrs(row)
    employee = ActsAsTenant.with_tenant(@organization) do
      Employee.new(attrs.merge(organization: @organization,
                               password: SecureRandom.hex(10)))
    end

    if employee.save
      result.imported << employee
    else
      result.errors << "Ligne #{line_num} (#{row['email']}) : #{employee.errors.full_messages.join(', ')}"
      result.skipped << row
    end
  end

  def build_employee_attrs(row)
    {
      first_name:    row['first_name'].to_s.strip,
      last_name:     row['last_name'].to_s.strip,
      email:         row['email'].to_s.strip.downcase,
      phone:         row['phone']&.strip,
      department:    row['department']&.strip,
      job_title:     row['job_title']&.strip,
      contract_type: normalize_contract(row['contract_type']),
      start_date:    parse_date(row['start_date']),
      end_date:      parse_date(row['end_date']),
      gross_salary_cents: parse_salary(row['gross_salary']),
      role:          normalize_role(row['role'])
    }.compact
  end

  def normalize_contract(val)
    CONTRACT_ALIASES[val.to_s.downcase.strip] || 'CDI'
  end

  def normalize_role(val)
    r = val.to_s.downcase.strip
    Employee::ROLES.include?(r) ? r : 'employee'
  end

  def parse_date(val)
    return nil if val.blank?
    # Essaie plusieurs formats
    %w[%d/%m/%Y %Y-%m-%d %d-%m-%Y %m/%d/%Y].each do |fmt|
      return Date.strptime(val.strip, fmt) rescue nil
    end
    nil
  end

  def parse_salary(val)
    return nil if val.blank?
    # Accepte "58000", "58 000", "58 000,00 €", "58000.00"
    cents = val.to_s.gsub(/[^\d.,]/, '').gsub(',', '.').to_f
    (cents * 100).to_i
  end

  def resolve_managers(rows, result)
    rows.each do |row|
      next if row['manager_email'].blank?
      employee = ActsAsTenant.with_tenant(@organization) do
        Employee.find_by(email: row['email']&.strip&.downcase)
      end
      manager = ActsAsTenant.with_tenant(@organization) do
        Employee.find_by(email: row['manager_email']&.strip&.downcase)
      end
      employee&.update_columns(manager_id: manager&.id)
    end
  end
end
```

### Controller import

```ruby
# app/controllers/admin/employee_imports_controller.rb
class Admin::EmployeeImportsController < Admin::BaseController
  def new
    # Affiche le formulaire upload + template téléchargeable
  end

  def create
    unless params[:file]&.content_type&.in?(['text/csv', 'application/vnd.ms-excel', 'text/plain'])
      return redirect_to new_admin_employee_import_path, alert: "Veuillez uploader un fichier CSV."
    end

    result = EmployeeCsvImportService.new(params[:file], current_organization).call

    @imported = result.imported
    @errors   = result.errors
    @skipped  = result.skipped

    # Envoyer email de bienvenue à chaque employé importé
    @imported.each do |emp|
      TrialWelcomeMailer.welcome(emp, nil).deliver_later  # sans mot de passe (reset password flow)
    end

    render :result
  end
end
```

### Template CSV téléchargeable

Fichier `public/templates/collaborateurs_template.csv` :

```csv
Prénom;Nom;Email;Téléphone;Département;Poste;Type de contrat;Date d'entrée;Date de fin;Salaire brut;Manager (email);Rôle
Thomas;Martin;thomas@entreprise.fr;0612345678;Engineering;Lead Dev;CDI;15/01/2022;;58000;directeur@entreprise.fr;manager
Marie;Dupont;marie@entreprise.fr;;Marketing;Content;CDI;01/03/2023;;42000;;employee
```

### UI import (`new.html.erb`)

```
┌─────────────────────────────────────────────┐
│  📥 Importer vos collaborateurs             │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Glissez votre fichier CSV ici      │   │
│  │  ou cliquez pour sélectionner       │   │
│  │                                     │   │
│  │  [Choisir un fichier]               │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ⬇ Télécharger le modèle Excel/CSV         │
│                                             │
│  Colonnes reconnues automatiquement :       │
│  Prénom · Nom · Email · Contrat · Entrée   │
│  Département · Poste · Salaire · Manager   │
│                                             │
│  [Importer les collaborateurs →]           │
└─────────────────────────────────────────────┘
```

### UI résultat (`result.html.erb`)

```
✅ 47 collaborateurs importés avec succès
⚠️  3 lignes ignorées (erreurs)

Ligne 5 (jean@ex.fr) : Email déjà utilisé
Ligne 12 (paul@ex.fr) : Date d'entrée invalide
Ligne 23 () : Email obligatoire manquant

[Voir les collaborateurs] [Réimporter]
```

---

## Intégration dans la landing page

### Section dédiée dans la landing (entre Features et Pricing)

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  🚀 Migrez en 2 minutes chrono                          │
│                                                          │
│  "Changer de SIRH, c'est compliqué ?"                   │
│  Pas avec Izi-RH.                                       │
│                                                          │
│  1. Exportez votre liste depuis Excel ou votre SIRH     │
│  2. Glissez le fichier dans Izi-RH                     │
│  3. Tous vos collaborateurs sont importés               │
│                                                          │
│  Compatible avec : Excel · Sage · Lucca · Factorial ·   │
│  PayFit · BambooHR · tout logiciel avec export CSV      │
│                                                          │
│  ✅ Détection automatique du format                      │
│  ✅ Dates françaises (JJ/MM/AAAA) et ISO                │
│  ✅ Séparateur , ou ; (Excel FR/EN)                     │
│  ✅ Rapport détaillé ligne par ligne                     │
│                                                          │
│         <!-- SCREENSHOT: import-preview.png -->         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Routes complètes

```ruby
# config/routes.rb
root to: 'pages#home'

authenticated :employee do
  root to: 'dashboard#show', as: :authenticated_root
end

resource :trial_registration, only: [:create]

namespace :admin do
  resource :employee_import, only: [:new, :create]
  # ...
end
```

---

## Structure landing page complète

1. **Navbar marketing** — Logo + ancres + CTA "Essayer"
2. **Hero** — H1 SEO, sous-titre, badges confiance, CTA, screenshot dashboard
3. **Features Grid** — 6 cartes fonctionnalités (icônes SVG)
4. **Section Import CSV** ⭐ — "Migrez en 2 minutes" (point de force migration)
5. **Pricing** — 3 tiers (Essentiel/Pro/Entreprise)
6. **Formulaire Trial** — 4 champs, connexion auto
7. **FAQ** — 5 questions Alpine.js accordion
8. **Footer** — Liens légaux, Made in France

---

## SEO

### robots.txt
```
User-agent: *
Allow: /
Disallow: /admin
Disallow: /manager
Disallow: /api
Disallow: /employees/sign_in
Disallow: /profile
Disallow: /dashboard

Sitemap: https://app.izi-rh.fr/sitemap.xml
```

### Mots-clés ciblés
- "SIRH français" / "logiciel RH PME"
- "gestion congés salariés" / "calcul RTT automatique"
- "suivi temps travail" / "pointage employé"
- "logiciel onboarding collaborateur"
- "importer employés CSV SIRH" / "migration logiciel RH"
- "SIRH conforme droit du travail français"

---

## Sécurité

- `skip_before_action :authenticate_employee!` sur les controllers publics
- `ActsAsTenant.with_tenant(org)` pour isolation tenant à la création
- Mot de passe temporaire : `SecureRandom.hex(10)`, envoyé par email uniquement
- Rate limiting Rack::Attack : 5 soumissions/heure/IP sur trial
- Import CSV : taille fichier max 5MB, content-type vérifié, pas d'exécution de code

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle("trial_registrations/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path == "/trial_registration" && req.post?
end
```

---

## Screenshots attendus (à fournir par l'utilisateur)

Déposer dans `public/screenshots/` :

| Fichier | Contenu suggéré |
|---------|----------------|
| `dashboard.png` | Dashboard manager avec toutes les cards |
| `features-preview.png` | Vue congés ou objectifs |
| `import-preview.png` | L'interface import CSV avec résultat |
| `og-image.png` | Image OG 1200×630 pour partage social |

---

## Vérification post-implémentation

```bash
# 1. Landing accessible sans connexion
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
# Attendu : 200

# 2. Utilisateur connecté → dashboard
# Se connecter puis aller sur / → doit rediriger vers /dashboard

# 3. Formulaire trial → org + employee créés + redirection dashboard
# Tester avec un email unique

# 4. Import CSV — test avec le template
# Aller sur /admin/employee_import/new → uploader collaborateurs_template.csv
# Attendu : 2 employés importés, 0 erreurs

# 5. Import CSV avec données invalides
# Ligne sans email → erreur ligne par ligne affichée

# 6. Meta SEO
curl -s http://localhost:3000/ | grep -E "description|og:title|canonical"

# 7. robots.txt
curl -s http://localhost:3000/robots.txt
```

---

*Dernière mise à jour : 2026-03-01 par @architect*
