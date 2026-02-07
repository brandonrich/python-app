# Python Demo Application

A simple Flask REST API for demonstrating CI/CD pipelines.

## Features

- Health check endpoint
- Simple greeting API
- Unit tests with pytest
- Docker support

## Endpoints

- `GET /` - Service information
- `GET /docs` - API documentation (Swagger UI)
- `GET /health` - Health check
- `GET /api/greeting` - Greeting endpoint

## Local Development

### Prerequisites

- Python 3.11 or higher
- pip

### Installation

```bash
pip install -r requirements.txt
```

### Running the Application

```bash
python app.py
```

The application will be available at `http://localhost:5000`

### Running Tests

```bash
pytest test_app.py -v
```

### Code Quality Checks

#### Linting

Run ruff to check for code style and potential issues:

```bash
ruff check .
```

To automatically fix issues:

```bash
ruff check --fix .
```

#### Security Scanning

Run bandit to check for common security issues:

```bash
bandit -r app.py
```

## Docker

### Build the Image

```bash
docker build -t python-demo-app:latest .
```

### Run the Container

```bash
docker run -p 5000:5000 python-demo-app:latest
```

## Testing the API

```bash
# Health check
curl http://localhost:5000/health

# Greeting
curl http://localhost:5000/api/greeting

# Service info
curl http://localhost:5000/
```
