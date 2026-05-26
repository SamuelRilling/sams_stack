#!/usr/bin/env bash
# test/test_setup.sh — validate Sam's Stack setup.sh end-to-end in a sandbox.
# Runs in temp dir, does not touch real $HOME files.
#
# Usage: ./test/test_setup.sh

set -uo pipefail

PASS=0
FAIL=0
FAILED_TESTS=()

ok()   { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "\033[1;31m  ✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); FAILED_TESTS+=("$*"); }
hdr()  { printf "\n\033[1;36m== %s ==\033[0m\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SANDBOX=$(mktemp -d)
FAKE_HOME="$SANDBOX/home"
PROJECT="$SANDBOX/project"
mkdir -p "$FAKE_HOME" "$PROJECT"

cp -r "$REPO_DIR"/* "$PROJECT/" 2>/dev/null
cp -r "$REPO_DIR"/.clinerules "$REPO_DIR"/.gitignore "$REPO_DIR"/.github "$PROJECT/" 2>/dev/null || true

cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

cd "$PROJECT"
chmod +x setup.sh test/test_setup.sh 2>/dev/null || true

hdr "Phase 1: Required files present"
for f in setup.sh README.md TEMPLATE_SETUP.md HANDOFF_FORMAT.md LICENSE .clinerules .gitignore; do
  [[ -f "$f" ]] && ok "$f" || fail "$f missing"
done
for d in ai docs/examples test .github/workflows; do
  [[ -d "$d" ]] && ok "$d/ directory" || fail "$d/ missing"
done

hdr "Phase 2: ai/ memory files"
for f in bootstrap.md architecture.md roadmap.md decisions.md repo_map.md current_task.md; do
  [[ -s "ai/$f" ]] && ok "ai/$f non-empty" || fail "ai/$f missing or empty"
done

hdr "Phase 3: ai/bootstrap.md preserved (user's version)"
grep -q "SYSTEM ARCHITECT" ai/bootstrap.md && ok "Contains 'SYSTEM ARCHITECT'" || fail "bootstrap.md lost original content"
grep -q "PLANNING LOOP" ai/bootstrap.md    && ok "Contains 'PLANNING LOOP'"   || fail "bootstrap.md missing planning loop"
grep -q "FAILURE RULE" ai/bootstrap.md     && ok "Contains 'FAILURE RULE'"    || fail "bootstrap.md missing failure rule"

hdr "Phase 4: Examples preserved"
[[ -f docs/examples/handoff.md ]]            && ok "docs/examples/handoff.md present"            || fail "handoff.md example missing"
[[ -f docs/examples/prompt-01-foundation.md ]] && ok "docs/examples/prompt-01-foundation.md present" || fail "foundation example missing"

hdr "Phase 5: setup.sh syntax"
bash -n setup.sh 2>/dev/null && ok "setup.sh syntax OK" || fail "setup.sh syntax error"

hdr "Phase 6: No architect-mode bug"
grep -q "\-\-architect" setup.sh && fail "--architect flag still present" || ok "No --architect flag"
grep -q "editor-model" setup.sh  && fail "editor-model still referenced"  || ok "No editor-model reference"

hdr "Phase 7: Required functions in setup.sh"
grep -q "planner-swap()"   setup.sh && ok "planner-swap function"   || fail "planner-swap missing"
grep -q "planner-status()" setup.sh && ok "planner-status function" || fail "planner-status missing"
grep -q "PLANNER_MODEL_BACKUP" setup.sh && ok "PLANNER_MODEL_BACKUP defined" || fail "PLANNER_MODEL_BACKUP missing"
grep -q "deepseek" setup.sh && ok "DeepSeek backup configured" || fail "DeepSeek missing"

hdr "Phase 8: CLI flags"
grep -q "\-\-uninstall" setup.sh && ok "--uninstall flag"      || fail "--uninstall missing"
grep -q "\-\-no-deps"   setup.sh && ok "--no-deps flag"        || fail "--no-deps missing"
grep -q "\-\-quiet"     setup.sh && ok "--quiet flag"          || fail "--quiet missing"
grep -q "\-\-help"      setup.sh && ok "--help flag"           || fail "--help missing"

hdr "Phase 9: Dependency-install logic"
grep -q "install_apt" setup.sh   && ok "apt install function"   || fail "apt install missing"
grep -q "install_brew" setup.sh  && ok "brew install function"  || fail "brew install missing"
grep -q "pipx install aider-chat" setup.sh && ok "Aider install via pipx" || fail "Aider install missing"

hdr "Phase 10: End-to-end dry run with stubs"
export PATH="$SANDBOX/stubs:$PATH"
mkdir -p "$SANDBOX/stubs"
for cmd in sudo apt-get dpkg pipx aider brew; do
  cat > "$SANDBOX/stubs/$cmd" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  install) exit 0 ;;
  --version) echo "stub 0.0.0"; exit 0 ;;
  ensurepath) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$SANDBOX/stubs/$cmd"
done

HOME="$FAKE_HOME" OPENROUTER_API_KEY="sk-or-v1-faketestkey" \
  PROJECT_DIR="$PROJECT" bash setup.sh --quiet > "$SANDBOX/setup.log" 2>&1
RC=$?
[[ $RC -eq 0 ]] && ok "setup.sh exits 0 (first run)" || { fail "setup.sh exit $RC"; tail -20 "$SANDBOX/setup.log"; }

[[ -f "$FAKE_HOME/.planner_env" ]]   && ok "~/.planner_env created"   || fail "~/.planner_env not created"
[[ -f "$PROJECT/run_planner.sh" ]]   && ok "run_planner.sh generated" || fail "run_planner.sh missing"
[[ -d "$PROJECT/.git" ]]             && ok "git repo initialized"     || fail "git repo missing"

hdr "Phase 11: Idempotency"
HOME="$FAKE_HOME" PROJECT_DIR="$PROJECT" bash setup.sh --quiet > "$SANDBOX/setup2.log" 2>&1
RC=$?
[[ $RC -eq 0 ]] && ok "setup.sh exits 0 (second run)" || fail "Second run failed ($RC)"

COUNT=$(grep -c "sams_stack runtime" "$FAKE_HOME/.bashrc" 2>/dev/null || echo 0)
[[ $COUNT -eq 2 ]] && ok "bashrc has exactly one runtime block" || fail "bashrc has $COUNT markers (expected 2)"

hdr "Phase 12: Generated run_planner.sh checks"
RP="$PROJECT/run_planner.sh"
[[ -x "$RP" ]] && ok "run_planner.sh executable" || fail "run_planner.sh not executable"
bash -n "$RP" && ok "run_planner.sh syntax OK" || fail "run_planner.sh syntax error"

grep -q "\-\-architect" "$RP" && fail "run_planner.sh has --architect" || ok "No --architect in run_planner.sh"
grep -q "flock"                "$RP" && ok "Lock present"             || fail "Lock missing"
grep -q "\-\-read ai/bootstrap.md" "$RP" && ok "Reads bootstrap.md"   || fail "bootstrap.md not loaded"

hdr "Phase 13: Functions callable after sourcing env"
HOME="$FAKE_HOME" bash -c "
  source '$FAKE_HOME/.planner_env'
  type planner-swap >/dev/null && type planner-status >/dev/null && echo OK
" | grep -q OK && ok "planner-swap + planner-status defined" || fail "Functions not defined after source"

hdr "Phase 14: API key file permissions"
PERMS=$(stat -c '%a' "$FAKE_HOME/.planner_env" 2>/dev/null || stat -f '%A' "$FAKE_HOME/.planner_env" 2>/dev/null)
[[ "$PERMS" == "600" ]] && ok ".planner_env chmod 600" || fail ".planner_env perms = $PERMS (expected 600)"

hdr "Phase 15: Uninstall"
HOME="$FAKE_HOME" bash setup.sh --uninstall > "$SANDBOX/uninstall.log" 2>&1
RC=$?
[[ $RC -eq 0 ]] && ok "Uninstall exits 0" || fail "Uninstall failed ($RC)"
[[ ! -f "$FAKE_HOME/.planner_env" ]] && ok "Uninstall removed .planner_env" || fail "Uninstall left .planner_env"
! grep -q "sams_stack runtime" "$FAKE_HOME/.bashrc" 2>/dev/null && ok "Uninstall cleaned bashrc" || fail "Uninstall left bashrc block"
[[ -f "$PROJECT/run_planner.sh" ]] && ok "Project files preserved" || fail "Uninstall deleted project files"

# ── Summary ─────────────────────────────────────────────────────────────────
echo
printf "\033[1m== Summary ==\033[0m\n"
printf "  Passed: \033[1;32m%d\033[0m\n" "$PASS"
printf "  Failed: \033[1;31m%d\033[0m\n" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi

echo
printf "\033[1;32mAll tests passed.\033[0m\n"
exit 0
