# Installer la factory

Tu es un agent de code qui installe cette factory dans le projet de
l'utilisateur. La partie mécanique est faite par `install.sh` ; toi, tu adaptes,
tu vérifies et tu rends la main. Travaille à la racine du projet.

## 0. Vérifier le projet

Arrête-toi et préviens l'utilisateur si l'un de ces points échoue (`install.sh`
les contrôle aussi) :

- dépôt git avec un `origin` sur GitHub ; `gh auth status` OK, avec le droit de
  pousser et de gérer les labels ;
- la branche par défaut (`gh repo view --json defaultBranchRef`) existe sur
  `origin` ;
- `claude --version` récent (l'agent `intake` tourne sur Fable) ;
- `python3 --version` ≥ 3.10.

## 1. Lancer l'installeur

```bash
curl -fsSL https://raw.githubusercontent.com/cisbeo/software-factory/main/install.sh | bash
```

Il copie les fichiers de `MANIFEST`, complète `.gitignore`, crée les trois
labels GitHub et écrit `factory/.version`. Options : `--ref <tag|branche>`,
`--no-labels`, `--dry-run`, `--force`.

Si des fichiers existent déjà, il s'arrête sans rien écrire (code 2) et les
liste. Montre la liste à l'utilisateur et **demande avant d'utiliser `--force`**.

## 2. Adapter

Les fichiers « adaptés » (`MANIFEST`, catégorie `adapte`) sont à toi ; les
fichiers « gérés » ne se modifient pas.

**`factory/checks.sh`.** Remplace le gabarit par les vrais contrôles du projet :
installation des dépendances si un worktree neuf en a besoin, puis lint,
typecheck, tests, build, selon ce que le projet a. Cherche-les dans `AGENTS.md`,
`CLAUDE.md`, `package.json`, `Makefile`, `pyproject.toml`, la CI. Le script
tourne avec le worktree d'un job comme dossier courant ; il doit être non
interactif, ne rien réécrire (pas de `--fix`, pas de mise à jour de snapshots)
et sortir en non-zéro au moindre échec. Garde `set -euo pipefail`.

**`factory/config.json`.**

- `base_branch` : la branche par défaut.
- `merge_method` : `merge`, `squash` ou `rebase`, autorisé par le dépôt
  (`gh api repos/{owner}/{repo} --jq '{allow_merge_commit, allow_squash_merge, allow_rebase_merge}'`).
- `protected_paths` : garde les entrées de la factory ; n'ajoute pas les tests du
  projet (une fonctionnalité légitime modifie des tests existants).
- `ports` : déplace `base` si les ports 5100–5199 sont déjà pris.
- `auto_merge` reste à `never` et `concurrency` à `1` sauf demande de
  l'utilisateur.

**Agents.** Adapte les listes de contrôle à la pile sans changer leur
structure, leurs noms de fichiers, les formats de première ligne ni les réponses
d'une ligne :

- `reviewer-security.md` : les points sensibles du projet (authentification,
  accès aux données, paiements et webhooks, entrées utilisateur vers requêtes
  ou HTML) ;
- `reviewer-ui.md` : où vivent les design tokens, le thème, les composants
  partagés ;
- `reviewer-ux.md` : les types d'utilisateurs de l'application ;
- `approver.md` : ce qu'un humain doit toujours voir, à ajouter à la liste
  ESCALATE ;
- `intake.md` : remplace le commentaire sous **Decide** par une ligne disant à
  quoi sert le projet.

Les relecteurs UI et UX utilisent la CLI `agent-browser` ; si le projet n'a pas
d'interface, ils ne sont jamais lancés.

**`AGENTS.md`** (ou `CLAUDE.md`, selon ce que le projet utilise ; crée
`AGENTS.md` si aucun n'existe). Tous les agents le lisent. Il doit dire :

- comment préparer un checkout neuf (dépendances, fichiers d'environnement) ;
- comment lancer le serveur de dev sur un port donné, s'il y en a un ;
- les commandes de validation, identiques à `factory/checks.sh`.

Ajoute ensuite cette section :

```markdown
## Software factory

`/factory run` builds every open GitHub issue labeled `factory` through
intake → spec → build → gate → review → approve, one PR per issue. State is in
`factory/jobs/` (gitignored); `factory/bin/job` is its only writer. Checks:
`factory/checks.sh`. Dashboard: `cd factory && python3 -m http.server`, then
open http://localhost:8000/dashboard.html.

Each job works in its own git worktree, a full checkout of the repo at
`.worktrees/<job-id>` (gitignored). A tool run from the repo root that doesn't
read `.gitignore` sees those copies too; exclude `.worktrees/` in its config.
```

## 3. Documents de référence (facultatif)

Les agents lisent, **s'ils existent**, `GLOSSARY.md`, `CODING_STANDARDS.md`,
`DESIGN.md` et `docs/adr/`. Si le projet n'en a pas, propose à l'utilisateur d'en
créer un squelette (glossaire des termes du domaine, règles de code, décisions
d'architecture). N'impose rien : sans eux, les relecteurs jugent sur
`AGENTS.md` et sur le code voisin.

## 4. Vérifier

1. `bash factory/checks.sh` sort en 0 sur la branche courante. Sinon la factory
   ne pourra jamais valider un job : corrige le script (pas le projet) ou dis
   à l'utilisateur ce qui est cassé.
2. `factory/bin/job queue` s'exécute sans erreur.
3. Chaque fichier de `.claude/agents/` n'a que ces clés de frontmatter : `name`,
   `description`, `tools`, `model`, et `skills`/`hooks` sur le builder. Claude
   Code ignore sans prévenir les clés inconnues : une faute de frappe change
   le comportement en silence.
4. `python3 -m json.tool factory/config.json` réussit.
5. `git check-ignore factory/jobs/x .worktrees/x` affiche les deux chemins, et
   `git status --porcelain --untracked-files=all` liste comme committables
   `.claude/` et `factory/`.

## 5. Rendre la main

Reste sur la branche de l'utilisateur : n'en crée pas d'autre. Commite
l'installation avec un message d'une ligne et montre le diff. **Demande avant de
pousser** : la factory crée chaque job depuis `origin/<base_branch>`, donc
l'installation doit y être avant le premier lancement.

Dis ensuite, en quelques lignes :

- étiquette une ou deux petites issues `factory`, puis lance `/factory run`
  dans Claude Code depuis la racine du projet ;
- chaque job finit en PR ; l'approver fusionne ce qu'il approuve (si
  `auto_merge` l'autorise), le reste attend avec le label `factory:needs-human` ;
  on approuve en fusionnant la PR, ou on dit à la factory quoi changer avec
  `/factory <texte>` ;
- `intake` tourne sur Fable, une fois par issue ; selon le forfait, cela peut
  consommer des crédits d'usage ;
- pour démarrer prudemment, garde `concurrency: 1` et lis chaque PR.

## 6. Mettre à jour

Relance la commande de l'étape 1. Les fichiers gérés sont remplacés. Pour chaque
fichier adapté que l'amont a modifié et que l'utilisateur a personnalisé,
l'installeur écrit `<fichier>.upstream` et le liste. Fusionne chaque
`.upstream` dans le fichier adapté, supprime-le, puis refais l'étape 4.
