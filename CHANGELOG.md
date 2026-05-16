# MLOps-Kit — CHANGELOG

All notable changes to the MLOps-Kit repository are documented here.

---
# Changelog

## [Unreleased]

### Added

#### mlf-001 — MLflow Model Registry quick-start guide
- **Documentation:** `mlflow/docs/model-registry-quickstart.md`
- Provides a step-by-step guide to using the MLflow Model Registry for model versioning, staging, and promotion.
- Includes instructions for starting a tracking server, logging models, registering models, and transitioning between stages.

#### kub-002 — Kubeflow Pipelines bootstrap on Minikube
- **Script:** `kubeflow/scripts/bootstrap_kfp_on_minikube.sh`
- Provides a fully-interactive, single-command orchestration for standing up a
  local Kubeflow Pipelines 1.x deployment on Minikube.
- Features: Minikube profile lifecycle management, kustomize-based KFP
  manifest installation, port-forward helper hints, `--dry-run` support, and
  interactive pre-flight confirmation.  Validates `minikube`, `kubectl`, and
  `kustomize` binaries before execution.

#### wb-002 — W&B project and API key initialisation script
- **Script:** `weights-and-biases/scripts/wandb_bootstrap.sh`
- Wires up a W&B project end-to-end in one go: resolves entity and project name,
  silently writes a properly-formatted `.netrc` entry for the API key, verifies
  API connectivity, and optionally runs an offline `wandb.init` smoke-test.
- Supports `--yes` for CI/non-interactive use and `--key` for supplying the
  credential via CLI flag.  Validates `wandb` and `python3` availability up front.

#### Supporting infrastructure
- `00_index/quick-links.md` — centralised cross-reference table linking all
  tools, areas, and files in the kit.
- `CHANGELOG.md` — this file, tracking every task landing.
- bentoml/security/cve-2026-35043-analysis.md - Security analysis for BentoML command injection vulnerability

(End of file - total 42 lines)