# Suggestions Veille Technologique — Gstack

---

## 📅 26 avril 2026 (mise à jour)

### 🤖 Gemini CLI — Provider alternatif gratuit (PRIORITÉ MOYENNE)
Google vient de sortir Gemini CLI (Apache 2.0, avril 2026) :
- 60 req/min **gratuit** avec Gemini 2.5 Pro, 1M contexte
- ReAct loop natif, support MCP, GitHub Actions pour bug-fixing autonome
- [ ] Tester dans les pipelines CI/CD Gstack comme alternative économique
- [ ] Comparer performances sur SWE-bench vs Claude Opus 4.7

### 🔧 Superpowers Framework — Composable Skills (à étudier)
Publié le 10 avril 2026, architecture similaire aux 23+ skills Gstack.
- [ ] Analyser : https://aitoolly.com/ai-news/article/2026-04-10-superpowers-a-comprehensive-agent-skill-framework-and-software-development-methodology-for-ai-coding
- [ ] Identifier patterns réutilisables pour améliorer la composabilité des skills

### 🕸️ OpenClaw — Intégration workflows autonomes
210K+ stars, agent self-hosted qui peut écrire ses propres skills.
- [ ] Étudier l'architecture de skills auto-extensibles
- [ ] Évaluer intégration OpenClaw + Gstack pour workflows hybrides

### 🔒 Sécurité Supply Chain MCP
Avec 23+ skills qui appellent potentiellement des MCPs tiers :
- [ ] Auditer chaque MCP tiers utilisé dans les skills Gstack
- [ ] Référence : https://authzed.com/blog/timeline-mcp-breaches

### 🔄 Gstack Update Pipeline ✅
Skill `/gstack-update` avec fork URL enforced en place ✅.
- [ ] Ajouter tests automatiques post-update (regression tests)
- [ ] Webhook pour notifier quand upstream publie une nouvelle version

---

## 📅 11 avril 2026 (historique)

### A2A Protocol ✅ (toujours prioritaire)
Standardiser les échanges entre /cso, /qa, /review via A2A.
- Repo: https://github.com/a2aproject/A2A

### Letta — Portabilité d'agents
Exporter skills Gstack comme agents portables au format .af (snapshot mémoire + tools + prompts).
- Repo: https://github.com/letta-ai/letta

### Spec-Driven Development (GitHub Spec Kit)
Intégrer une skill /spec compatible Spec Kit v0.5.0.

### OpenCode comme alternative
OpenCode (95K+ stars, Go) — tester la compatibilité des skills Gstack avec OpenCode.
