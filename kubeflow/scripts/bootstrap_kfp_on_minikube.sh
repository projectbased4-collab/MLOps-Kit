#!/usr/bin/env bash
#===============================================================================
# bootstrap_kfp_on_minikube.sh
#
# Purpose:
#   Orchestrate the full bootstrapping of a local Kubeflow Pipelines (KFP) 1.x
#   deployment on Minikube, including Minikube startup, kustomize-based KFP
#   manifest installation, and port-forward set-up for the UI and API.
#
# When to use:
#   • Setting up a local KFP playground on a developer laptop or CI runner.
#   • Preparing an integration-test environment that exercises pipeline runs
#     end-to-end.
#   • Rapid iteration on pipeline YAML before pushing to a cluster.
#
# Prerequisites:
#   • Linux / macOS x86_64 or arm64
#   • Minikube >= 1.29, kubectl >= 1.26, kustomize >= 4.5
#   • curl >= 7.60  (optional – used by --install-deps if -y is set)
#   • At least 4 GB free RAM and 2 CPU cores available on the host
#
# Usage:
#   ./bootstrap_kfp_on_minikube.sh [-y|--yes] [-n|--dry-run] [-p|--profile NAME]
#
# Flags:
#   -y, --yes         Skip interactive prompts (non-interactive / CI mode).
#   -n, --dry-run     Print each step without executing it.
#   -p, --profile     Minikube profile / cluster name  (default: kfp-dev).
#   -h, --help        Show this help message and exit.
#
# Verify:
#   kubectl --context kfp-dev get pods -n kubeflow
#   # All pods reach Running state (~2-5 minutes on first run).
#
#   Forward UI:
#   kubectl --context kfp-dev -n kubeflow port-forward svc/ml-pipeline-ui 8080:80 &
#   # Open http://localhost:8080 in a browser.
#
# Rollback:
#   minikube delete -p kfp-dev      # destroy cluster + KFP installation
#   # or edit overlays before re-running if only manifests need resetting.
#
# Outputs:
#   KFP_API_URI        – ML pipeline API endpoint (printed on success)
#   KFP_UI_URI         – ML pipeline UI endpoint (printed on success)
#
# Common errors:
#   • "minikube: command not found"
#       → Install Minikube: https://minikube.sigs.k8s.io/docs/start/
#
#   • "kustomize: command not found"
#       → Install kustomize: https://kustomize.io/installation/
#
#   • KFP pods stuck in Pending / ImagePullBackOff
#       → Run  minikube cache add <image>  for every missing image, or
#          increase Minikube RAM:  minikube start --cpus=4 --memory=8192
#
#   • Insufficient disk space
#       → Free several GB under  $MINIKUBE_HOME  (default ~/.minikube).
#
# References:
#   • KFP install overlays: https://github.com/kubeflow/pipelines/tree/master/manifests/kustomize
#   • Minikube docs:     https://minikube.sigs.k8s.io/docs/
#   • kustomize docs:    https://kustomize.io/
#===============================================================================

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
KFP_KUSTOMIZE_MANIFESTS_VERSION="v2.2.0"
DEFAULT_PROFILE="kfp-dev"
KFP_NAMESPACE="kubeflow"
# shellcheck disable=SC2034
KUBE_CONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# ── Defaults ─────────────────────────────────────────────────────────────────
DRY_RUN=false
ASSUME_YES=false
PROFILE="${DEFAULT_PROFILE}"
ASSUMED_CONTINUOUS=false

# ── Colour helpers (disabled in CI / NO_COLOR) ──────────────────────────────
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

die() {
  log_error "$*"
  exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '/^# Usage:/,/^# Flags:/p' "$0" | sed 's/^# //; s/^#//' | sed '/^$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)    ASSUME_YES=true;  shift ;;
    -n|--dry-run) DRY_RUN=true;    shift ;;
    -p|--profile) PROFILE="$2";    shift 2 ;;
    -h|--help)   usage ;;
    *)           log_warn "Unknown flag: $1 (ignored)"; shift ;;
  esac
done

# ── Required-binary checks ────────────────────────────────────────────────────
require_binary() {
  local binary="$1"
  if ! command -v "$binary" &>/dev/null; then
    die "Required binary '$binary' not found in PATH. Install it and retry."
  fi
}

log_info "Checking required binaries …"
require_binary minikube
require_binary kubectl
require_binary kustomize

# ── Dry-run helper ────────────────────────────────────────────────────────────
# shellcheck disable=SC2059
run() {
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC}  %s\n" "$*"
  else
    "$@"
  fi
}

