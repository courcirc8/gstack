# gstack Secure Updater

Script de mise a jour securisee des skills gstack avec audit automatique.

## Probleme

gstack est mis a jour frequemment. Chaque update modifie des fichiers SKILL.md
qui sont des **prompts executes par Claude** — un vecteur d'attaque potentiel
(prompt injection, exfiltration de cles API, commandes shell malveillantes).

## Solution

`gstack-secure-update.sh` automatise le workflow :

```
Fetch upstream → Diff vs installed → Security audit → Report → Deploy (avec backup)
```

## Usage

```bash
# Update standard avec audit interactif
./gstack-secure-update.sh

# Voir les diffs complets
./gstack-secure-update.sh --verbose

# Re-auditer sans re-fetcher
./gstack-secure-update.sh --skip-fetch

# Mode CI : abort automatique si alertes
./gstack-secure-update.sh --auto
```

## Audit de securite

Le script scanne automatiquement :

| Check | Quoi | Severite |
|-------|------|----------|
| Commandes shell suspectes | `curl`, `wget`, `eval`, `base64`, `nc`... | WARN |
| URLs non-allowlistees | Domaines inconnus dans les SKILL.md | WARN |
| Patterns d'injection | "ignore previous instructions", `<system>`, etc. | ALERT |
| Exfiltration de donnees | References a `API_KEY`, `.ssh`, credentials | WARN |
| Nouveaux outils MCP | `mcp__*` non recenses | WARN |
| Executables | Nouveaux fichiers avec permissions exec | WARN |
| Permissions | `chmod`, `chown` dans les templates | WARN |

## Fichiers

```
~/.gstack-dev/
├── upstream-audit/     # Clone upstream (re-utilise entre updates)
└── audit-reports/
    ├── report-*.txt    # Rapports d'audit horodates
    ├── diff-*.patch    # Diffs horodates
    └── backup-*/       # Backups avant deploy (rollback possible)
```

## Rollback

Chaque deploy cree un backup. Pour revenir en arriere :

```bash
# Le script affiche la commande exacte apres chaque deploy
rm -rf ~/.claude/skills/gstack && cp -r ~/.gstack-dev/audit-reports/backup-XXXXXXXX-XXXXXX ~/.claude/skills/gstack
```

## Personnalisation

```bash
# Upstream custom (votre fork)
./gstack-secure-update.sh --repo https://github.com/courcirc8/gstack.git

# Skills dans un autre dossier
./gstack-secure-update.sh --skills /path/to/skills/gstack

# Dossier d'audit custom
./gstack-secure-update.sh --audit /tmp/gstack-audit
```
