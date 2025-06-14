from flask import Flask, session, jsonify
from flask_session import Session # pip install flask-session
import redis
import os
import socket

app = Flask(__name__)

# Configure Redis for session storage
app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_REDIS'] = redis.Redis(
    host='redis',
    port=6379,
    db=0
)
Session(app)

@app.route('/')
def index():
    if 'visits' not in session:
        session['visits'] = 0
    session['visits'] += 1
    
    return jsonify({
        'message': f'Hello from {socket.gethostname()}!',
        'visits': session['visits'],
        'session_id': session.sid
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 