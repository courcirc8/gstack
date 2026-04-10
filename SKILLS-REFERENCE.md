# gstack Skills Reference — FastAPI Developer

Quick reference des skills gstack triees par utilite pour un workflow FastAPI (backend Python + frontend web).

---

## Quotidien — Toujours sous la main

| Commande | Quoi | Quand l'utiliser |
|----------|------|------------------|
| `/review` | Review de PR | Avant chaque merge. Detecte SQL unsafe, side effects, trust boundaries, problemes structurels |
| `/investigate` | Debug systematique | Bug en prod ou test qui casse. 4 phases : investigate > analyze > hypothesize > implement. Pas de fix sans root cause |
| `/health` | Dashboard qualite | Apres un sprint ou avant release. Lance mypy, ruff, pytest, dead code. Score 0-10 avec tendance |
| `/ship` | Ship complet | Pret a merger. Merge base branch > tests > review > bump version > CHANGELOG > PR > push |
| `/cso` | Audit securite | Avant release ou apres ajout de deps. Secrets, pip-audit, OWASP Top 10, STRIDE, supply chain |
| `/qa` | QA web + fix | Tester les routes FastAPI cote navigateur. Teste, trouve les bugs, les fixe, re-verifie |
| `/browse` | Browser headless | Naviguer l'app, tester un endpoint, screenshot, verifier un formulaire, debug CORS |
| `/checkpoint` | Sauvegarder l'etat | Fin de journee ou avant un gros refactor. Reprendre exactement ou on en etait |

## Regulier — Plusieurs fois par semaine

| Commande | Quoi | Quand l'utiliser |
|----------|------|------------------|
| `/careful` | Mode prudent | Avant de toucher a la BDD prod, migrations, ou infra |
| `/guard` | Mode securise complet | `/careful` + verrouillage de dossier. Quand on debug en prod |
| `/freeze src/` | Verrouiller un dossier | Empeche les edits hors du dossier specifie |
| `/learn` | Consulter les apprentissages | Voir ce que gstack a retenu du projet entre sessions |
| `/qa-only` | QA sans fix | Rapport de bugs structure sans toucher au code. Pour documenter avant de fixer |
| `/design-review` | Review visuelle | Apres modif du frontend. Detecte inconsistances visuelles, spacing, hierarchie |

## Ponctuel — Pour les moments cles

| Commande | Quoi | Quand l'utiliser |
|----------|------|------------------|
| `/plan-eng-review` | Review archi | Avant un gros refactor ou nouveau module. Valide l'architecture, data flow, edge cases |
| `/retro` | Retrospective | Fin de semaine. Analyse commits, patterns de travail, metriques qualite |
| `/document-release` | MAJ docs | Apres une release. Lit les docs existantes, cross-ref le diff, met a jour |
| `/canary` | Monitoring post-deploy | Apres un deploy. Watch console errors, perf regressions, erreurs reseau |
| `/benchmark` | Regression perf | Avant/apres optim. Baseline de perf puis detection de regressions |
| `/codex` | Second avis | Review independante via OpenAI Codex. Utile pour les changements critiques |
| `/autoplan` | Pipeline review complet | Avant un gros lancement. Enchaine CEO + design + eng + DX review |
| `/land-and-deploy` | Merge + deploy + verify | Workflow complet : merge PR > attend CI > deploy > verifie en prod |

---

## Combos utiles pour FastAPI

**Nouveau endpoint API :**
```
1. Coder l'endpoint
2. /health          → verifier que mypy + ruff passent
3. /browse          → tester l'endpoint dans le navigateur
4. /review          → review avant merge
5. /ship            → merger
```

**Bug en production :**
```
1. /investigate     → trouver la root cause
2. /careful         → activer les garde-fous
3. Fixer le bug
4. /qa              → verifier le fix + regressions
5. /ship            → deployer le fix
```

**Avant une release :**
```
1. /health          → score qualite global
2. /cso             → audit securite (deps, secrets, OWASP)
3. /qa              → QA complete de l'app
4. /review          → review finale du diff
5. /ship            → release
6. /canary          → surveiller post-deploy
7. /document-release → mettre a jour la doc
```

**Refactor important :**
```
1. /checkpoint      → sauvegarder l'etat actuel
2. /plan-eng-review → valider l'architecture cible
3. /freeze src/api/ → verrouiller le scope
4. Refactorer
5. /health          → verifier que rien n'a casse
6. /review          → review du diff
7. /ship            → merger
```

---

## Memo rapide

| Besoin | Commande |
|--------|----------|
| Review mon code | `/review` |
| Debug un bug | `/investigate` |
| Tester mon app web | `/qa` ou `/browse` |
| Qualite du code | `/health` |
| Securite | `/cso` |
| Merger et deployer | `/ship` ou `/land-and-deploy` |
| Sauvegarder mon travail | `/checkpoint` |
| Mode prudent | `/careful` ou `/guard` |
| Qu'est-ce qu'on a appris | `/learn` |
| Retrospective | `/retro` |
