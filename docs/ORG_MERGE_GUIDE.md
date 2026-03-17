# Guide — Fusion d'organisations (OrgMerge)

**Cas d'usage** : un client utilise Izi-RH en mode **Manager OS** (B2C) et souhaite basculer vers un plan **SIRH** centralisé. L'administrateur SIRH invite les organisations Manager OS à fusionner : leurs employés et données RH migrent dans l'organisation SIRH cible.

---

## Prérequis

| Condition | Organisation source | Organisation cible |
|-----------|--------------------|--------------------|
| Plan requis | Manager OS | SIRH (Essentiel ou Pro) |
| Statut | Active (pas déjà `merged`) | Active |
| Email invité | Doit correspondre à un compte existant dans l'org source | — |

> Les emails en double entre les deux organisations bloquent la fusion. Résolvez les conflits avant de lancer.

---

## Étape 1 — Envoyer l'invitation (côté SIRH)

1. Connectez-vous avec un compte **Admin** ou **HR Officer** de l'organisation SIRH.
2. Accédez à **Administration → Fusions d'organisations**.
3. Cliquez sur **Inviter une organisation**.
4. Saisissez l'**email d'un employé** de l'organisation Manager OS à fusionner.
5. Cliquez sur **Envoyer l'invitation**.

Un email est envoyé à cet employé avec un lien valable **7 jours**.

---

## Étape 2 — Accepter l'invitation (côté Manager OS)

1. L'employé reçoit l'email d'invitation.
2. Il clique sur **"Voir la proposition de fusion"**.
3. La page affiche un **aperçu des données** qui seront migrées (nombre d'employés, congés, formations, etc.).
4. Il clique sur **"Accepter la fusion"** pour lancer la migration, ou **"Décliner"** pour refuser.

> Aucune connexion préalable n'est requise pour accéder à la page d'acceptation — le lien contient un token sécurisé.

---

## Étape 3 — Migration automatique

Après acceptation, la migration démarre en arrière-plan. Le processus :

1. Vérifie l'absence d'emails en double entre les deux organisations.
2. Migre tous les **employés** de l'org source vers l'org cible.
3. Migre tous les **enregistrements RH** associés (voir liste complète ci-dessous).
4. Marque l'organisation source comme **dissoute** (`status: merged`).
5. Annule l'abonnement Stripe de l'organisation source.
6. Envoie un **email de confirmation** à l'admin SIRH qui a initié la fusion.

---

## Données migrées

| Domaine | Modèles migrés |
|---------|---------------|
| Employés | `Employee` |
| Planification | `WorkSchedule`, `WeeklySchedulePlan` |
| Congés | `LeaveBalance`, `LeaveRequest` |
| Temps | `TimeEntry` |
| 1:1 | `OneOnOne`, `ActionItem` |
| Objectifs | `Objective` |
| Formations | `Training`, `TrainingAssignment` |
| Onboarding | `OnboardingTemplate`, `OnboardingTemplateTask`, `EmployeeOnboarding`, `OnboardingTask`, `OnboardingReview` |
| Évaluations | `Evaluation`, `EvaluationObjective` |
| Automatisations | `BusinessRule`, `RuleExecution`, `ApprovalStep` |
| Délégations | `EmployeeDelegation` |
| Paie | `PayrollPeriod` |
| Notifications | `Notification` |

---

## États de l'invitation

| Statut | Signification |
|--------|--------------|
| `pending` | Invitation envoyée, en attente de réponse |
| `accepted` | Acceptée, migration en file d'attente |
| `merging` | Migration en cours |
| `completed` | Migration terminée avec succès |
| `declined` | Refusée par le destinataire ou annulée par l'admin |
| `failed` | Erreur durant la migration (voir logs) |

---

## Annuler une invitation (avant acceptation)

Depuis **Administration → Fusions d'organisations**, cliquez sur **Annuler** en regard de l'invitation. Le statut passe à `declined` et l'invitation ne peut plus être acceptée.

---

## En cas d'échec

Si la migration échoue (`status: failed`) :

1. Aucune donnée n'est partiellement migrée — la transaction ACID garantit l'atomicité.
2. Consultez les logs Rails : `[OrgMergeService]` et `[OrgMergeJob]`.
3. Les erreurs sont également remontées sur Sentry.
4. Corrigez la cause (ex. emails en double), puis relancez manuellement depuis la console :

```ruby
invitation = OrgMergeInvitation.find(<id>)
invitation.update!(status: 'accepted')
OrgMergeJob.perform_later(invitation.id)
```

---

## Limitations connues

- **Un seul merge actif par organisation source** — une invitation `pending`, `accepted` ou `merging` bloque toute nouvelle invitation pour cette source.
- **Emails en double** — si un employé de l'org source a le même email qu'un employé de l'org cible, la migration est bloquée. Résoudre manuellement avant de relancer.
- **Token OAuth calendrier** — les tokens Google/Microsoft des employés ne sont pas migrés (ils devront se reconnecter après la fusion).
- **Stripe** — l'annulation de l'abonnement source est best-effort : si Stripe est indisponible, l'abonnement reste actif mais la migration DB est déjà commitée. Vérifier manuellement dans le dashboard Stripe si `stripe_error` apparaît dans les logs.
