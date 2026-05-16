#!/usr/bin/env bash
#
# MLflow Tracking Server Launcher
#
# Purpose: Launches an MLflow Tracking server locally with sensible defaults.
#
# When to use: Use this script to quickly start an MLflow Tracking server for
#              development or testing purposes.
#
# Prerequisites: MLflow must be installed (`pip install mlflow`).
#
# Steps:
#   1. Validate that required binaries are available.
#   2. Parse command-line arguments for customization.
#   3. Start the MLflow Tracking server with the specified configuration.
#
# Verify: Check that the server is running by accessing the UI at http://localhost:5000.
#
# Common errors:
#   - MLflow not installed: Install with `pip install mlflow`.
#   - Port already in use: Use a different port with --port or MLFLOW_SERVER_PORT.
#
# References:
#   - https://mlflow.org/docs/latest/tracking.html#running-the-tracking-server

set -euo pipefail

# Default values
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="5000"
DEFAULT_BACKEND_STORE_URI="sqlite:///mlflow.db"
DEFAULT_ARTIFACT_ROOT="./mlruns"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --backend-store-uri)
      BACKEND_STORE_URI="$2"
      shift 2
      ;;
    --artifact-root)
      ARTIFACT_ROOT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--host HOST] [--port PORT] [--backend-store-uri URI] [--artifact-root PATH]"
      echo "  --host                  Host to bind to (default: $DEFAULT_HOST)"
      echo "  --port                  Port to bind to (default: $DEFAULT_PORT)"
      echo "  --backend-store-uri     Backend store URI (default: $DEFAULT_BACKEND_STORE_URI)"
      echo "  --artifact-root         Artifact root directory (default: $DEFAULT_ARTIFACT_ROOT)"
      echo "  --help                  Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set defaults if not provided
HOST="${HOST:-$DEFAULT_HOST}"
PORT="${PORT:-$DEFAULT_PORT}"
BACKEND_STORE_URI="${BACKEND_STORE_URI:-$DEFAULT_BACKEND_STORE_URI}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$DEFAULT_ARTIFACT_ROOT}"

# Validate required binaries
if ! command -v mlflow &> /dev/null; then
  echo "Error: mlflow command not found. Please install MLflow with: pip install mlflow"
  exit 1
fi

# Create directories if they don't exist
mkdir -p "$(dirname "$BACKEND_STORE_URI")"
mkdir -p "$ARTIFACT_ROOT"

# Dry-run/preview mode
if [[ "${DRY_RUN:-}" == "true" ]]; then
  echo "DRY RUN: Would start MLflow Tracking server with:"
  echo "  Host: $HOST"
  echo "  Port: $PORT"
  echo "  Backend store URI: $BACKEND_STORE_URI"
  echo "  Artifact root: $ARTIFACT_ROOT"
  echo "Command: mlflow server --host $HOST --port $PORT --backend-store-uri $BACKEND_STORE_URI --default-artifact-root $ARTIFACT_ROOT"
  exit 0
fi

# Start the MLflow Tracking server
echo "Starting MLflow Tracking server..."
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Backend store URI: $BACKEND_STORE_URI"
echo "  Artifact root: $ARTIFACT_ROOT"
echo "UI will be available at: http://$HOST:$PORT"
echo "Press Ctrl+C to stop the server."

exec mlflow server \
  --host "$HOST" \
  --port "$PORT" \
  --backend-store-uri "$BACKEND_STORE_URI" \
  --default-artifact-root "$ARTIFACT_ROOT"