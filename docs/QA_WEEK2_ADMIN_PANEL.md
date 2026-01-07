# QA Testing Guide - Week 2: Admin Panel

**Date:** 2026-01-04
**Version:** Week 2 - Admin Panel CRUD
**Status:** Ready for QA Testing

---

## 🎯 Objectif

Tester le panel d'administration complet pour la gestion des employés et des paramètres d'organisation.

---

## ✅ Fonctionnalités à Tester

### 1. Accès au Panel Admin

**Prérequis:**
- Compte employé avec rôle `hr` ou `admin`
- Connexion à l'application

**Test:**
1. Connectez-vous avec un compte HR/Admin
2. Vérifiez qu'un lien "Admin" apparaît dans la navigation principale
3. Cliquez sur "Admin" → Vous devez arriver sur `/admin/employees`
4. **Vérification sécurité:** Connectez-vous avec un compte `employee` normal → Le lien "Admin" ne doit PAS apparaître
5. **Vérification sécurité:** Essayez d'accéder à `/admin/employees` avec un compte employee → Vous devez être redirigé avec un message "Accès non autorisé"

**Résultat attendu:**
- ✅ Seuls les utilisateurs HR/Admin ont accès au panel admin
- ✅ Redirection et message d'erreur pour les utilisateurs non autorisés

---

### 2. Liste des Employés (Index)

**URL:** `/admin/employees`

**Test:**
1. Vérifiez que la liste affiche tous les employés de VOTRE organisation uniquement
2. Vérifiez les colonnes affichées:
   - Photo de profil (avatar ou initiales)
   - Nom complet
   - Email
   - Rôle (avec badge coloré: employee/manager/hr/admin)
   - Type de contrat (CDI/CDD/Stage/Alternance/Interim)
   - Département
   - Poste
   - Actions (Voir/Modifier/Supprimer)
3. Vérifiez la pagination (si plus de 20 employés)
4. Vérifiez le bouton "Nouvel Employé"

**Multi-tenancy (CRITIQUE):**
1. Créez une deuxième organisation en base de données
2. Ajoutez des employés à cette deuxième organisation
3. Connectez-vous avec un compte de la première organisation
4. **Vérifiez que vous ne voyez QUE les employés de votre organisation**

**Résultat attendu:**
- ✅ Liste affichée correctement avec toutes les informations
- ✅ Pagination fonctionnelle (20 employés par page)
- ✅ **CRITIQUE:** Isolation totale entre organisations
- ✅ Interface responsive sur mobile et desktop

---

### 3. Créer un Employé (Modal)

**Test:**
1. Cliquez sur "Nouvel Employé"
2. Une **modale** doit s'ouvrir (pas de rechargement de page)
3. Remplissez le formulaire:
   - Prénom (requis)
   - Nom (requis)
   - Email (requis, format email)
   - Mot de passe (requis pour nouveau)
   - Confirmation mot de passe
   - Rôle: employee/manager/hr/admin
   - Type de contrat: CDI/CDD/Stage/Alternance/Interim
   - Date d'entrée (requis)
   - Date de sortie (optionnel)
   - Département (optionnel)
   - Poste (optionnel)
   - Manager (dropdown, optionnel)
   - Photo de profil (upload fichier)
4. Cliquez sur "Créer l'employé"

**Validations à tester:**
- Email invalide → erreur
- Mot de passe manquant → erreur
- Champs requis vides → erreurs

**Résultat attendu:**
- ✅ Modale s'ouvre sans rechargement
- ✅ Formulaire valide les données
- ✅ Après création: redirection vers la page détail de l'employé
- ✅ Message de succès "Employé créé avec succès"
- ✅ L'employé est bien ajouté à VOTRE organisation uniquement

**Cas d'erreur à tester:**
- Email déjà existant
- Format email invalide
- Mot de passe trop court (< 6 caractères)

---

### 4. Voir un Employé (Show)

**URL:** `/admin/employees/:id`

**Test:**
1. Cliquez sur "Voir" pour un employé
2. Vérifiez les sections affichées:
   - **En-tête:** Photo + Nom + Rôle
   - **Informations personnelles:** Email, Département, Poste
   - **Informations contractuelles:** Date d'entrée, Ancienneté, Type de contrat, Date de sortie, Manager
   - **Équipe:** Liste des membres de l'équipe (si l'employé est manager)
3. Vérifiez les boutons d'action: "Modifier" et "Supprimer"

