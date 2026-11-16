# Dépôt public de la software factory, installable à la demande

Date : 2026-11-16 — Statut : à approuver

## Intention

La factory de le projet source fonctionne. On l'extrait dans un dépôt GitHub public qui
ne contient qu'elle, pour l'installer dans n'importe quel projet avec une
commande ou un prompt collé dans Claude Code, sur le modèle de
[ZazenCodes v2](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code-v2).

## Buts

- Un dépôt public, sous GPLv3, documentation en français.
- Installation en une étape pour l'utilisateur : coller un prompt (entrée
  principale) ou lancer `install.sh`.
- Fonctionne sur un projet inconnu : autre pile que npm, pas de `AGENTS.md`,
  pas de glossaire ni de standards, fichiers déjà présents.
- Mise à jour d'une factory déjà installée sans écraser les adaptations locales.

## Hors périmètre

- Modifier le projet source : il garde sa copie telle quelle. Le rebrancher sur le
  dépôt public sera une demande à part.
- Publier des jobs d'exemple (ceux de le projet source sont privés).
- Un plugin Claude Code ou un paquet npm.
- Traduire les prompts des agents : ils restent en anglais, comme aujourd'hui.

## Anti-buts

- Un installeur qui écrase un fichier du projet sans le dire.
- Une factory installée dont `checks.sh` passe à vide (aucun contrôle réel).
- Une trace de le projet source dans le dépôt public (nom, URL, commandes, données).

## Contraintes

- Dérivé de ZazenCodes (GPLv3) : `LICENSE` GPLv3 à la racine, crédits conservés.
- Les skills `tdd`, `diagnosing-bugs` et `pr` (Matt Pocock, MIT ; section de
  `pr` reprise de Dex Horthy) sont préchargés par le builder : ils font partie
  de la livraison, avec leur licence et leurs crédits.
- Prérequis côté projet cible : dépôt git avec `origin` sur GitHub, `gh`
  authentifié, `python3` ≥ 3.10, Claude Code récent (intake sur Fable), `curl`.
  `agent-browser` est requis seulement pour les relecteurs UI et UX.

## Approches

| | Principe | Verdict |
|---|---|---|
| A. Prompt seul | L'agent lit `INSTALL.md`, copie par `curl`, adapte | Copie refaite à la main à chaque fois, pas de mise à jour |
| B. Script seul | `curl … \| bash` copie tout | Ne sait pas adapter `checks.sh` ni les relecteurs |
| **C. Les deux** | `install.sh` fait la partie mécanique, `INSTALL.md` guide l'agent pour l'adaptation | **Retenue** par le propriétaire : copie fiable, adaptation intelligente, mise à jour possible |

Écarté : plugin Claude Code (les agents et `factory/` doivent vivre dans le
projet et y être adaptés).

## Conception

### Arborescence du dépôt

Les fichiers à installer sont aux mêmes chemins que dans le projet cible.

```
.claude/
  skills/factory/SKILL.md
  skills/tdd/…  skills/diagnosing-bugs/…  skills/pr/…
  skills/LICENSE-mattpocock-skills
  agents/  intake, spec-writer, builder, approver,
           reviewer-code, -spec, -standards, -security, -ui, -ux
factory/
  bin/job  bin/gate  bin/route
  checks.sh          gabarit, échoue tant qu'il n'est pas rempli
  config.json        valeurs par défaut
  dashboard.html
  CREDITS.md
install.sh           partie mécanique
MANIFEST             liste des fichiers installés, avec leur catégorie
VERSION              version courante (semver)
INSTALL.md           instructions pour l'agent installeur
README.md            présentation, prompt à coller, commandes
DESIGN.md            fonctionnement et écarts par rapport à ZazenCodes
LICENSE              GPLv3
tests/               tests de install.sh
.github/workflows/   CI : shellcheck + tests
```

### Deux catégories de fichiers (`MANIFEST`)

- **gérés** : `factory/bin/*`, `dashboard.html`, `SKILL.md` de la factory, les
  trois skills, `CREDITS.md`, licences. Identiques partout, remplacés à chaque
  mise à jour.
- **adaptés** : les dix agents, `checks.sh`, `config.json`. Copiés à la
  première installation, puis propriété du projet : jamais écrasés.

### `install.sh`

