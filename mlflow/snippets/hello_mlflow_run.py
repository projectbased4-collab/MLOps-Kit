# Hey-world MLflow Run - End to End

```python
import mlflow
import mlflow.sklearn
from sklearn.linear_model import LogisticRegression
from sklearn.datasets import load_iris

# Set experiment
mlflow.set_experiment("hello-world")

with mlflow.start_run():
    # Load data
    X, y = load_iris(return_X_y=True)
    
    # Train model
    model = LogisticRegression(max_iter=200)
    model.fit(X, y)
    
    # Log params
    mlflow.log_param("model_type", "LogisticRegression")
    mlflow.log_param("max_iter", 200)
    
    # Log metric
    accuracy = model.score(X, y)
    mlflow.log_metric("accuracy", accuracy)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
    
    print(f"Run complete! Accuracy: {accuracy:.2f}")
```

Run it:
```bash
python hello_mlflow.py
```

Check the UI at http://127.0.0.1:5000