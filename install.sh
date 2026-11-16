#!/usr/bin/env bash
# Installe (ou met à jour) la software factory dans le projet courant.
#
#   curl -fsSL https://raw.githubusercontent.com/cisbeo/software-factory/main/install.sh | bash
#
# Options : --ref <tag|branche>  --force  --no-labels  --dry-run  --help
# Variables : FACTORY_SRC=<dossier> (installe depuis une copie locale),
#             FACTORY_REPO=<owner/repo> (défaut : cisbeo/software-factory)
#
# Codes de sortie : 0 OK, 1 prérequis manquant, 2 conflit, 3 source introuvable.
set -euo pipefail

REPO=${FACTORY_REPO:-cisbeo/software-factory}
REF=""
FORCE=0
NO_LABELS=0
DRY_RUN=0

die() { local code=$1; shift; echo "install.sh : $*" >&2; exit "$code"; }
info() { echo "$*"; }

usage() {
  sed -n '2,10p' "${BASH_SOURCE[0]}" 2>/dev/null | sed 's/^# \{0,1\}//' || true
}

while [ $# -gt 0 ]; do
  case $1 in
    --ref) [ $# -ge 2 ] || die 1 "--ref demande une valeur"; REF=$2; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-labels) NO_LABELS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die 1 "option inconnue : $1 (voir --help)" ;;
  esac
done

# --- Prérequis ---------------------------------------------------------------
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 1 "ce dossier n'est pas dans un dépôt git."
origin=$(git -C "$ROOT" remote get-url origin 2>/dev/null) || die 1 "le dépôt n'a pas de remote 'origin'."
case $origin in
  *github.com*) ;;
  *) die 1 "'origin' ne pointe pas vers GitHub ($origin)." ;;
esac
command -v gh >/dev/null 2>&1 || die 1 "gh est introuvable : https://cli.github.com/"
gh auth status >/dev/null 2>&1 || die 1 "gh n'est pas authentifié : lance 'gh auth login'."
command -v python3 >/dev/null 2>&1 || die 1 "python3 est introuvable (3.10 ou plus requis)."
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
  || die 1 "python3 3.10 ou plus est requis."

# --- Source ------------------------------------------------------------------
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ -n "${FACTORY_SRC:-}" ]; then
  SRC=$FACTORY_SRC
  [ -f "$SRC/MANIFEST" ] || die 3 "source introuvable ou invalide : $SRC (MANIFEST absent)."
else
  command -v curl >/dev/null 2>&1 || die 1 "curl est introuvable."
  command -v tar >/dev/null 2>&1 || die 1 "tar est introuvable."
  if [ -z "$REF" ]; then
    REF=$(git ls-remote --tags --sort=-v:refname "https://github.com/$REPO" 'v*' 2>/dev/null \
      | awk '{sub("refs/tags/", "", $2); if ($2 !~ /\^\{\}$/) {print $2; exit}}') || true
    REF=${REF:-main}
  fi
  curl -fsSL "https://github.com/$REPO/archive/$REF.tar.gz" -o "$WORK/src.tar.gz" \
    || die 3 "téléchargement impossible : $REPO @ $REF."
  mkdir "$WORK/src"
  tar -xzf "$WORK/src.tar.gz" -C "$WORK/src" --strip-components=1 \
    || die 3 "archive illisible : $REPO @ $REF."
  SRC=$WORK/src
  [ -f "$SRC/MANIFEST" ] || die 3 "archive sans MANIFEST : $REPO @ $REF."
fi
VERSION=$(tr -d '[:space:]' < "$SRC/VERSION")

# --- Plan --------------------------------------------------------------------
# Lignes du MANIFEST : "<categorie> <chemin>" ; # = commentaire.
MANIFEST_LINES=$(awk '!/^#/ && NF' "$SRC/MANIFEST")
[ -n "$MANIFEST_LINES" ] || die 3 "MANIFEST vide."

cd "$ROOT"

UPDATE=0
[ -f factory/.version ] && UPDATE=1

if [ "$UPDATE" = 0 ] && [ "$FORCE" = 0 ]; then
  conflicts=""
  while read -r _cat path; do
    [ -e "$path" ] && conflicts="$conflicts  $path"$'\n'
  done <<< "$MANIFEST_LINES"
  if [ -n "$conflicts" ]; then
    {
      echo "install.sh : ces fichiers existent déjà, rien n'a été écrit :"
      printf '%s' "$conflicts"
      echo "Compare-les avec la factory, puis relance avec --force pour les écraser."
    } >&2
    exit 2
  fi
fi

if [ "$DRY_RUN" = 1 ]; then
  info "Simulation (rien n'est écrit) — factory $VERSION :"
  while read -r cat path; do info "  $cat  $path"; done <<< "$MANIFEST_LINES"
  exit 0
fi

# --- Copie -------------------------------------------------------------------
copy_file() {
  mkdir -p "$(dirname "$1")"
  cp -p "$SRC/$1" "$1"
}

while read -r _cat path; do
  copy_file "$path"
done <<< "$MANIFEST_LINES"

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

{
  echo "$VERSION"
  while read -r cat path; do
    [ "$cat" = adapte ] && echo "$(sha "$SRC/$path")  $path"
  done <<< "$MANIFEST_LINES"
} > factory/.version

info "Factory $VERSION installée dans $ROOT."
info "Étape suivante : demande à ton agent de suivre INSTALL.md, étape « Adapter »."