Bash, sans dépendance autre que `curl`, `tar`, `git`, `gh`. Lancé à la racine du
projet cible :

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | bash
```

Options : `--ref <tag|branche>` (défaut : dernière version publiée),
`--no-labels`, `--force`, `--dry-run`. Variable `FACTORY_SRC=<dossier>` pour
installer depuis une copie locale (tests).

Déroulé :

1. Vérifie les prérequis ; s'arrête avec un message clair sinon.
2. Télécharge l'archive de la version demandée dans un dossier temporaire.
3. **Première installation** (pas de `factory/.version`) : si un fichier du
   manifeste existe déjà, liste les conflits et s'arrête sans rien écrire,
   sauf `--force`. Sinon copie tout.
4. **Mise à jour** (`factory/.version` présent) : remplace les fichiers gérés ;
   pour chaque fichier adapté dont la version amont a changé depuis la version
   installée, dépose la nouvelle à côté en `<fichier>.upstream` et le signale.
5. Ajoute `/factory/jobs/` et `/.worktrees/` à `.gitignore` s'ils manquent.
6. Crée les trois labels GitHub (`gh label create --force`), sauf `--no-labels`.
7. Écrit `factory/.version` (versionné dans le projet) et affiche la suite :
   « demande à ton agent de suivre INSTALL.md, étape Adapter ».

Le script est idempotent et ne commite rien.

### `INSTALL.md` (pour l'agent)

1. Lancer `install.sh` ; en cas de conflit, montrer la liste à l'utilisateur et
   demander avant `--force`.
2. **Adapter** : remplir `checks.sh` avec les vrais contrôles du projet ; régler
   `base_branch`, `merge_method`, `ports` dans `config.json` ; ajuster les
   relecteurs sécurité, UI, UX, l'approver et l'intake au projet ; compléter
   `AGENTS.md` (préparation d'un checkout, serveur de dev, validation, section
   « Software factory »).
3. **Documents de référence** : si `GLOSSARY.md`, `CODING_STANDARDS.md` ou
   `docs/adr/` manquent, proposer de créer un squelette ; ne rien imposer.
4. **Vérifier** : `checks.sh` passe sur la branche courante, `bin/job queue`
   tourne, frontmatter des agents valide, `config.json` valide, chemins ignorés.
5. **Rendre la main** : commit sur la branche courante, demander avant de pousser.
6. Section **Mise à jour** : relancer `install.sh`, fusionner chaque
   `.upstream` dans le fichier adapté, supprimer les `.upstream`, revérifier.

### Généralisation du contenu

- `checks.sh` : gabarit qui sort en erreur avec « à remplir » (anti-but : pas de
  passage à vide).
- Agents : `GLOSSARY.md`, `CODING_STANDARDS.md`, `DESIGN.md`, `docs/adr/`
  deviennent « s'ils existent ». Sans standards, `reviewer-standards` juge sur
  les conventions de `AGENTS.md` et du code existant.
- `config.json` : valeurs actuelles, avec `auto_merge: "never"` et
  `concurrency: 1` par défaut (prudence pour un nouvel utilisateur).
- `CREDITS.md` réécrit pour un dépôt public : ZazenCodes (GPLv3), Matt Pocock
  (MIT), Dex Horthy.
- Recherche finale de `<projet-source>`, `cisbeo`, `Demande`, `drizzle`, `neon` : zéro
  occurrence.

### Tests

`tests/` lance `install.sh` avec `FACTORY_SRC` dans des dépôts git jetables et
vérifie : installation neuve, arrêt sur conflit sans écriture, `--force`,
relance idempotente, mise à jour (géré remplacé, adapté préservé, `.upstream`
créé), `.gitignore`, `--dry-run`. `gh` est remplacé par un faux binaire. CI :
shellcheck et ces tests à chaque push.

Validation finale : installation réelle dans un projet vierge non-npm, jusqu'à
`bin/job queue`.

## Choix faits par Claude (à corriger si besoin)

- Nom du dépôt : `cisbeo/software-factory`, public. **À confirmer avant création.**
- Fichiers à la racine aux chemins cibles, comme ZazenCodes, plutôt qu'un
  sous-dossier.
- `concurrency: 1` par défaut (le projet source est à 3).
- Fichiers `.upstream` pour les mises à jour, plutôt qu'une fusion automatique.
- Pas de jobs d'exemple.
- Versions par tags git (`v1.0.0`), `install.sh` prend le dernier tag.
- Le dépôt est construit dans `~/Projets/software-factory`.

## Laissé au constructeur

Forme exacte du `MANIFEST`, messages du script, détail des squelettes de
glossaire et de standards, contenu de `DESIGN.md`.
