"""
Unit tests for the Flask API
"""
import pytest

from app import app


@pytest.fixture
def client():
    """Create a test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health(client):
    """Test health endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'
    assert data['service'] == 'python-demo-app'

def test_greet(client):
    """Test greeting endpoint"""
    response = client.get('/api/greeting')
    assert response.status_code == 200
    data = response.get_json()
    assert data['message'] == 'Hello, Jenkins!'

def test_root(client):
    """Test root endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert data['service'] == 'python-demo-app'
    assert 'version' in data

def test_failing_health_check(client):
    """Intentional failing test - health should return unhealthy"""
    response = client.get('/health')
    data = response.get_json()
    assert data['status'] == 'unhealthy', "Health status should be unhealthy"

def test_failing_greeting_message(client):
    """Intentional failing test - greeting should be different"""
    response = client.get('/api/greeting')
    data = response.get_json()
    assert data['message'] == 'Goodbye, Jenkins!', "Greeting should say Goodbye"

def test_failing_root_service_name(client):
    """Intentional failing test - service name mismatch"""
    response = client.get('/')
    data = response.get_json()
    assert data['service'] == 'wrong-service-name', "Service name should be different"

def test_failing_status_code(client):
    """Intentional failing test - wrong status code"""
    response = client.get('/health')
    assert response.status_code == 404, "Health endpoint should return 404"

def test_failing_missing_field(client):
    """Intentional failing test - missing required field"""
    response = client.get('/')
    data = response.get_json()
    assert 'nonexistent_field' in data, "Response should have nonexistent_field"
