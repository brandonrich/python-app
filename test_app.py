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
    assert data['message'] == 'Hello, World!'

def test_root(client):
    """Test root endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert data['service'] == 'python-demo-app'
    assert 'version' in data
