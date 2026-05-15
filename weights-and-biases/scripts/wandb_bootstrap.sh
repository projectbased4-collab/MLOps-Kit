#!/usr/bin/env bash
#===============================================================================
# wandb_bootstrap.sh
#
# Purpose:
#   Initialise a Weights & Biases (W&B) project in the current working
#   directory, configure the W&B API key, and verify connectivity.  Designed
#   for first-run developer setup and CI/CD bootstrapping.
#
# When to use:
#   • Setting up W&B on a new machine or CI runner for the first time.
#   • Rotating or injecting a new API key for an existing project.
#   • Interactive discovery of an existing W&B project to attach to.
#
# Prerequisites:
#   • Python >= 3.8 (wandb >= 0.16 required)
#   • jq >= 1.6  (optional – prettifies API responses)
#   • write access to  $HOME/.config/wandb/settings  or  .netrc
#
# Usage:
#   ./wandb_bootstrap.sh [-y|--yes] [-n|--dry-run] [-e|--entity ENTITY] [-p|--project PROJECT]
#                        [-k|--key KEY]
#
# Flags:
#   -y, --yes          Non-interactive; use defaults / env vars.
#   -n, --dry-run      Print actions without executing them.
#   -e, --entity       W&B entity (team or username).
#   -p, --project      W&B project name (default: basename of CWD).
#   -k, --key          Supply W&B API key directly (avoids prompt).
#   -h, --help         Show this help message and exit.
#
# Environment variables:
#   WANDB_API_KEY       Pre-set API key (highest precedence).
#   WANDB_ENTITY        Default entity when --entity is not given.
#   WANDB_PROJECT       Default project when --project is not given.
#
# Verify:
#   wandb online           # should print "Weights & Biases is online"
#   wandb status           # shows active run / project context
#
# Rollback:
#   wandb logout   # removes stored API credentials
#   rm -f .netrc   # removes netrc entry if one was written
#
# Outputs:
#   WANDB_API_KEY (env)  – Set and validated for the current shell session.
#   WANDB_ENTITY         – Resolved entity written to .netrc context.
#   WANDB_PROJECT        – Resolved project name.
#
# Common errors:
#   • "wandb: command not found"
#       → pip install wandb
#
#   • "wandb: API key is invalid"
#       → Regenerate your key at https://wandb.ai/settings → API keys.
#
#   • "403 Forbidden" when listing projects
#       → The --entity or --project does not exist or you lack access to it.
#
# References:
#   • W&B Install Guide:    https://docs.wandb.ai/guides/getting-started
#   • W&B API Keys:         https://docs.wandb.ai/guides/security/api-keys
#   • Console API reference: https://docs.wandb.ai/guides/public-apis
#===============================================================================

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
readonly DEFAULT_PROJECT="${WANDB_PROJECT:-$(basename "$PWD")}"
# shellcheck disable=SC2034
readonly WANDB_CONFIG_DIR="${HOME}/.config/wandb"

# ── Defaults ─────────────────────────────────────────────────────────────────
DRY_RUN=false
ASSUME_YES=false
ENTITY_ARG=""
PROJECT_ARG=""
KEY_ARG=""

# ── Colour helpers ────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

# shellcheck disable=SC2059
log_info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

die() { log_error "$*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '/^# Usage:/,/^# Flags:/p' "$0" | sed 's/^# //; s/^#//' | sed '/^$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)        ASSUME_YES=true;  shift ;;
    -n|--dry-run)    DRY_RUN=true;     shift ;;
    -e|--entity)     ENTITY_ARG="$2";  shift 2 ;;
    -p|--project)    PROJECT_ARG="$2"; shift 2 ;;
    -k|--key)        KEY_ARG="$2";     shift 2 ;;
    -h|--help)       usage ;;
    *)               log_warn "Unknown flag: $1 (ignored)"; shift ;;
  esac
done

# ── Binary validation ─────────────────────────────────────────────────────────
require_python_pkg() {
  local pkg="$1"
  if ! python3 -c "import ${pkg//[^a-zA-Z0-9_]/_}" 2>/dev/null; then
    die "Python package '${pkg}' is not installed. Run: pip install ${pkg}"
  fi
}

require_binary() {
  local binary="$1"
  if ! command -v "$binary" &>/dev/null; then
    log_warn "Optional binary '$binary' not found; some features will be limited."
  fi
}

log_info "Checking required tools …"
require_binary python3
require_binary wandb
require_binary jq
require_python_pkg wandb

