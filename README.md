# Software factory pour Claude Code

Une factory qui travaille sur tes issues GitHub. Étiquette une issue `factory`,
lance `/factory run` : des agents décident si elle mérite d'être construite,
écrivent une spécification, codent, passent tes propres contrôles, relisent, et
ouvrent une pull request qui ferme l'issue. L'approbateur fusionne ce dont il
est sûr et te passe le reste.

## Installer

Dans Claude Code, à la racine de ton projet, colle :

```text
Installe cette software factory dans ce projet en suivant son INSTALL.md :

https://github.com/cisbeo/software-factory
```

L'agent lance `install.sh`, remplit `factory/checks.sh` avec les vrais contrôles
de ton projet, adapte les relecteurs à ta pile, vérifie, puis commite.

Ou à la main, pour la partie mécanique seulement :

```bash
curl -fsSL https://raw.githubusercontent.com/cisbeo/software-factory/main/install.sh | bash
```

Il copie les fichiers, complète `.gitignore`, crée les labels GitHub. Il faut
ensuite faire l'étape « Adapter » d'[`INSTALL.md`](INSTALL.md).

**Prérequis** : Claude Code récent, `git` avec un `origin` GitHub, `gh`
authentifié (pousser, gérer les labels), `python3` ≥ 3.10, `curl`, `tar`. La CLI
`agent-browser` n'est nécessaire que pour les relecteurs UI et UX.

## La boucle

```
issues étiquetées `factory`
        │
        ▼
intake (fable) ── NEEDS-INFO → pose la question sur l'issue et attend
        │         REJECT     → explique sur l'issue, retire le label
        ▼ ACCEPT, éventuellement recadrée ; note le risque et les surfaces
route (script)    choisit relecteurs et modèles d'après config.json
        ▼
spec-writer (opus) → spec.md
        ▼
builder (opus) → commits, push, PR en brouillon « Closes #n »
        ▼            ▲
gate (script) ─FAIL──┤  factory/checks.sh ; aucun relecteur sur un build qui échoue
        ▼ PASS       │
relecteurs ─CHANGES──┘  code (risque faible) ou spec + standards (risque moyen/élevé) ; + ux et ui sur les changements d'interface ; + sécurité
        ▼ tous PASS
approver (opus) ── APPROVE  → synchronise avec la base, gate, fusionne si `auto_merge` l'autorise
                └─ ESCALATE → PR prête pour toi, issue étiquetée factory:needs-human
```

Une session Claude Code orchestre tous les jobs, `concurrency` à la fois
(défaut : 1). Chaque job a son worktree et sa branche `factory/<job-id>`. Tout
l'état est dans `factory/jobs/` : si la session meurt, `/factory run` reprend.

## Commandes

```
/factory run          vide la file : toutes les issues `factory` ouvertes ; reprend aussi
/factory run <n>      une seule issue
/factory <texte>      parler à la factory : questions, retours sur un job, nouvelle fonctionnalité
```

Tu approuves en fusionnant la PR sur GitHub. Pour modifier une PR escaladée, dis
à la factory ce que tu veux avec `/factory`.

## Tableau de bord

```bash
cd factory && python3 -m http.server
```

Puis ouvre <http://localhost:8000/dashboard.html> : une carte par job, avec
issue, PR, relecteurs par tour, risque, coût et durée.

## Mettre à jour

Relance la commande d'installation. Les fichiers gérés (scripts, tableau de
bord, skill `factory`, skills embarqués) sont remplacés ; les fichiers adaptés
(agents, `checks.sh`, `config.json`) ne sont jamais écrasés : si l'amont a changé
un fichier que tu as personnalisé, la nouvelle version est déposée à côté en
`<fichier>.upstream`, à fusionner puis à supprimer. La version installée est dans
`factory/.version`.

## Coût et sécurité

- La factory ouvre de vraies PR et consomme ton forfait Claude. Démarre avec
  `concurrency: 1` et lis chaque PR tant que tu ne lui fais pas confiance.
  `auto_merge` vaut `never` par défaut.
- `intake` tourne sur Fable, une fois par issue ; selon le forfait, cela peut
  consommer des crédits d'usage.
- Seules les issues étiquetées `factory` sont traitées, et seuls les profils
  avec droit de triage ou d'écriture peuvent poser ce label. Le texte des issues
  arrive aux agents comme donnée citée, jamais comme instruction.
- La factory ne pousse que des branches `factory/*`, ne fusionne que par
  `gh pr merge`, ne déploie jamais.

## Contenu

```
.claude/skills/factory/     l'orchestrateur (file, concurrence, pipeline)
.claude/skills/{tdd,diagnosing-bugs,pr}/   skills préchargés par le builder
.claude/agents/             intake, spec-writer, builder, reviewer-*, approver
factory/bin/{job,gate,route}  état, contrôle, routage
factory/{checks.sh,config.json,dashboard.html}
install.sh  MANIFEST  VERSION  INSTALL.md  DESIGN.md
```

[`DESIGN.md`](DESIGN.md) explique le fonctionnement et les écarts avec la
version de départ.

## Crédits et licence

Dérivée de [Software Factory for Claude Code (v2)](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code-v2)
de ZazenCodes ; skills de Matt Pocock (MIT) ; voir [`factory/CREDITS.md`](factory/CREDITS.md).

Distribué sous [GPLv3](LICENSE). Les logiciels que la factory produit dans ton
projet ne sont pas couverts par cette licence.
