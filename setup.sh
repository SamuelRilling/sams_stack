#!/usr/bin/env bash
# setup.sh — Sam's Stack: one-command bootstrap for the planner+executor workflow.
#
# Installs dependencies (git, python3, pipx, aider-chat), configures the planner
# runtime, wires your shell, and scaffolds the repo. Idempotent — safe to re-run.
#
# Usage:
#   ./setup.sh                  # interactive install
#   ./setup.sh --uninstall      # remove planner runtime (project files preserved)
#   ./setup.sh --no-deps        # skip dependency install (assume already present)
#   ./setup.sh --quiet          # less output, fail-fast
#   ./setup.sh --name=<project> # set project name in seeded ai/ files

set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PROJECT_SLUG="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-*$//')"
[[ -z "$PROJECT_SLUG" ]] && PROJECT_SLUG="project"

PLANNER_MODEL_DEFAULT="openrouter/z-ai/glm-4.5-air:free"
PLANNER_MODEL_BACKUP_DEFAULT="openrouter/deepseek/deepseek-chat-v3.1:free"

BIN_DIR="$HOME/.local/bin"
ENV_FILE="$HOME/.planner_env_${PROJECT_SLUG}"
BASHRC_MARKER="# >>> sams_stack runtime: ${PROJECT_SLUG} >>>"
BASHRC_END="# <<< sams_stack runtime: ${PROJECT_SLUG} <<<"

QUIET=false
SKIP_DEPS=false
PROJECT_NAME=""

# ── Output helpers ──────────────────────────────────────────────────────────
say()  { $QUIET || printf "\033[1;36m[setup]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[fail]\033[0m %s\n" "$*" >&2; exit 1; }
ok()   { $QUIET || printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }

# ── Flag parsing ────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --uninstall)
      say "Uninstalling Sam's Stack runtime..."
      rm -f "$BIN_DIR/planner" "$ENV_FILE"
      if [[ -f "$HOME/.bashrc" ]]; then
        sed -i "/$BASHRC_MARKER/,/$BASHRC_END/d" "$HOME/.bashrc"
      fi
      say "Removed. Project files in $PROJECT_DIR left intact."
      exit 0
      ;;
    --no-deps)  SKIP_DEPS=true ;;
    --quiet)    QUIET=true ;;
    --name=*)   PROJECT_NAME="${arg#--name=}" ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# //;s/^#//'
      exit 0
      ;;
  esac
done

# ── 1. Environment sanity ───────────────────────────────────────────────────
say "Project dir: $PROJECT_DIR"

