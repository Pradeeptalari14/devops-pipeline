#!/usr/bin/env python3
"""Sample Flask application."""

from flask import Flask, jsonify
from datetime import datetime
import os

app = Flask(__name__)
time_started = datetime.utcnow()


@app.route('/')
def index():
    """Root endpoint."""
    return jsonify({
        'service': 'DevOps Pipeline Demo',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'uptime_seconds': (datetime.utcnow() - time_started).total_seconds()
    })


@app.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'checks': {
            'database': 'ok',
            'disk': 'ok',
            'memory': 'ok'
        }
    }), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
