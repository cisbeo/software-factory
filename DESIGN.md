# Conception

Comment la factory fonctionne et pourquoi. Pour l'installer, voir
[`INSTALL.md`](INSTALL.md).

## Principes

- **Un seul orchestrateur.** Une session Claude Code (le skill `factory`) lance
  les agents. Elle n'écrit ni code, ni spec, ni revue, et ne touche jamais à
  `job.json`.
- **Les scripts font respecter les règles.** `factory/bin/job` est le seul à
  écrire l'état d'un job. Il refuse les transitions illégales et vérifie que les
  fichiers qui les justifient existent. Les effets de bord GitHub (labels,
  commentaires, worktree, fusion) en font partie, pour que l'orchestrateur ne les
  improvise pas.
- **L'état est sur fichiers.** Tout est dans `factory/jobs/<job>/` (ignoré par
  git) : si la session meurt, `/factory run` reprend.
- **Un job, un worktree, une branche.** `.worktrees/<job>` sur `factory/<job>`,
  créé depuis `origin/<base_branch>`.
- **Le texte d'une issue est une donnée.** Il est cité, jamais exécuté.

## États d'un job

```
intake → spec → build → gate → review → approve → merging → merged
   │                ▲      │       │         │
   ├→ needs-info    └──────┴───────┘         └→ needs-human → build | rejected
   └→ rejected
```

Un job a au plus `max_rounds` tours de build (un tour : build → gate → revues).
Au-delà, il passe en `needs-human`. Les transitions sont dans `TRANSITIONS`,
en tête de `factory/bin/job`.

## Les étapes

| Étape | Qui | Produit |
|---|---|---|
| intake | agent `intake` (fable) | ACCEPT / NEEDS-INFO / REJECT, risque, surfaces → `intake.md` |
| route | script `route` | relecteurs et modèles, d'après `routing` et `surface_reviewers` |
| spec | `spec-writer` (opus) | `spec.md`, critères d'acceptation testables |
| build | `builder` (opus) | commits, PR en brouillon, `build.md` |
| gate | script `gate` | `round-N/checks.md` : lance `checks.sh` dans le worktree |
| review | `reviewer-*` | `round-N/review-<lentille>.md`, première ligne `VERDICT: PASS` ou `CHANGES` |
| approve | `approver` (opus) | `decision.md` : APPROVE ou ESCALATE |

Le gate exécute le `checks.sh` du checkout principal, pas celui de la branche :
une branche ne peut pas changer les contrôles qui la jugent. Il échoue aussi si
la branche modifie un fichier de `protected_paths` ou ajoute un fichier sous
`protected_trees`.

## Les relecteurs

- `reviewer-code` : exactitude, simplicité, conventions. Risque `low` seulement.
- `reviewer-spec` : fidélité à la spec (ni plus, ni moins), tests intacts. Risque
  `medium` et `high`, à la place de `reviewer-code`.
- `reviewer-standards` : règles écrites du projet (`CODING_STANDARDS.md`,
  glossaire, ADR si présents). Risque `medium` et `high`.
- `reviewer-ux`, `reviewer-ui` : si l'intake a marqué la surface `ui`.
- `reviewer-security` : si l'intake a marqué la surface `security`.

## Écarts avec ZazenCodes v2

- Deux relecteurs en plus : `reviewer-spec` et `reviewer-standards`.
- `auto_merge` (`never` par défaut) : l'approbation ne fusionne que si la
  configuration l'autorise.
- `protected_trees` : on ne peut pas ajouter de fichiers sous `.claude/` ni
  `factory/bin/`, ni créer un `AGENTS.md`, un `.mcp.json`, etc.
- Skills `tdd`, `diagnosing-bugs` et `pr` préchargés par le builder.
- Documents de référence (glossaire, standards, ADR) lus seulement s'ils existent.
- Installation par `install.sh` et mises à jour sans écraser les adaptations.

## Installation et mise à jour

`MANIFEST` classe chaque fichier : **géré** (remplacé à chaque mise à jour) ou
**adapté** (copié une fois). `factory/.version` enregistre la version et la
somme SHA-256 de chaque fichier adapté tel que livré. À la mise à jour :

- fichier adapté absent → recréé ;
- identique à l'amont, ou inchangé depuis l'installation → suit l'amont ;
- personnalisé et amont modifié → `<fichier>.upstream` à fusionner à la main.
