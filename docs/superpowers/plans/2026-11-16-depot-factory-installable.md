# Dépôt public de la software factory — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publier `cisbeo/software-factory`, un dépôt GPLv3 qui ne contient que la factory et l'installe dans un projet quelconque via `install.sh` + `INSTALL.md`.

**Architecture:** Les fichiers à installer sont à la racine du dépôt, aux chemins cibles. `MANIFEST` les classe en « gérés » (remplacés à chaque mise à jour) et « adaptés » (jamais écrasés). `install.sh` fait la copie, `.gitignore`, les labels et la version ; `INSTALL.md` guide l'agent pour l'adaptation.

**Tech Stack:** Bash (install + tests), Python 3 stdlib (scripts existants de la factory), GitHub Actions, `gh`.

**Spec:** `docs/superpowers/specs/2026-11-16-depot-factory-installable-design.md` (copie jointe ci-dessous)

## Global Constraints

- Source : `~/Projets/<projet-source>` (lecture seule, rien n'y est modifié hormis ce plan). Cible : `~/Projets/software-factory`, nouveau dépôt git, branche `main`.
- Documentation en français ; prompts des agents en anglais, inchangés hors généralisation.
- Licence GPLv3 à la racine ; crédits ZazenCodes (GPLv3), Matt Pocock (MIT), Dex Horthy conservés.
- Zéro occurrence de `<projet-source>`, `cisbeo` (hors URL du dépôt lui-même), `Demande`, `drizzle`, `neon`, `vitest` dans les fichiers installés.
- `install.sh` : dépendances `curl`, `tar`, `git`, `gh` seulement ; idempotent ; ne commite rien ; aucune lecture interactive (il tourne via `curl | bash`).
- Prérequis vérifiés : dépôt git, `origin` sur GitHub, `gh auth status` OK, `python3` ≥ 3.10.
- Ne jamais copier de `factory/jobs/`, `.env*`, ni de worktree.
- Création du dépôt GitHub public et push : seulement après confirmation explicite de le propriétaire (tâche 7).

## Review Focus

1. Chemin du projet contenant des espaces → l'installation réussit (toutes les expansions entre guillemets).
2. Téléchargement interrompu ou `--ref` inexistant → message clair, aucun fichier écrit dans le projet.
3. `.gitignore` sans saut de ligne final, ou contenant déjà les entrées → pas de ligne collée, pas de doublon.
4. Lancé depuis un sous-dossier du projet → s'installe à la racine git (`git rev-parse --show-toplevel`), pas dans le sous-dossier.
5. Fichier adapté supprimé par l'utilisateur avant une mise à jour → recréé depuis l'amont et signalé, sans erreur.

Chacun a son test dans la tâche 3 ou 4.

---

### Task 1: Squelette du dépôt et copie brute

**Files:**
- Create: `~/Projets/software-factory/` (`git init -b main`)
- Copy depuis le projet source, mêmes chemins : `.claude/agents/*.md` (10), `.claude/skills/{factory,tdd,diagnosing-bugs,pr}/**`, `.claude/skills/LICENSE-mattpocock-skills`, `factory/bin/{job,gate,route}`, `factory/checks.sh`, `factory/config.json`, `factory/dashboard.html`, `factory/CREDITS.md`
- Create: `LICENSE` (copie de `factory/LICENSE-zazencodes`, texte GPLv3), `VERSION` (`1.0.0`), `.gitignore` (`/factory/jobs/`, `/.worktrees/`)

**Interfaces:**
- Produces: l'arborescence que `MANIFEST` (tâche 3) énumère.

- [ ] **Step 1:** Créer le dossier, `git init -b main`, copier avec `git ls-files` du projet source comme source de vérité (seuls les fichiers versionnés partent).
- [ ] **Step 2:** Vérifier : `find . -type f -not -path './.git/*' | sort` liste exactement les fichiers ci-dessus ; `factory/bin/*` et `checks.sh` exécutables.
- [ ] **Step 3:** Commit `Copie initiale de la factory`.

### Task 2: Généralisation du contenu

**Files:**
- Modify: `factory/checks.sh`, `factory/config.json`, `factory/CREDITS.md`
- Modify: `.claude/agents/{intake,spec-writer,reviewer-spec,reviewer-standards}.md`, tout autre agent ou `SKILL.md` qui cite un document de référence

- [ ] **Step 1: `factory/checks.sh`** — garder l'en-tête et `set -euo pipefail`, remplacer les commandes npm par :

```bash
echo "factory/checks.sh n'est pas rempli : remplace ce bloc par les vrais contrôles du projet (voir INSTALL.md, étape Adapter)." >&2
exit 1
```

- [ ] **Step 2: `factory/config.json`** — `concurrency: 1` ; le reste inchangé (`auto_merge: "never"`, `base_branch: "main"`). `python3 -m json.tool` passe.
- [ ] **Step 3: Agents** — chaque mention de `GLOSSARY.md`, `CODING_STANDARDS.md`, `DESIGN.md`, `docs/adr/` devient conditionnelle (« if it exists »). Dans `reviewer-standards.md`, ajouter : sans `CODING_STANDARDS.md`, juger sur les conventions de `AGENTS.md` et du code voisin, et CHANGES seulement pour une règle écrite enfreinte. Ne pas toucher aux noms de fichiers, formats de première ligne ni réponses d'une ligne.
- [ ] **Step 4: `factory/CREDITS.md`** — réécrit en français pour un dépôt public : dérivé de ZazenCodes v2 (GPLv3, lien), skills de Matt Pocock (MIT), section de `pr` de Dex Horthy ; les logiciels produits par la factory ne sont pas couverts par la GPL.
- [ ] **Step 5: Vérifier** — `grep -rniE 'le projet source|cisbeo|drizzle|neon|vitest|Demande|npm run' .claude factory` ne renvoie rien ; `bash factory/checks.sh` sort en 1 ; `factory/bin/route --help` ou équivalent ne plante pas à l'import.
- [ ] **Step 6:** Commit `Généralise la factory pour un projet quelconque`.

### Task 3: `install.sh` — première installation

**Files:**
- Create: `install.sh`, `MANIFEST`, `tests/run.sh`, `tests/lib.sh`, `tests/fake-bin/gh`

**Interfaces:**
- `MANIFEST` : une ligne par fichier, `<categorie> <chemin>`, catégorie ∈ `gere` | `adapte`, lignes `#` ignorées. `adapte` = les 10 agents, `factory/checks.sh`, `factory/config.json` ; tout le reste `gere`.
- `install.sh [--ref <ref>] [--force] [--no-labels] [--dry-run]` ; env `FACTORY_SRC=<dossier>` (court-circuite le téléchargement), `FACTORY_REPO` (défaut `cisbeo/software-factory`).
- Ref par défaut : dernier tag `v*` (`git ls-remote --tags --sort=-v:refname`), sinon `main`. Archive : `https://github.com/$FACTORY_REPO/archive/<ref>.tar.gz`, extraite dans `mktemp -d`, nettoyée par `trap`.
- Codes de sortie : 0 OK, 1 prérequis manquant, 2 conflit, 3 téléchargement.
- Produces: `factory/.version` — ligne 1 la version (`VERSION`), puis une ligne `<sha256>  <chemin>` par fichier `adapte` tel que livré par l'amont.
- `tests/lib.sh` : `new_project` (dépôt git jetable avec `origin` GitHub factice, peut prendre un nom avec espaces), `run_install [args]` (PATH préfixé par `tests/fake-bin`, `FACTORY_SRC` = racine du dépôt), `assert_file`, `assert_no_file`, `assert_eq`, `assert_contains`. `tests/fake-bin/gh` journalise ses arguments dans `$GH_LOG` et sort en 0.

- [ ] **Step 1: Tests qui échouent** dans `tests/run.sh` :
  - `test_install_neuf` : après `run_install`, chaque chemin du `MANIFEST` existe, les `bin/*` et `checks.sh` sont exécutables, `factory/.version` commence par `1.0.0`, sortie 0.
  - `test_conflit_n_ecrit_rien` : `.claude/agents/builder.md` préexistant → sortie 2, le nom du fichier dans la sortie, contenu intact, `factory/` absent.
  - `test_force_ecrase` : même situation avec `--force` → sortie 0, fichier remplacé.
  - `test_prerequis` : hors dépôt git → sortie 1 ; sans `origin` → sortie 1.
  - `test_chemin_avec_espaces` (Review Focus 1).
  - `test_sous_dossier` : lancé depuis `sub/` → fichiers à la racine git (Review Focus 4).
  - `test_source_introuvable` : `FACTORY_SRC=/inexistant` → sortie 3, rien d'écrit (Review Focus 2).
  - `test_dry_run` : `--dry-run` liste les fichiers, n'écrit rien.
- [ ] **Step 2:** `bash tests/run.sh` → tous FAIL (install.sh absent).
- [ ] **Step 3:** Écrire `MANIFEST`, puis `install.sh` : prérequis → source → détection de conflits **avant** toute écriture → copie → `.version`. Messages en français.
- [ ] **Step 4:** `bash tests/run.sh` → PASS ; `shellcheck install.sh tests/*.sh` propre.
- [ ] **Step 5:** Commit `install.sh : première installation`.

### Task 4: `install.sh` — mise à jour, `.gitignore`, labels

**Files:**
- Modify: `install.sh`, `tests/run.sh`

**Interfaces:**
- Consumes: `factory/.version` (tâche 3).
- Mise à jour = `factory/.version` présent. Fichiers `gere` : remplacés. Fichier `adapte` : si absent, recréé et signalé ; si le sha amont nouveau ≠ sha enregistré, écrire `<chemin>.upstream` et le lister ; sinon ne rien faire. Puis réécrire `.version`.
- Labels : `factory` (5319E7), `factory:needs-info` (FBCA04), `factory:needs-human` (D93F0B), via `gh label create --force`.

- [ ] **Step 1: Tests qui échouent** :
  - `test_relance_idempotente` : deux `run_install` de suite → sortie 0, `git status --porcelain` identique après la 2ᵉ, aucun `.upstream`.
  - `test_maj_gere_remplace` : `factory/bin/job` modifié localement puis relance → revenu à l'amont.
  - `test_maj_adapte_preserve` : `checks.sh` modifié localement, amont inchangé → intact, pas de `.upstream`.
  - `test_maj_adapte_amont_change` : sha de `checks.sh` falsifié dans `.version` → `checks.sh` local intact, `checks.sh.upstream` = amont, nom listé en sortie.
  - `test_maj_adapte_supprime` : `factory/config.json` supprimé → recréé, signalé (Review Focus 5).
  - `test_gitignore` : absent → créé avec les 2 lignes ; présent sans saut de ligne final → 2 lignes ajoutées proprement ; déjà présentes → pas de doublon (Review Focus 3).
  - `test_labels` : `$GH_LOG` contient les 3 `label create` ; avec `--no-labels`, aucun.
- [ ] **Step 2:** `bash tests/run.sh` → les nouveaux FAIL.
- [ ] **Step 3:** Implémenter. Dernière sortie du script : version installée, `.upstream` à fusionner, puis « Demande à ton agent de suivre INSTALL.md, étape Adapter ».
- [ ] **Step 4:** `bash tests/run.sh` et `shellcheck` → PASS.
- [ ] **Step 5:** Commit `install.sh : mise à jour, .gitignore et labels`.

### Task 5: Documentation

**Files:**
- Create: `README.md`, `INSTALL.md`, `DESIGN.md`

- [ ] **Step 1: `INSTALL.md`** (français, adressé à l'agent), sections dans cet ordre : 0. Vérifier le projet · 1. Lancer `install.sh` (conflit → montrer la liste, demander avant `--force`) · 2. Adapter (`checks.sh` ; `base_branch`, `merge_method`, `ports` ; relecteurs sécurité/UI/UX, approver, intake ; `AGENTS.md` avec la section « Software factory » reprise mot pour mot de le projet source `AGENTS.md`) · 3. Documents de référence (proposer des squelettes `GLOSSARY.md`, `CODING_STANDARDS.md`, `docs/adr/`, sans imposer) · 4. Vérifier (les 5 contrôles de l'INSTALL de ZazenCodes) · 5. Rendre la main (commit sur la branche courante, demander avant de pousser, message d'accueil) · 6. Mise à jour (relancer, fusionner puis supprimer chaque `.upstream`, revérifier).
- [ ] **Step 2: `README.md`** : ce que c'est en 3 lignes ; prompt à coller ; commande `curl … | bash` ; prérequis (dont `agent-browser` pour les relecteurs UI/UX) ; schéma de la boucle avec les relecteurs `spec` et `standards` ; commandes `/factory` ; dashboard ; mise à jour ; coût et sécurité ; crédits et licence. Prompt :

```text
Installe cette software factory dans ce projet en suivant son INSTALL.md :

https://github.com/cisbeo/software-factory
```

- [ ] **Step 3: `DESIGN.md`** : fonctionnement (états d'un job, rôle de `bin/job`, gate, routage) et écarts par rapport à ZazenCodes v2 (`reviewer-spec`, `reviewer-standards`, `auto_merge`, `protected_trees`, skills préchargés, `install.sh`). S'appuyer sur le code, pas sur la mémoire.
- [ ] **Step 4:** Vérifier que chaque chemin et option cités existent (`grep` croisé avec `MANIFEST` et `install.sh --help`).
- [ ] **Step 5:** Commit `Documentation : README, INSTALL, DESIGN`.

### Task 6: CI et validation sur un projet vierge

**Files:**
- Create: `.github/workflows/ci.yml` (ubuntu-latest : `shellcheck install.sh tests/*.sh`, `bash tests/run.sh`, `python3 -m json.tool factory/config.json`, `python3 -m py_compile` sur `factory/bin/*`)

- [ ] **Step 1:** Écrire le workflow ; lancer localement les mêmes commandes → PASS.
- [ ] **Step 2: Projet vierge non-npm** dans le scratchpad : dépôt git avec un `Makefile` (`make test` = `python3 -m unittest`), `origin` GitHub factice, `gh` factice. `FACTORY_SRC=… install.sh`, puis remplir `checks.sh` avec `make test` comme le demande `INSTALL.md`.
- [ ] **Step 3:** Vérifier : `bash factory/checks.sh` sort en 0 ; `python3 -m json.tool factory/config.json` ; `git check-ignore factory/jobs/x .worktrees/x` imprime les deux ; `factory/bin/job queue` s'exécute (avec `gh` factice renvoyant `[]`) ; frontmatter des agents limité à `name`, `description`, `tools`, `model`, `skills`, `hooks`.
- [ ] **Step 4:** Commit `CI`.

### Task 7: Publication (après confirmation de le propriétaire)

- [ ] **Step 1:** Montrer à le propriétaire l'arborescence finale et le résultat des tests ; demander confirmation pour créer le dépôt public.
- [ ] **Step 2:** `gh repo create cisbeo/software-factory --public --source . --push --description "Software factory pour Claude Code : des issues GitHub aux pull requests"`.
- [ ] **Step 3:** `git tag v1.0.0 && git push origin v1.0.0` ; vérifier que la CI passe.
- [ ] **Step 4: Test bout en bout réel** : dans un dépôt jetable, `curl -fsSL https://raw.githubusercontent.com/cisbeo/software-factory/main/install.sh | bash -s -- --no-labels` → sortie 0, `factory/.version` = `1.0.0`.