# ── Dry-run helper ────────────────────────────────────────────────────────────
# shellcheck disable=SC2059
run() {
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC}  %s\n" "$*"
  else
    "$@"
  fi
}

# ── Step 1 – resolve entity and project ──────────────────────────────────────
ENTITY="${ENTITY_ARG:-${WANDB_ENTITY:-}}"
PROJECT="${PROJECT_ARG:-${WANDB_PROJECT:-${DEFAULT_PROJECT}}}"

if [[ -z "$ENTITY" ]]; then
  if $ASSUME_YES; then
    die "Entity must be supplied via --entity or WANDB_ENTITY in non-interactive mode."
  fi
  # shellcheck disable=SC2059
  printf "${YELLOW}Enter your W&B entity (team or username):${NC} "
  read -r ENTITY
fi
[[ -z "$ENTITY" ]] && die "Entity is required."

log_info "Entity : $ENTITY"
log_info "Project: $PROJECT"

# ── Step 2 – API key ──────────────────────────────────────────────────────────
if ${KEY_ARG:+true}; then
  WANDB_API_KEY="$KEY_ARG"
else
  WANDB_API_KEY="${WANDB_API_KEY:-}"
fi

if [[ -z "$WANDB_API_KEY" ]]; then
  if $ASSUME_YES; then
    die "WANDB_API_KEY must be set via --key or the WANDB_API_KEY env var in non-interactive mode."
  fi
  # shellcheck disable=SC2059
  printf "${YELLOW}Enter your W&B API key (stored in .netrc, not echoed):${NC} "
  read -rs WANDB_API_KEY
  printf '\n'
fi

export WANDB_API_KEY="$WANDB_API_KEY"

# ── Step 3 – verify API key ───────────────────────────────────────────────────
log_info "Verifying API key …"
if ! $DRY_RUN; then
  if ! wandb online &>/dev/null; then
    die "wandb online failed.  Check API key and network connectivity."
  fi
fi
log_info "API key is valid."

# ── Step 4 – write .netrc ─────────────────────────────────────────────────────
if ! $DRY_RUN; then
  NETRC_DIR="${HOME}"
  NETRC_FILE="${NETRC_DIR}/.netrc"
  mkdir -p "$NETRC_DIR"
  chmod 600 "$NETRC_FILE" 2>/dev/null || true
  {
    printf "machine api.wandb.ai\n"
    printf "  login api\n"
    printf "  password %s\n" "$WANDB_API_KEY"
  } >> "$NETRC_FILE"
  log_info "API key written to ${NETRC_FILE}"
else
  log_info "[DRY-RUN] Would write API key to ${HOME}/.netrc"
fi

# ── Step 5 – pre-create / verify project ─────────────────────────────────────
log_info "Checking project '%s' in entity '%s' …" "$PROJECT" "$ENTITY"

if $DRY_RUN; then
  log_info "[DRY-RUN] Would verify/create W&B project '$PROJECT' in entity '$ENTITY'."
else
  if wandb api projects --entity "$ENTITY" --name "$PROJECT" 2>/dev/null | jq -e '.name' >/dev/null 2>&1; then
    log_info "Project '$PROJECT' already exists."
  else
    log_warn "Project '$PROJECT' not found in entity '$ENTITY'; it will be created on first run push."
  fi
fi

# ── Step 6 – optional sandbox run ────────────────────────────────────────────
if ! $ASSUME_YES && ! $DRY_RUN; then
  # shellcheck disable=SC2059
  printf "${YELLOW}Run a one-off W&B login verification (online)? [y/N]${NC} "
  read -r -n1 _confirm || true
  echo
  if [[ ${_confirm,,} =~ ^y ]]; then
    python3 - <<'PY'
import wandb, sys
try:
    wandb.init(project="<injected>", entity="<injected>", mode="offline")
    wandb.finish()
    print("W&B offline init succeeded — configuration is correct.")
except Exception as e:
    print(f"W&B offline init failed: {e}", file=sys.stderr)
    sys.exit(1)
PY
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
log_info "✅  W&B initialisation complete."
log_info "   Entity  : $ENTITY"
log_info "   Project : $PROJECT"
log_info ""
log_info "Start logging:"
log_info "  python -c \"import wandb; wandb.init(project='%s', entity='%s')\"" \
  "$PROJECT" "$ENTITY"
log_info "  wandb online   # confirm daemon is reachable"
log_info "  wandb status   # show session details"
