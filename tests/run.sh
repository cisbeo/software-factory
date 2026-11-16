#!/usr/bin/env bash
# Tests de install.sh : bash tests/run.sh [motif]
set -u
# shellcheck source=tests/lib.sh
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
  local d="$TMP/horsgit-$RANDOM"; mkdir -p "$d"; cd "$d" || exit
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
  new_project; mkdir sub; cd sub || exit
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

test_relance_idempotente() {
  new_project; run_install; assert_rc 0
  local avant; avant=$(git status --porcelain --untracked-files=all)
  run_install; assert_rc 0
  assert_eq "$(git status --porcelain --untracked-files=all)" "$avant"
  [ -z "$(find . -name '*.upstream' -not -path './.git/*')" ] || fail ".upstream inattendu"
}

test_maj_gere_remplace() {
  new_project; run_install; echo "# local" >> factory/bin/job
  run_install; assert_rc 0
  cmp -s factory/bin/job "$REPO_ROOT/factory/bin/job" || fail "factory/bin/job non remis à l'amont"
}

test_maj_adapte_preserve() {
  new_project; run_install; echo "# local" >> factory/checks.sh
  run_install; assert_rc 0
  assert_contains "$(tail -1 factory/checks.sh)" "# local"
  assert_no_file factory/checks.sh.upstream
}

test_maj_adapte_amont_change() {
  new_project; run_install; echo "# local" >> factory/checks.sh
  sed -i.bak 's#^[0-9a-f]\{64\}  factory/checks.sh$#0000000000000000000000000000000000000000000000000000000000000000  factory/checks.sh#' factory/.version
  rm factory/.version.bak
  run_install; assert_rc 0
  assert_contains "$(tail -1 factory/checks.sh)" "# local"
  cmp -s factory/checks.sh.upstream "$REPO_ROOT/factory/checks.sh" || fail ".upstream différent de l'amont"
  assert_contains "$OUT" "factory/checks.sh.upstream"
}

test_maj_adapte_non_modifie_suit_l_amont() {
  new_project; run_install
  sed -i.bak 's#^[0-9a-f]\{64\}  factory/checks.sh$#0000000000000000000000000000000000000000000000000000000000000000  factory/checks.sh#' factory/.version
  rm factory/.version.bak
  # checks.sh local identique à l'amont : rien à signaler
  run_install; assert_rc 0
  assert_no_file factory/checks.sh.upstream
  # fichier jamais touché par l'utilisateur, amont modifié : suit l'amont sans .upstream
  local src="$TMP/src-$RANDOM"; mkdir -p "$src"; cp -R "$REPO_ROOT"/. "$src"/; rm -rf "$src/.git"
  echo "# nouveau" >> "$src/factory/checks.sh"
  SRC_OVERRIDE=$src run_install; assert_rc 0
  assert_no_file factory/checks.sh.upstream
  assert_contains "$(tail -1 factory/checks.sh)" "# nouveau"
}

test_maj_adapte_supprime() {
  new_project; run_install; rm factory/config.json
  run_install; assert_rc 0
  assert_file factory/config.json
  assert_contains "$OUT" "factory/config.json"
}

test_gitignore() {
  new_project; run_install; assert_rc 0
  assert_eq "$(cat .gitignore)" "$(printf '/factory/jobs/\n/.worktrees/')"
  new_project; printf 'node_modules' > .gitignore
  run_install; assert_rc 0
  assert_eq "$(cat .gitignore)" "$(printf 'node_modules\n/factory/jobs/\n/.worktrees/')"
  run_install; assert_rc 0
  assert_eq "$(grep -c '^/factory/jobs/$' .gitignore)" 1
}

test_labels() {
  new_project; run_install; assert_rc 0
  for l in "factory" "factory:needs-info" "factory:needs-human"; do
    grep -q "^label create $l " "$GH_LOG" || fail "label $l non créé"
  done
  new_project; run_install --no-labels; assert_rc 0
  ! grep -q '^label create' "$GH_LOG" || fail "labels créés malgré --no-labels"
}

test_upstream_persiste() {
  new_project; run_install; echo "# local" >> factory/checks.sh
  sed -i.bak 's#^[0-9a-f]\{64\}  factory/checks.sh$#0000000000000000000000000000000000000000000000000000000000000000  factory/checks.sh#' factory/.version
  rm factory/.version.bak
  run_install; assert_contains "$OUT" "factory/checks.sh.upstream"
  rm factory/checks.sh.upstream
  run_install; assert_rc 0
  assert_contains "$OUT" "factory/checks.sh.upstream"   # l'avertissement ne disparaît pas tout seul
  assert_file factory/checks.sh.upstream
}

test_refuse_les_liens_symboliques() {
  new_project; mkdir -p "$TMP/cible"; ln -s "$TMP/cible" factory
  run_install --force; assert_rc 2
  assert_eq "$(find "$TMP/cible" -type f | wc -l | tr -d ' ')" 0
  rm factory; : > "$TMP/autre"; ln -s "$TMP/autre" .gitignore
  run_install; assert_rc 2
  assert_eq "$(wc -c < "$TMP/autre" | tr -d ' ')" 0
}

if [ -z "${SOURCED_ONLY:-}" ]; then
  pat=${1:-.}; pass=0; ko=0
  for t in $(declare -F | awk '{print $3}' | grep '^test_' | grep -E "$pat"); do
    echo "• $t"
    if ( "$t" ); then pass=$((pass+1)); else ko=$((ko+1)); fi
  done
  echo "$pass réussis, $ko échoués"; [ "$ko" = 0 ]
fi
