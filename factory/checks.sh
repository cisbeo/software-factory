#!/usr/bin/env bash
# Les contrôles du dépôt. Sortir avec 0 seulement quand la branche est bonne à relire.
#
# Le gate lance ce script depuis le checkout principal, avec le worktree du job
# comme dossier courant. Il doit rester rapide, déterministe et non interactif :
# pas de mode watch, pas de question, rien qui réécrive des fichiers.
set -euo pipefail

echo "factory/checks.sh n'est pas rempli : remplace ce bloc par les vrais contrôles du projet (voir INSTALL.md, étape Adapter)." >&2
exit 1
