import os
import jwt
from datetime import datetime, timedelta, timezone
from functools import wraps
from flask import request, jsonify, g

SECRET = os.getenv('JWT_SECRET', 'dev-jwt-secret-change-in-production')
ACCESS_TOKEN_TTL_HOURS = 24 * 7  # 7 days


def create_mobile_token(user_id: int, username: str, role: str) -> str:
    payload = {
        'user_id': user_id,
        'username': username,
        'role': role,
        'exp': datetime.now(timezone.utc) + timedelta(hours=ACCESS_TOKEN_TTL_HOURS),
        'iat': datetime.now(timezone.utc),
    }
    return jwt.encode(payload, SECRET, algorithm='HS256')


def decode_mobile_token(token: str) -> dict:
    return jwt.decode(token, SECRET, algorithms=['HS256'])


def get_bearer_token() -> str | None:
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return auth[7:]
    return None


def mobile_auth_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = get_bearer_token()
        if not token:
            return jsonify({'error': '未登录，请提供认证令牌'}), 401
        try:
            payload = decode_mobile_token(token)
            g.user_id = payload['user_id']
            g.username = payload['username']
            g.role = payload['role']
        except jwt.ExpiredSignatureError:
            return jsonify({'error': '登录已过期，请重新登录'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': '无效的认证令牌'}), 401
        return f(*args, **kwargs)
    return decorated
