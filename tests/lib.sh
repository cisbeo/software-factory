# Aides communes aux tests de install.sh.
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "    ÉCHEC : $*"; exit 1; }

# Dépôt git jetable avec un origin GitHub factice ; s'y place.
new_project() {
  P="$TMP/${1:-projet}-$RANDOM"
  mkdir -p "$P" && git -C "$P" init -q -b main
  git -C "$P" remote add origin https://github.com/acme/app.git
  export GH_LOG="$TMP/gh.log"; : > "$GH_LOG"
  cd "$P"
}

# Lance install.sh ; remplit OUT et RC.
run_install() {
  RC=0
  OUT=$(PATH="$REPO_ROOT/tests/fake-bin:$PATH" FACTORY_SRC="${SRC_OVERRIDE:-$REPO_ROOT}" \
    bash "$REPO_ROOT/install.sh" "$@" 2>&1) || RC=$?
}

assert_file()    { [ -f "$1" ] || fail "fichier attendu : $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "fichier inattendu : $1"; }
assert_eq()      { [ "$1" = "$2" ] || fail "attendu '$2', obtenu '$1' ${3:-}"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "'$2' absent de : $1";; esac; }
assert_rc()      { [ "$RC" = "$1" ] || fail "code de sortie attendu $1, obtenu $RC. Sortie : $OUT"; }
manifest_paths() { awk '!/^#/ && NF {print $2}' "$REPO_ROOT/MANIFEST"; }
