#!/usr/bin/env python3
"""
MLflow Logging Snippet

Purpose: Demonstrates how to log parameters, metrics, and artifacts to MLflow.

When to use: Use this snippet as a starting point for integrating MLflow tracking
             into your machine learning experiments.

Prerequisites:
   - MLflow installed (`pip install mlflow`)
   - An MLflow Tracking server running (see `start_mlflow_server.sh` script)
   - Python 3.7+

Steps:
   1. Set the tracking URI to point to your MLflow server.
   2. Create or set an experiment.
   3. Start a run.
   4. Log parameters (key-value pairs).
   5. Log metrics (key-value pairs, can be logged throughout the run).
   6. Log artifacts (files, directories, or MLflow models).
   7. End the run.

Verify: Check the MLflow UI to see the logged parameters, metrics, and artifacts.

Common errors:
   - Tracking URI not set: Ensure you call `mlflow.set_tracking_uri()` or set the
     MLFLOW_TRACKING_URI environment variable.
   - Experiment does not exist: Use `mlflow.create_experiment()` or
     `mlflow.set_experiment()` with an existing experiment ID or name.
   - Artifact logging fails: Ensure the artifact path is valid and you have
     write permissions.

References:
   - https://mlflow.org/docs/latest/python_api/mlflow.html
   - https://mlflow.org/docs/latest/tracking.html
"""

import os
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Set tracking URI (modify as needed)
# For a local tracking server started with the provided script:
mlflow.set_tracking_uri("http://localhost:5000")

# Alternatively, you can set the MLFLOW_TRACKING_URI environment variable:
# os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"

# Create an experiment
experiment_name = "logging-demo"
try:
    experiment_id = mlflow.create_experiment(experiment_name)
except mlflow.exceptions.MlflowException:
    experiment_id = mlflow.get_experiment_by_name(experiment_name).experiment_id

mlflow.set_experiment(experiment_id)

# Start a run
with mlflow.start_run(run_name="random-forest-iris") as run:
    # Log parameters
    mlflow.log_param("model_type", "RandomForestClassifier")
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("max_depth", 5)
    mlflow.log_param("random_state", 42)

    # Load and prepare data
    data = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        data.data, data.target, test_size=0.2, random_state=42
    )

    # Train model
    rf = RandomForestClassifier(
        n_estimators=100, max_depth=5, random_state=42
    )
    rf.fit(X_train, y_train)

    # Log metrics
    train_acc = rf.score(X_train, y_train)
    test_acc = rf.score(X_test, y_test)
    mlflow.log_metric("train_accuracy", train_acc)
    mlflow.log_metric("test_accuracy", test_acc)

    # Log the model
    mlflow.sklearn.log_model(rf, "random-forest-model")

    # Log an artifact (e.g., a file with feature importances)
    import pandas as pd
    feature_importances = pd.DataFrame(
        rf.feature_importances_,
        index=data.feature_names,
        columns=["importance"]
    )
    feature_importances_path = "feature_importances.csv"
    feature_importances.to_csv(feature_importances_path)
    mlflow.log_artifact(feature_importances_path)

    # Optionally, clean up the temporary artifact file
    os.remove(feature_importances_path)

    # Print the run ID for reference
    print(f"Run ID: {run.info.run_id}")
    print(f"Experiment ID: {experiment_id}")