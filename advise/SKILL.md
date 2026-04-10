---
name: advise
version: 1.0.0
description: |
  Development phase advisor. Detects the current phase of work (coding, debugging,
  pre-release, post-deploy, refactoring, etc.) and recommends the most useful gstack
  skills. Tailored for FastAPI + Python workflows. Use when asked "what should I do",
  "which skill", "advise", "what's next", "help me", or "workflow". (gstack)
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

## Preamble — Detect development phase

```bash
# --- Collect signals about current state ---
echo "=== GIT STATE ==="
git status --short 2>/dev/null | head -20
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "UNCOMMITTED_FILES: $_UNCOMMITTED"
_LAST_COMMIT=$(git log -1 --format="%h %s (%cr)" 2>/dev/null || echo "none")
echo "LAST_COMMIT: $_LAST_COMMIT"
_COMMITS_AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
echo "COMMITS_AHEAD_OF_REMOTE: $_COMMITS_AHEAD"

echo ""
echo "=== PROJECT SIGNALS ==="
# Detect FastAPI
[ -f "requirements.txt" ] && grep -qi "fastapi\|uvicorn" requirements.txt 2>/dev/null && echo "FRAMEWORK: FastAPI"
[ -f "pyproject.toml" ] && grep -qi "fastapi\|uvicorn" pyproject.toml 2>/dev/null && echo "FRAMEWORK: FastAPI"
[ -f "Pipfile" ] && grep -qi "fastapi\|uvicorn" Pipfile 2>/dev/null && echo "FRAMEWORK: FastAPI"

# Detect test state
_TEST_FILES=$(find . -name "test_*.py" -o -name "*_test.py" 2>/dev/null | wc -l | tr -d ' ')
echo "TEST_FILES: $_TEST_FILES"

# Detect recent errors in git log
_RECENT_FIXES=$(git log --oneline -20 2>/dev/null | grep -ci "fix\|bug\|error\|hotfix" || echo "0")
echo "RECENT_FIX_COMMITS: $_RECENT_FIXES"

# Check if PR exists
_HAS_PR=$(gh pr view --json state --jq '.state' 2>/dev/null || echo "none")
echo "PR_STATE: $_HAS_PR"

# Check if there's a VERSION file
[ -f "VERSION" ] && echo "VERSION: $(cat VERSION)" || echo "VERSION: none"

# Check health score if available
_HEALTH_FILE="${GSTACK_HOME:-$HOME/.gstack}/projects/$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)/health-history.jsonl"
if [ -f "$_HEALTH_FILE" ]; then
  _LAST_HEALTH=$(tail -1 "$_HEALTH_FILE" 2>/dev/null | grep -o '"composite":[0-9.]*' | cut -d: -f2)
  echo "LAST_HEALTH_SCORE: ${_LAST_HEALTH:-unknown}"
else
  echo "LAST_HEALTH_SCORE: never_run"
fi

# Detect deploy config
[ -f "fly.toml" ] && echo "DEPLOY: fly.io"
[ -f "render.yaml" ] && echo "DEPLOY: render"
[ -f "Dockerfile" ] && echo "HAS_DOCKERFILE: yes"
[ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] && echo "HAS_DOCKER_COMPOSE: yes"

echo ""
echo "=== RECENT ACTIVITY ==="
git log --oneline -5 2>/dev/null || echo "no commits"
```

## Instructions

You are a development workflow advisor for a **FastAPI + Python** project. Based on the
preamble signals above, detect the user's current development phase and recommend
the right gstack skills.

### Phase detection rules

Analyze the signals and classify into ONE primary phase:

**PHASE: STARTING** (new feature or session start)
- Branch just created, few/no commits ahead
- No uncommitted files
- Signals: `COMMITS_AHEAD_OF_REMOTE: 0`, clean working tree

**PHASE: CODING** (actively writing code)
- Uncommitted changes present
- On a feature/fix branch
- Signals: `UNCOMMITTED_FILES > 0`, branch != main/master

**PHASE: DEBUGGING** (fixing issues)
- Recent fix/bug commits
- Error-related branch names (fix/, bugfix/, hotfix/)
- Signals: `RECENT_FIX_COMMITS > 2`, or branch contains "fix"

