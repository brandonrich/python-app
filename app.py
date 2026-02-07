"""
Simple Flask API for CI/CD demonstration
"""
from flask import Flask, jsonify, send_from_directory
from flask_swagger_ui import get_swaggerui_blueprint

app = Flask(__name__)

# Swagger UI configuration
SWAGGER_URL = '/docs'
API_URL = '/openapi.yaml'

swaggerui_blueprint = get_swaggerui_blueprint(
    SWAGGER_URL,
    API_URL,
    config={
        'app_name': "Python Demo App API"
    }
)

app.register_blueprint(swaggerui_blueprint, url_prefix=SWAGGER_URL)

@app.route('/openapi.yaml')
def serve_openapi_spec():
    """Serve the OpenAPI specification"""
    return send_from_directory('.', 'openapi.yaml')

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "python-demo-app"})

@app.route('/api/greeting')
def get_greeting():
    """Greeting endpoint"""
    return jsonify({"message": "Hello, World!"})

@app.route('/')
def root():
    """Root endpoint"""
    return jsonify({
        "service": "python-demo-app",
        "version": "1.0.0",
        "documentation": "/docs",
        "endpoints": ["/health", "/api/greeting"]
    })

if __name__ == '__main__':
    # Bind to 0.0.0.0 for Docker container access
    app.run(host='0.0.0.0', port=5000)
