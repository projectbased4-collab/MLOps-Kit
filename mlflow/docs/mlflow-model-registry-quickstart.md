# MLflow Model Registry Quick-Start Guide

## Purpose
This guide provides a quick-start for using the MLflow Model Registry to manage the lifecycle of machine learning models, including versioning, staging, and transitioning models between environments.

## When to Use
Use this guide when you need to:
- Track and manage multiple versions of ML models
- Implement model promotion workflows (e.g., staging to production)
- Maintain model lineage and metadata
- Collaborate on model development with team members

## Prerequisites
- MLflow installed (`pip install mlflow`)
- Access to an MLflow Tracking Server (local or remote)
- Basic understanding of MLflow concepts (experiments, runs, parameters, metrics)
- Python 3.7+ environment

## Steps

### 1. Start MLflow Tracking Server
```bash
# Start a local tracking server (for development)
mlflow server --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./artifacts --host 0.0.0.0 --port 5000
```

### 2. Set Tracking URI
```python
import mlflow
mlflow.set_tracking_uri("http://localhost:5000")
```

### 3. Create an Experiment
```python
experiment_id = mlflow.create_experiment("model-registry-demo")
mlflow.set_experiment(experiment_id)
```

### 4. Train and Log a Model
```python
import sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split

# Load data
data = load_iris()
X_train, X_test, y_train, y_test = train_test_split(data.data, data.target, test_size=0.2, random_state=42)

# Train model
with mlflow.start_run() as run:
    # Log parameters
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("max_depth", 5)
    
    # Train and evaluate model
    rf = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
    rf.fit(X_train, y_train)
    accuracy = rf.score(X_test, y_test)
    mlflow.log_metric("accuracy", accuracy)
    
    # Log model
    mlflow.sklearn.log_model(rf, "model")
    
    # Get the run ID
    run_id = run.info.run_id
```

### 5. Register the Model
```python
# Register the model in the MLflow Model Registry
model_uri = f"runs:/{run_id}/model"
mlflow.register_model(model_uri, "IrisClassifier")
```

### 6. Transition Model to Staging
```python
from mlflow.tracking import MlflowClient

client = MlflowClient()
client.transition_model_version_stage(
    name="IrisClassifier",
    version=1,  # Assuming this is version 1
    stage="Staging"
)
```

### 7. Transition Model to Production
```python
client.transition_model_version_stage(
    name="IrisClassifier",
    version=1,
    stage="Production",
    archive_existing_versions=True  # Archive existing production models
)
```

### 8. Load and Use the Model
```python
# Load the latest version in Production stage
model_uri = "models:/IrisClassifier/Production"
model = mlflow.sklearn.load_model(model_uri)

# Make predictions
predictions = model.predict(X_test)
```

## Verify
- Check the MLflow UI at `http://localhost:5000` to see the experiment, run, and registered model
- Verify model versions and stages in the Models section of the UI
- Test that the model loaded from production makes correct predictions

## Rollback
To rollback to a previous model version:
```python
# Archive current production model
client.transition_model_version_stage(
    name="IrisClassifier",
    version=current_version,
    stage="Archived"
)

# Promote previous version to production
client.transition_model_version_stage(
    name="IrisClassifier",
    version=previous_version,
    stage="Production"
)
```

## Common Errors
- **Error: "RESOURCE_ALREADY_EXISTS"** when registering a model: Use a unique model name or delete the existing registered model first
- **Error: "PERMISSION_DENIED"** when transitioning stages: Ensure you have appropriate permissions on the MLflow server
- **Error: "MODEL_VERSION_NOT_FOUND"** when loading a model: Verify the model name, version, and stage exist

## References
- [MLflow Model Registry Documentation](https://mlflow.org/docs/latest/model-registry.html)
- [MLflow Python API Reference](https://mlflow.org/docs/latest/python_api/index.html)
- [MLflow Tracking Server Setup](https://mlflow.org/docs/latest/tracking.html#running-the-tracking-server)