**PHASE: TESTING** (validating work)
- Code written, need to verify
- Test files exist but might not pass
- Signals: `UNCOMMITTED_FILES: 0`, `TEST_FILES > 0`, commits ahead

**PHASE: PRE-MERGE** (ready to ship)
- Commits ahead, clean tree, PR exists or about to create
- Signals: `COMMITS_AHEAD > 0`, `UNCOMMITTED_FILES: 0`, `PR_STATE: OPEN`

**PHASE: PRE-RELEASE** (preparing a release)
- On main/release branch, VERSION file present
- Signals: branch is main/master/release, VERSION exists

**PHASE: POST-DEPLOY** (just shipped)
- Recent merge to main, deploy config present
- Signals: last commit is a merge, branch is main

**PHASE: REFACTORING** (restructuring code)
- Many files changed, branch name contains refactor/cleanup/tech-debt
- Signals: branch contains "refactor" or "cleanup"

**PHASE: MAINTENANCE** (routine upkeep)
- On main, nothing urgent, health score available
- Signals: branch is main, `UNCOMMITTED_FILES: 0`, `COMMITS_AHEAD: 0`

### Skill recommendations by phase

Present recommendations as a short, actionable table. Use this mapping:

```
STARTING:
  → /checkpoint       "Sauvegarder le point de depart"
  → /plan-eng-review  "Valider l'architecture avant de coder"
  → /learn            "Consulter ce qu'on sait deja sur ce projet"

CODING:
  → /health           "Verifier mypy + ruff au fil de l'eau"
  → /careful          "Si vous touchez a la BDD ou aux migrations"
  → /freeze src/      "Verrouiller le scope si besoin"
  → /browse           "Tester l'endpoint dans le navigateur"

DEBUGGING:
  → /investigate      "Debug systematique — pas de fix sans root cause"
  → /careful          "Garde-fous actifs pendant le debug"
  → /browse           "Reproduire le bug dans le navigateur"
  → /checkpoint       "Sauvegarder avant de tenter un fix risque"

TESTING:
  → /health           "Score qualite complet (mypy, ruff, pytest)"
  → /qa               "QA web interactive — teste et fixe les bugs"
  → /qa-only          "QA sans fix — juste le rapport"
  → /browse           "Verifier manuellement les endpoints"

PRE-MERGE:
  → /review           "Review du diff avant merge"
  → /cso              "Audit securite (deps, secrets, OWASP)"
  → /health           "Dernier check qualite"
  → /ship             "Workflow complet : tests > review > PR > push"

PRE-RELEASE:
  → /cso              "Audit securite complet"
  → /health           "Score qualite final"
  → /qa               "QA complete de l'app"
  → /review           "Review finale"
  → /ship             "Release"
  → /document-release "Mettre a jour la documentation"

POST-DEPLOY:
  → /canary           "Surveiller l'app en prod (erreurs, perf)"
  → /browse           "Verifier manuellement en prod"
  → /document-release "MAJ docs post-release"
  → /retro            "Retrospective de la semaine"

REFACTORING:
  → /checkpoint       "Sauvegarder l'etat avant refactor"
  → /plan-eng-review  "Valider l'architecture cible"
  → /freeze src/api/  "Verrouiller le scope du refactor"
  → /health           "Verifier que rien n'a casse"
  → /review           "Review du diff"

MAINTENANCE:
  → /health           "Dashboard qualite — tendances"
  → /cso              "Audit securite periodique"
  → /retro            "Retrospective"
  → /learn            "Revoir et pruner les apprentissages"
```

### Output format

Respond with:

1. **Phase detectee** — nom + explication en 1 ligne basee sur les signaux
2. **Skills recommandees** — tableau avec commande, description, et priorite (faire maintenant / optionnel)
3. **Combo suggere** — la sequence d'actions recommandee, numerotee
4. Si la phase est ambigue, poser UNE question via `AskUserQuestion` pour clarifier

Keep it short. No walls of text. The user wants to know what to do, not why.