**Résultat attendu:**
- ✅ Toutes les informations affichées correctement
- ✅ Ancienneté calculée automatiquement
- ✅ Si manager: liste de ses employés affichée
- ✅ Boutons d'action fonctionnels

---

### 5. Modifier un Employé (Modal)

**Test:**
1. Sur la page détail, cliquez sur "Modifier" OU cliquez sur "Modifier" depuis la liste
2. Une **modale** doit s'ouvrir avec le formulaire pré-rempli
3. Modifiez quelques champs (ex: département, poste)
4. **Note:** Le mot de passe n'apparaît PAS en édition (sécurité)
5. Cliquez sur "Mettre à jour"

**Résultat attendu:**
- ✅ Modale s'ouvre avec données pré-remplies
- ✅ Modifications sauvegardées
- ✅ Message "Employé mis à jour avec succès"
- ✅ Pas de rechargement de page (Turbo)

---

### 6. Supprimer un Employé

**Test:**
1. Cliquez sur "Supprimer" pour un employé
2. Une confirmation doit apparaître
3. Confirmez la suppression

**Résultat attendu:**
- ✅ Employé supprimé de la liste
- ✅ Message "Employé supprimé avec succès"
- ✅ Pas de rechargement de page

**⚠️ Important:** Vérifiez qu'on ne peut pas se supprimer soi-même (si implémenté)

---

### 7. Dropdown Manager

**Test:**
1. En création/édition d'employé, ouvrez le dropdown "Manager"
2. Vérifiez que seuls les employés avec rôle manager/hr/admin apparaissent
3. Vérifiez que l'employé en cours d'édition n'apparaît PAS dans sa propre liste (éviter boucle)

**Multi-tenancy:**
- Vérifiez que seuls les managers de VOTRE organisation apparaissent

**Résultat attendu:**
- ✅ Liste filtrée correctement (seulement managers)
- ✅ Auto-exclusion en édition
- ✅ Isolation par organisation

---

### 8. Upload Avatar

**Test:**
1. En création/édition, uploadez une photo de profil
2. Formats à tester: JPG, PNG, GIF
3. Taille à tester: Petit fichier (< 1MB) et gros fichier (> 5MB)

**Résultat attendu:**
- ✅ Upload réussi pour JPG/PNG/GIF < 5MB
- ✅ Avatar affiché dans la liste et sur la page détail
- ✅ Fallback sur initiales si pas d'avatar

---

### 9. Page Organisation (Settings)

**URL:** `/admin/organization`

**Test:**
1. Cliquez sur "Organisation" dans la navigation admin
2. Vérifiez les sections affichées:
   - **Informations générales:** Nom, SIRET, Adresse
   - **Temps de travail:** Heures hebdo, Seuil heures sup, Max heures/jour, RTT activé
   - **Congés:** Taux acquisition CP, Date expiration CP, Jours consécutifs minimum
   - **Statistiques:** Total employés, Managers, Employés actifs
3. Cliquez sur "Modifier"

**Résultat attendu:**
- ✅ Toutes les informations de l'organisation affichées
- ✅ Statistiques calculées correctement

---

### 10. Modifier Organisation

**URL:** `/admin/organization/edit`

**Test:**
1. Modifiez les informations générales (nom, SIRET, adresse)
2. Modifiez les paramètres de temps de travail:
   - Heures hebdomadaires (défaut: 35h)
   - Seuil heures supplémentaires
   - Maximum heures par jour (max légal: 10h)
   - RTT activé (checkbox)
3. Modifiez les paramètres de congés:
   - Taux acquisition CP (défaut: 2.5 jours/mois)
   - Mois d'expiration CP (défaut: Mai)
   - Jour d'expiration CP (défaut: 31)
   - Jours consécutifs minimum (défaut: 10 jours)
4. Cliquez sur "Enregistrer"

**Validations:**
- Heures hebdo: entre 1 et 48h
- Heures max/jour: max 10h (légal français)

**Résultat attendu:**
- ✅ Tous les paramètres modifiables
- ✅ Validations respectées
- ✅ Message "Paramètres mis à jour avec succès"
- ✅ Retour à la page organisation

---

## 🔒 Tests de Sécurité Multi-Tenancy (CRITIQUE)

### Scénario de test complet:

**Setup:**
1. Créez 2 organisations: "TechCorp" et "InnoLabs"
2. Créez 2 employés HR:
   - marie@techcorp.fr (organisation: TechCorp, rôle: hr)
   - pierre@innolabs.fr (organisation: InnoLabs, rôle: hr)