case "$PROJECT_DIR" in
  /mnt/c/*|/mnt/d/*|/mnt/e/*)
    die "PROJECT_DIR is on Windows filesystem ($PROJECT_DIR). NTFS breaks Unix permissions. Clone into ~/projects/ instead."
    ;;
esac

# Detect platform
PLATFORM="unknown"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID" in
    ubuntu|debian) PLATFORM="apt" ;;
    fedora|rhel|centos) PLATFORM="dnf" ;;
    arch) PLATFORM="pacman" ;;
  esac
fi
if [[ "$(uname -s)" == "Darwin" ]]; then PLATFORM="brew"; fi

say "Platform: $PLATFORM"

# ── 2. Install dependencies ─────────────────────────────────────────────────
install_apt() {
  local missing=()
  for pkg in git python3 python3-pip python3-venv pipx curl util-linux; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    say "Installing missing packages: ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
  else
    ok "All apt packages present"
  fi
}

install_brew() {
  command -v brew >/dev/null || die "Homebrew not installed. See https://brew.sh"
  for pkg in git python pipx; do
    brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
  done
  ok "Homebrew packages OK"
}

if ! $SKIP_DEPS; then
  case "$PLATFORM" in
    apt)  install_apt ;;
    brew) install_brew ;;
    dnf|pacman)
      warn "Auto-install for $PLATFORM not implemented. Ensure git, python3, pipx, curl, flock are installed."
      ;;
    *)
      warn "Unknown platform. Assuming dependencies are already installed."
      ;;
  esac
else
  say "Skipping dependency install (--no-deps)"
fi

# Verify core tools
command -v git >/dev/null     || die "git not found after install"
command -v python3 >/dev/null || die "python3 not found after install"
command -v flock >/dev/null   || warn "flock not found — concurrent-launch protection will be weaker"

# pipx PATH handling
if ! command -v pipx >/dev/null; then
  die "pipx not found after install. Try: python3 -m pip install --user pipx && python3 -m pipx ensurepath"
fi
pipx ensurepath >/dev/null 2>&1 || true
export PATH="$BIN_DIR:$PATH"

# Aider
if ! command -v aider >/dev/null; then
  say "Installing aider-chat via pipx..."
  pipx install aider-chat
fi
command -v aider >/dev/null || die "aider install failed. Try manually: pipx install aider-chat"
ok "aider $(aider --version 2>&1 | head -1 | awk '{print $NF}')"

# Optional VS Code + Cline check
if command -v code >/dev/null; then
  ok "VS Code found"
else
  warn "VS Code not detected. Install from https://code.visualstudio.com for Cline executor support."
fi

# ── 3. API key + env file ───────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

_key_valid() {
  local k="${1:-}"
  [[ -n "$k" ]] && [[ "$k" != "REPLACE_WITH_YOUR_KEY" ]] && [[ "$k" =~ ^sk-or-v1- ]]
}

if _key_valid "${OPENROUTER_API_KEY:-}"; then
  ok "Using existing OPENROUTER_API_KEY (${#OPENROUTER_API_KEY} chars)"
  KEY_VAL="$OPENROUTER_API_KEY"
else
  echo
  echo "Get a free OpenRouter API key at: https://openrouter.ai/keys"
  read -rsp "Enter OPENROUTER_API_KEY: " key; echo
  [[ -z "$key" ]] && die "Empty key."
  if [[ ! "$key" =~ ^sk-or-v1- ]]; then
    warn "Key does not start with sk-or-v1- — double-check it's an OpenRouter key."
  fi
  KEY_VAL="$key"
fi
ok "Key to be written: ${#KEY_VAL} chars"

umask 077
cat > "$ENV_FILE" <<EOF
# ~/.planner_env — sourced by every shell via ~/.bashrc
# Generated by Sam's Stack setup.sh; safe to edit by hand.

# ── Credentials ─────────────────────────────────────────────────────────────
export OPENROUTER_API_KEY='$KEY_VAL'

# ── Planner models (Aider only — Cline configures its own model in VS Code) ─
# Active planner model. Toggle with: planner-swap
export PLANNER_MODEL='$PLANNER_MODEL_DEFAULT'

# Primary and backup definitions (used by planner-swap)
export PLANNER_MODEL_PRIMARY='$PLANNER_MODEL_DEFAULT'
export PLANNER_MODEL_BACKUP='$PLANNER_MODEL_BACKUP_DEFAULT'

# Project location (where run_planner.sh lives)
export PROJECT_DIR='$PROJECT_DIR'

# ── planner-swap: toggle planner model between primary and backup ───────────
planner-swap() {
  local envfile="\$HOME/.planner_env"
  local current next label

  current=\$(grep -E "^export PLANNER_MODEL=" "\$envfile" | head -1 | cut -d"'" -f2)

  if [[ "\$current" == "\$PLANNER_MODEL_PRIMARY" ]]; then
    next="\$PLANNER_MODEL_BACKUP"
    label="DeepSeek (backup)"
  else
    next="\$PLANNER_MODEL_PRIMARY"
    label="GLM (primary)"
  fi

  sed -i "s|^export PLANNER_MODEL=.*|export PLANNER_MODEL='\$next'|" "\$envfile"
  export PLANNER_MODEL="\$next"
  echo "Planner model → \$label"

  if [[ -x "\$PROJECT_DIR/setup.sh" ]]; then
    ( cd "\$PROJECT_DIR" && ./setup.sh --no-deps --quiet >/dev/null 2>&1 ) \\
      && echo "run_planner.sh regenerated." \\
      || echo "warn: regeneration failed — run ./setup.sh manually."
  fi
}

# ── planner-status: show active config ──────────────────────────────────────
planner-status() {
  local key="\${OPENROUTER_API_KEY:-}"
  echo "Project:        \$PROJECT_DIR"
  echo "Planner model:  \$PLANNER_MODEL"
  echo "  primary:      \$PLANNER_MODEL_PRIMARY"
  echo "  backup:       \$PLANNER_MODEL_BACKUP"
  if [[ -z "\$key" ]]; then
    echo "API key:        MISSING — run ./setup.sh"
  elif [[ "\$key" == "REPLACE_WITH_YOUR_KEY" ]] || [[ "\$key" == sk-or-v1-fake* ]]; then
    echo "API key:        INVALID (placeholder) — re-run ./setup.sh"
  elif [[ "\$key" =~ ^sk-or-v1- ]]; then
    echo "API key:        valid (\${#key} chars)"
  else
    echo "API key:        unrecognized format (\${#key} chars) — expected sk-or-v1-…"
  fi
}
EOF
chmod 600 "$ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"
ok "Wrote $ENV_FILE (chmod 600)"

# ── 4. Bashrc wiring ────────────────────────────────────────────────────────
if ! grep -q "$BASHRC_MARKER" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<EOF

$BASHRC_MARKER
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
case ":\$PATH:" in *":$BIN_DIR:"*) ;; *) export PATH="$BIN_DIR:\$PATH" ;; esac
$BASHRC_END
EOF
  ok "Wired ~/.bashrc"
fi

# ── 5. Project scaffold ─────────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/ai" "$PROJECT_DIR/.aider"
cd "$PROJECT_DIR"

if [[ ! -d .git ]]; then
  git init -q
  ok "Initialized git repo"
fi

# Seed bootstrap.md if missing or empty (preserve user's customized version)
if [[ ! -s "ai/bootstrap.md" ]]; then
  cat > "ai/bootstrap.md" <<'BOOTSTRAP'
You are the SYSTEM ARCHITECT for this repository.
You do NOT write production code.
You do NOT perform implementation.
You only design, plan, and orchestrate execution.
You operate in a strict loop:
========================
PLANNING LOOP (MANDATORY)
========================
STEP 1 — READ STATE
Always read:
- ai/architecture.md
- ai/roadmap.md
- ai/current_task.md
- ai/decisions.md
- ai/repo_map.md
STEP 2 — UPDATE UNDERSTANDING
- Update architecture if incorrect or incomplete
- Update roadmap if priorities changed
- Record any new decisions in ai/decisions.md
STEP 3 — GENERATE SINGLE EXECUTION TASK
You MUST output exactly ONE task for the execution agent (Cline).
The task MUST:
- be atomic
- modify minimal files
- include clear constraints
- include acceptance criteria
- avoid ambiguity
STEP 4 — WRITE OUTPUTS
You MUST update:
- ai/architecture.md (if needed)
- ai/roadmap.md (if needed)
- ai/current_task.md (always)
STEP 5 — STOP
Do NOT continue beyond the single task.
Do NOT speculate about future tasks.
========================
EXECUTION CONTRACT
========================
The execution agent (Cline + coding model) is:
- stateless
- non-architectural
- strictly follows your task
You are responsible for correctness BEFORE execution.
If instructions are ambiguous, you must refine them instead of delegating ambiguity.
========================
FAILURE RULE
========================
If execution failures occur:
- analyze root cause
- update architecture constraints
- refine next task
- NEVER repeat the same task unchanged
BOOTSTRAP
  ok "Seeded ai/bootstrap.md"
fi

# Seed memory files only if missing (preserve existing content)
declare -A SEEDS=(
  ["ai/architecture.md"]="# Architecture${PROJECT_NAME:+ — $PROJECT_NAME}\n\n> Replace with your project's reality. Keep brief — read every planner session."
  ["ai/roadmap.md"]="# Roadmap\n\n## Now\n\n## Next\n\n## Later\n\n## Done"
  ["ai/decisions.md"]="# Decisions\n\n> Append-only log of architectural choices."
  ["ai/repo_map.md"]="# Repo Map\n\n> High-level orientation by purpose."
  ["ai/current_task.md"]="# ${PROJECT_NAME:+$PROJECT_NAME — }No active task\n\nRun the planner to write the first task here."
)
for f in "${!SEEDS[@]}"; do
  if [[ ! -s "$f" ]]; then
    printf '%b' "${SEEDS[$f]}" > "$f"
    ok "Seeded $f"
  fi
done

if [[ ! -f .gitignore ]] || ! grep -q ".aider" .gitignore; then
  cat >> .gitignore <<'EOF'
.aider/
.aider.chat.history.md
.aider.input.history
.aider.tags.cache.v4/
.planner_env
*.pyc
__pycache__/
node_modules/
.env
.env.local
.DS_Store
EOF
  ok "Updated .gitignore"
fi

# ── 6. Generate run_planner.sh ──────────────────────────────────────────────
cat > run_planner.sh <<EOF
#!/usr/bin/env bash
# Pure Aider chat as planner. NO architect mode — Cline is the executor.
set -euo pipefail
cd "$PROJECT_DIR"

[ -f "$ENV_FILE" ] && source "$ENV_FILE"
[ -z "\${OPENROUTER_API_KEY:-}" ] && { echo "OPENROUTER_API_KEY not set. Run ./setup.sh"; exit 1; }

LOCK="$PROJECT_DIR/.aider/planner.lock"
mkdir -p "\$(dirname "\$LOCK")"
exec 9>"\$LOCK"
flock -n 9 || { echo "Another planner is already running in $PROJECT_DIR"; exit 1; }

[ -s ai/bootstrap.md ] || { echo "ai/bootstrap.md is empty — re-run ./setup.sh"; exit 1; }

exec aider \\
  --model "\$PLANNER_MODEL" \\
  --no-auto-commits \\
  --no-show-model-warnings \\
  --read ai/bootstrap.md \\
  --read ai/architecture.md \\
  --read ai/roadmap.md \\
  --read ai/decisions.md \\
  ai/current_task.md
EOF
chmod +x run_planner.sh
ok "Generated run_planner.sh"

# ── 7. Global command ───────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
ln -sf "$PROJECT_DIR/run_planner.sh" "$BIN_DIR/planner"
ok "Symlinked $BIN_DIR/planner"

# ── 8. Done ─────────────────────────────────────────────────────────────────
if ! $QUIET; then
  echo
  printf "\033[1;32m✓ Sam's Stack ready.\033[0m\n"
  echo
  echo "Activate in this shell:  source ~/.bashrc"
  echo "Check config:            planner-status"
  echo "Launch planner:          planner"
  echo "Swap to backup model:    planner-swap"
  echo "Uninstall:               ./setup.sh --uninstall"
fi