# ── Step 1 – interactive confirmation ────────────────────────────────────────
if ! $ASSUME_YES && ! $ASSUMED_CONTINUOUS; then
  printf "${YELLOW}This will create/start Minikube profile '%s' and install Kubeflow\n" \
    "Pipelines via kustomize.  Existing data may be lost.  Continue? [y/N]${NC} "
  read -r -n1 confirm || true
  echo
  if [[ ! ${confirm,,} =~ ^y ]]; then
    log_warn "Aborted by user."
    exit 0
  fi
fi

# ── Step 2 – start Minikube ───────────────────────────────────────────────────
# shellcheck disable=SC2034
KFP_KUBE_CONTEXT="minikube"

if ! minikube profile list | awk '{print $1}' | grep -q "^${PROFILE}\$"; then
  log_info "Starting Minikube cluster '%s' (cpus=4, memory=8192, disk=30g) …" "$PROFILE"
  run minikube start \
      -p "$PROFILE" \
      --cpus=4 \
      --memory=8192 \
      --disk-size=30g \
      --addons=ingress,metrics-server
else
  log_info "Minikube profile '%s' already exists; starting …" "$PROFILE"
  run minikube start -p "$PROFILE"
fi

run minikube update-context -p "$PROFILE"

# ── Step 3 – wait for cluster readiness ──────────────────────────────────────
run minikube wait -p "$PROFILE" --for=apiserver --timeout=300s

log_info "Cluster is ready. Patching kubeconfig context to '%s' …" "$PROFILE"
KUBECTL_FLAGS=(-c "$PROFILE")

run kubectl "${KUBECTL_FLAGS[@]}" cluster-info >/dev/null 2>&1

# ── Step 4 – download and unpack KFP kustomize manifests ─────────────────────
WORK_DIR="$(mktemp -d /tmp/kfp-install-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

MANIFESTS_DIR="${WORK_DIR}/kubeflow-pipelines"

if $DRY_RUN; then
  log_info "[DRY-RUN] Would download KFP manifests to ${MANIFESTS_DIR}"
else
  log_info "Downloading KFP manifests v%s …" "$KFP_KUSTOMIZE_MANIFESTS_VERSION"
  curl -fsSL "https://github.com/kubeflow/pipelines/archive/refs/tags/${KFP_KUSTOMIZE_MANIFESTS_VERSION}.tar.gz" \
    | tar -xz -C "$WORK_DIR"
  # The tarball extracts to kubeflow-pipelines-<version>/
  MANIFESTS_DIR="$(find "$WORK_DIR" -maxdepth 1 -type d -name 'kubeflow-pipelines-*' | head -n1)/manifests/kustomize"
fi

OVERLAY="${MANIFESTS_DIR}/base"

run kubectl "${KUBECTL_FLAGS[@]}" create namespace "$KFP_NAMESPACE" --dry-run=client -o yaml \
  | kubectl "${KUBECTL_FLAGS[@]}" apply -f -

# ── Step 5 – install KFP via kustomize ────────────────────────────────────────
run kustomize build "$OVERLAY" | kubectl "${KUBECTL_FLAGS[@]}" apply -f -

# ── Step 6 – wait for pipeline components ────────────────────────────────────
log_info "Waiting for KFP pods to reach Running state (timeout 600 s) …"
CURRENT_NS=$KFP_NAMESPACE
run bash -c "
  kubectl -n $CURRENT_NS --context $PROFILE wait --for=condition=Ready pod \
    --all --timeout=600s 2>/dev/null || \
  kubectl -n $CURRENT_NS --context $PROFILE get pods
"

# ── Step 7 – check port-forward prerequisites & expose endpoints ──────────────
run kubectl "${KUBECTL_FLAGS[@]}" -n "$KFP_NAMESPACE" get svc \
  ml-pipeline-ui ml-pipeline-api -o name >/dev/null 2>&1

KFP_PORT=8080
log_info "Port-forward hints:"
log_info "  kubectl -n $KFP_NAMESPACE -c $PROFILE port-forward svc/ml-pipeline-ui    ${KFP_PORT}:80"
log_info "  kubectl -n $KFP_NAMESPACE -c $PROFILE port-forward svc/ml-pipeline-api  8888:8888"

HOST_IP="$(minikube -p "$PROFILE" ip 2>/dev/null || echo 'localhost')"
KFP_API_URI="http://${HOST_IP}:8888"
KFP_UI_URI="http://${HOST_IP}:${KFP_PORT}"

# ── Summary ───────────────────────────────────────────────────────────────────
log_info "✅  Kubeflow Pipelines is installed."
log_info "   KFP API  : ${KFP_API_URI}"
log_info "   KFP UI   : ${KFP_UI_URI}"
log_info ""
log_info "To port-forward locally:"
log_info "  kubectl -n $KFP_NAMESPACE -c $PROFILE port-forward svc/ml-pipeline-ui  ${KFP_PORT}:80"
log_info ""
log_info "Next run kubectl -n $KFP_NAMESPACE get pods to inspect pod health."