3. Créez 3 employés dans TechCorp
4. Créez 2 employés dans InnoLabs

**Tests:**
1. Connectez-vous avec marie@techcorp.fr
   - Liste employés → Doit voir uniquement les 3 employés TechCorp + elle-même (4 au total)
   - Dropdown managers → Doit voir uniquement les managers TechCorp
   - Organisation → Doit voir uniquement les paramètres TechCorp
2. Connectez-vous avec pierre@innolabs.fr
   - Liste employés → Doit voir uniquement les 2 employés InnoLabs + lui-même (3 au total)
   - Dropdown managers → Doit voir uniquement les managers InnoLabs
   - Organisation → Doit voir uniquement les paramètres InnoLabs
3. **Tentative d'accès direct:**
   - Connecté avec marie@techcorp.fr
   - Copiez l'URL d'un employé InnoLabs (ex: `/admin/employees/123`)
   - Essayez d'accéder directement → **DOIT ÉCHOUER** (erreur 404 ou redirection)

**Résultat attendu (CRITIQUE):**
- ✅ Isolation totale entre organisations
- ✅ Impossible d'accéder aux données d'une autre organisation
- ✅ Impossible de modifier des employés d'une autre organisation

---

## 🎨 Tests UI/UX (pour @ux)

### Navigation
- [ ] Le lien "Admin" est bien visible dans la navigation
- [ ] La navigation admin (Employés/Organisation/Retour) fonctionne
- [ ] Navigation mobile (bottom bar) fonctionne

### Responsive
- [ ] Desktop (> 1024px): Interface optimale
- [ ] Tablet (768-1024px): Interface adaptée
- [ ] Mobile (< 768px): Interface mobile friendly

### Modales
- [ ] Les modales s'ouvrent sans rechargement
- [ ] On peut fermer une modale (bouton X ou clic extérieur)
- [ ] Les modales sont responsive

### Feedback utilisateur
- [ ] Messages de succès affichés (vert)
- [ ] Messages d'erreur affichés (rouge)
- [ ] Loading states pendant les requêtes

### Lisibilité (à améliorer selon feedback)
- [ ] Texte lisible (taille, contraste)
- [ ] Espacement suffisant entre éléments
- [ ] Hiérarchie visuelle claire
- [ ] Couleurs accessibles

---

## 🐛 Bugs Connus

Aucun bug connu pour le moment.

---

## 📝 Notes pour @qa

**Environnement de test:**
- URL: http://localhost:3000
- Base de données: PostgreSQL en développement
- Données de test: Utilisez les seeds ou créez manuellement

**Comptes de test recommandés:**
```ruby
# Dans bin/rails console
# Créer une organisation
org1 = Organization.create!(name: "TechCorp")

# Créer un admin pour tester
admin = Employee.create!(
  organization: org1,
  email: "admin@techcorp.fr",
  password: "password123",
  first_name: "Admin",
  last_name: "Test",
  role: "admin",
  contract_type: "CDI",
  start_date: Date.current
)

# Créer un employé normal pour tester l'accès refusé
employee = Employee.create!(
  organization: org1,
  email: "employee@techcorp.fr",
  password: "password123",
  first_name: "Employee",
  last_name: "Test",
  role: "employee",
  contract_type: "CDI",
  start_date: Date.current
)
```

**Priorités de test:**
1. 🔴 **CRITIQUE:** Tests multi-tenancy (sécurité)
2. 🟠 **HAUTE:** CRUD employés (création, édition, suppression)
3. 🟡 **MOYENNE:** Paramètres organisation
4. 🟢 **BASSE:** UI/UX (sera retravaillé)

**Reporting des bugs:**
Créer un document avec:
- Titre du bug
- Étapes de reproduction
- Résultat attendu vs résultat obtenu
- Captures d'écran si pertinent
- Niveau de gravité (Critique/Haute/Moyenne/Basse)

---

## ✅ Checklist Finale

- [ ] Accès admin restreint HR/Admin uniquement
- [ ] CRUD employés complet et fonctionnel
- [ ] Multi-tenancy 100% sécurisé (CRITIQUE)
- [ ] Modales Turbo fonctionnelles
- [ ] Upload avatar fonctionnel
- [ ] Paramètres organisation modifiables
- [ ] Validations formulaires correctes
- [ ] Messages de feedback clairs
- [ ] Interface responsive
- [ ] Aucun crash/erreur 500

---

**Date de fin de tests prévue:** À définir
**Prochaine étape:** Amélioration UI/UX basée sur feedback
