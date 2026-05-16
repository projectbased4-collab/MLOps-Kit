# Installing MLflow and Running My First Command

I installed MLflow today. Here's what worked.

## Install

```bash
pip install mlflow
```

If you're using conda (which I am):
```bash
conda install -c conda-forge mlflow
```

## First Command

Ran the quick sanity check:
```bash
mlflow --version
```

Output: `mlflow, version 2.14.0`

## Tracking Server

Spin up a local tracking server to test:
```bash
mlflow server \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root ./mlruns
```

This starts the UI at http://127.0.0.1:5000

## What I'd Try Next

- Log a simple metric via the Python API
- Run the sklearn example from the docs

TODO: try logging params and metrics