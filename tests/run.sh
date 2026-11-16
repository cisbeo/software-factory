#!/usr/bin/env bash
# Tests de install.sh : bash tests/run.sh [motif]
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_install_neuf() {
  new_project; run_install; assert_rc 0
  while IFS= read -r f; do assert_file "$f"; done < <(manifest_paths)
  for f in factory/bin/job factory/bin/gate factory/bin/route factory/checks.sh; do
    [ -x "$f" ] || fail "$f non exécutable"
  done
  assert_eq "$(head -1 factory/.version)" "$(cat "$REPO_ROOT/VERSION")"
}

test_conflit_n_ecrit_rien() {
  new_project; mkdir -p .claude/agents; echo local > .claude/agents/builder.md
  run_install; assert_rc 2
  assert_contains "$OUT" ".claude/agents/builder.md"
  assert_eq "$(cat .claude/agents/builder.md)" local
  assert_no_file factory
}

test_force_ecrase() {
  new_project; mkdir -p .claude/agents; echo local > .claude/agents/builder.md
  run_install --force; assert_rc 0
  cmp -s .claude/agents/builder.md "$REPO_ROOT/.claude/agents/builder.md" || fail "builder.md non remplacé"
}

test_prerequis() {
  local d="$TMP/horsgit-$RANDOM"; mkdir -p "$d"; cd "$d"
  run_install; assert_rc 1
  new_project; git remote remove origin
  run_install; assert_rc 1
  assert_no_file factory
}

test_chemin_avec_espaces() {
  new_project "mon projet"; run_install; assert_rc 0
  assert_file factory/bin/job
}

test_sous_dossier() {
  new_project; mkdir sub; cd sub
  run_install; assert_rc 0
  assert_file "$P/factory/bin/job"; assert_no_file "$P/sub/factory"
}

test_source_introuvable() {
  new_project; SRC_OVERRIDE=/inexistant run_install; assert_rc 3
  assert_no_file factory; assert_no_file .claude
}

test_dry_run() {
  new_project; run_install --dry-run; assert_rc 0
  assert_contains "$OUT" "factory/bin/job"
  assert_no_file factory; assert_no_file .gitignore
}

if [ -z "${SOURCED_ONLY:-}" ]; then
  pat=${1:-.}; pass=0; ko=0
  for t in $(declare -F | awk '{print $3}' | grep '^test_' | grep -E "$pat"); do
    echo "• $t"
    if ( "$t" ); then pass=$((pass+1)); else ko=$((ko+1)); fi
  done
  echo "$pass réussis, $ko échoués"; [ "$ko" = 0 ]
fi
