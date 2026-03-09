# Agents Spécialisés Izi-RH

Ce dossier contient 4 agents spécialisés pour le développement du projet Izi-RH. Chaque agent a un rôle spécifique et des responsabilités bien définies.

## 🏗️ Les Agents

### 1. **Architecte** (`architect.md`)
**Responsable de**: Structure du code, choix techniques, découpage fichiers, décisions long terme

**Utiliser quand**:
- Tu veux ajouter une nouvelle fonctionnalité complexe
- Tu as besoin d'une décision technique stratégique
- Tu veux refactoriser une partie importante du code
- Tu veux créer un nouveau domaine/module

**Exemple de prompt**:
```
@architect Je veux ajouter un système de paie mensuelle automatique basé sur les pointages validés. Comment structurer ça?
```

### 2. **Developer** (`developer.md`)
**Responsable de**: Implémentation, respect strict des consignes, pas de refacto sauvages

**Utiliser quand**:
- Tu as des specs claires de l'Architecte
- Tu veux implémenter une fonctionnalité précise
- Tu as besoin de code propre et testé

**Exemple de prompt**:
```
@developer Implémente exactement ce que l'Architecte a spécifié pour le module de paie
```

### 3. **QA / Reviewer** (`qa.md`)
**Responsable de**: Détection de bugs, edge cases, dette technique, cohérence avec l'existant

**Utiliser quand**:
- Une fonctionnalité vient d'être implémentée
- Tu veux un audit de qualité
- Tu suspectes des bugs
- Tu veux identifier la dette technique

**Exemple de prompt**:
```
@qa Review complet du système de notifications dropdown que nous venons d'implémenter
```

### 4. **UX** (`ux.md`)
**Responsable de**: Lisibilité, DX, logique métier, expérience utilisateur

**Utiliser quand**:
- Tu veux valider l'ergonomie d'une interface
- Tu as besoin de feedback sur un workflow
- Tu veux améliorer l'expérience utilisateur
- Tu as des doutes sur la logique métier

**Exemple de prompt**:
```
@ux Analyse le parcours utilisateur pour pointer l'entrée/sortie. Est-ce assez intuitif?
```

## 🔄 Workflow Recommandé

### Pour une nouvelle fonctionnalité:

```
1. @ux → Analyser le besoin utilisateur et proposer le workflow
2. @architect → Designer l'architecture et les specs techniques
3. @developer → Implémenter selon les specs
4. @qa → Review et détection de bugs
5. @developer → Corriger les bugs identifiés
6. @ux → Valider l'expérience finale
```

### Pour un bug fix:

```
1. @qa → Identifier et documenter le bug
2. @architect → Décider de la stratégie de fix (si complexe)
3. @developer → Corriger le bug
4. @qa → Vérifier la correction et non-régression
```

### Pour une amélioration UX:

```
1. @ux → Identifier les points de friction
2. @architect → Proposer solutions techniques
3. @developer → Implémenter
4. @ux → Valider l'amélioration
```

## 📋 Exemples Concrets

### Exemple 1: Ajouter un export Excel des pointages

```bash
# Étape 1: Design UX
@ux Comment devrait fonctionner l'export Excel des pointages pour un manager?

# Étape 2: Architecture
@architect Design l'architecture pour un système d'export Excel des pointages validés

# Étape 3: Implémentation
@developer Implémente le système d'export selon les specs de l'architecte

# Étape 4: Review
@qa Review le système d'export Excel - bugs, edge cases, performance

# Étape 5: Validation UX
@ux Valide que l'expérience d'export est fluide et intuitive
```

### Exemple 2: Améliorer la page de dashboard

```bash
# Étape 1: Analyse UX
@ux Analyse l'ergonomie actuelle du dashboard et propose des améliorations

# Étape 2: Validation technique
@architect Valide la faisabilité des propositions UX et design l'implémentation

# Étape 3: Implémentation
@developer Implémente les améliorations validées

# Étape 4: Review qualité
@qa Review les changements sur le dashboard - cohérence, bugs, performance
```

### Exemple 3: Audit complet du code existant

```bash
# QA: Dette technique
@qa Audit complet de la dette technique du domaine time_tracking

# Architecte: Priorisation
@architect Priorise les points de dette technique identifiés par QA et propose un plan

# UX: Expérience
@ux Analyse l'expérience utilisateur globale du module de pointage
```

## 🎯 Bonnes Pratiques

### DO ✅
- Utiliser l'agent approprié selon la tâche
- Suivre le workflow recommandé
- Laisser chaque agent faire son travail
- Documenter les décisions de l'Architecte
- Faire reviewer par QA avant de considérer terminé

### DON'T ❌
- Ne pas mélanger les rôles (ex: demander à Developer de faire de l'archi)
- Ne pas skip l'étape review QA
- Ne pas implémenter sans specs de l'Architecte pour les features complexes
- Ne pas ignorer les feedbacks UX

## 🔧 Configuration

Les agents utilisent les conventions suivantes du projet:

- **Langage**: Français pour tout (messages, commentaires si nécessaires)
- **Stack**: Rails 7.1.6, PostgreSQL, Tailwind, Stimulus, Importmap
- **Architecture**: Domain-Driven Design
- **Sécurité**: Pundit pour autorisation, validations strictes
- **Performance**: Bullet activé, pas de N+1 tolérés

## 📚 Ressources

Chaque agent a:
- Un fichier de définition détaillé (`.md`)
- Des checklists spécifiques
- Des exemples de bon/mauvais code
- Des templates de réponse

## 🚀 Pour Commencer

1. Lis le fichier de l'agent que tu veux utiliser
2. Comprends son rôle et ses limites
3. Formule ta demande clairement avec `@agent-name`
4. Suis le workflow recommandé ci-dessus

## 💡 Tips

- **Pour les petites modifs**: Pas besoin de tout le workflow, Developer + QA suffit
- **Pour les features complexes**: Toujours passer par Architecte d'abord
- **Quand bloqué**: Demande à Architecte de trancher
- **Doute sur UX**: Demande à UX avant d'implémenter

## 🆘 Aide

Si tu ne sais pas quel agent utiliser:
- **Question technique/design** → Architecte
- **"Fais-moi ça"** → Developer
- **"Est-ce que c'est bon?"** → QA
- **"Est-ce que c'est clair/intuitif?"** → UX

---

**Note**: Ces agents sont des guides. Pour des tâches simples, tu peux toujours discuter directement sans passer par le système d'agents.
