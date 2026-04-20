"""
Mobile API Blueprint — /api/mobile/*
JWT-based auth endpoints for the Flutter Android app.
Web routes and admin panel are completely unaffected.
"""
import os
from datetime import date, datetime, timedelta, timezone
from flask import Blueprint, request, jsonify, g
from werkzeug.security import check_password_hash

from database import (
    get_user_by_username, get_user_by_id,
    check_and_register_device, clear_user_devices,
    update_user_subscription, DAILY_LIMITS,
)
from mobile_auth import create_mobile_token, mobile_auth_required

mobile_bp = Blueprint('mobile', __name__, url_prefix='/api/mobile')

PRODUCT_TO_TIER = {
    'creator_pro_monthly': 'pro',
    'creator_pro_plus_monthly': 'pro_plus',
}


def _play_package_name():
    return os.getenv('GOOGLE_PLAY_PACKAGE_NAME', '').strip()


def _play_service_account_json():
    return os.getenv('GOOGLE_SERVICE_ACCOUNT_JSON', '').strip()


def _allow_play_dev_bypass():
    return os.getenv('ALLOW_PLAY_SUBSCRIPTION_DEV_BYPASS', '').strip().lower() in {
        '1', 'true', 'yes'
    }


def _get_client_ip():
    forwarded = request.headers.get('X-Forwarded-For')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.remote_addr


def _user_dict(user):
    tier = user['subscription_tier'] or 'free'
    return {
        'id': user['id'],
        'username': user['username'],
        'role': user['role'],
        'subscription_tier': tier,
        'daily_limit': DAILY_LIMITS.get(tier, 3),
        'expires_at': user['expires_at'],
        'created_at': str(user['created_at'] or '')[:10],
    }


# ─── POST /api/mobile/login ──────────────────────────────────────────────────

@mobile_bp.route('/login', methods=['POST'])
def mobile_login():
    data = request.get_json(silent=True) or {}
    username = data.get('username', '').strip()
    password = data.get('password', '')
    device_id = data.get('device_id', 'unknown').strip()

    if not username or not password:
        return jsonify({'error': '请输入用户名和密码'}), 400
    if not device_id or device_id == 'unknown':
        return jsonify({'error': '设备识别失败，请重试'}), 400

    user = get_user_by_username(username)
    if not user or not check_password_hash(user['password_hash'], password):
        return jsonify({'error': '用户名或密码错误'}), 401
    if not user['is_active']:
        return jsonify({'error': '账号已被禁用，请联系管理员'}), 403
    if user['expires_at'] and date.today().isoformat() > user['expires_at']:
        return jsonify({'error': '账号已过期，请联系管理员续期或订阅'}), 403

    ip = _get_client_ip()
    allowed, reason = check_and_register_device(user['id'], ip, device_id, user['role'])
    if not allowed:
        return jsonify({'error': reason}), 403

    token = create_mobile_token(user['id'], user['username'], user['role'])
    return jsonify({
        'token': token,
        'user': _user_dict(user),
    })


# ─── GET /api/mobile/me ──────────────────────────────────────────────────────

@mobile_bp.route('/me', methods=['GET'])
@mobile_auth_required
def mobile_me():
    user = get_user_by_id(g.user_id)
    if not user or not user['is_active']:
        return jsonify({'error': '账号不存在或已被禁用'}), 403
    return jsonify({'user': _user_dict(user)})


# ─── POST /api/mobile/logout ─────────────────────────────────────────────────

@mobile_bp.route('/logout', methods=['POST'])
@mobile_auth_required
def mobile_logout():
    data = request.get_json(silent=True) or {}
    device_id = data.get('device_id', '')
    if device_id:
        # Remove only this device so other devices stay logged in
        from database import get_db
        conn = get_db()
        conn.execute(
            "DELETE FROM user_devices WHERE user_id = ? AND device_fingerprint = ?",
            (g.user_id, device_id)
        )
        conn.commit()
        conn.close()
    return jsonify({'ok': True})


# ─── POST /api/mobile/verify-subscription ────────────────────────────────────

@mobile_bp.route('/verify-subscription', methods=['POST'])
@mobile_auth_required
def mobile_verify_subscription():
    data = request.get_json(silent=True) or {}
    purchase_token = data.get('purchase_token', '').strip()
    product_id = data.get('product_id', '').strip()

    if not purchase_token or not product_id:
        return jsonify({'error': '缺少订阅凭证'}), 400

    tier = PRODUCT_TO_TIER.get(product_id)
    if not tier:
        return jsonify({'error': f'未知的订阅产品: {product_id}'}), 400

    # Verify with Google Play Developer API
    try:
        is_valid, expires_at = _verify_play_subscription(purchase_token, product_id)
    except Exception as e:
        return jsonify({'error': f'订阅验证失败: {e}'}), 502

    if not is_valid:
        return jsonify({'error': '订阅未生效或已取消', 'valid': False}), 402

    update_user_subscription(g.user_id, tier, purchase_token, product_id, expires_at)
    return jsonify({'valid': True, 'expires_at': expires_at, 'tier': tier})


def _verify_play_subscription(purchase_token: str, product_id: str):
    """Call Google Play Developer API to verify a subscription purchase."""
    package_name = _play_package_name()
    service_account_json = _play_service_account_json()
    if not service_account_json or not package_name:
        if _allow_play_dev_bypass():
            expires = (datetime.now(timezone.utc) + timedelta(days=30)).date().isoformat()
            return True, expires
        missing = []
        if not package_name:
            missing.append('GOOGLE_PLAY_PACKAGE_NAME')
        if not service_account_json:
            missing.append('GOOGLE_SERVICE_ACCOUNT_JSON')
        raise RuntimeError(
            'Google Play subscription verification is not configured. '
            f'Missing env vars: {", ".join(missing)}. '
            'Set ALLOW_PLAY_SUBSCRIPTION_DEV_BYPASS=true only for local development.'
        )

    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_file(
        service_account_json,
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    service = build('androidpublisher', 'v3', credentials=creds, cache_discovery=False)
    result = service.purchases().subscriptions().get(
        packageName=package_name,
        subscriptionId=product_id,
        token=purchase_token,
    ).execute()

    expiry_ms = int(result.get('expiryTimeMillis', 0))
    expires_at = datetime.fromtimestamp(expiry_ms / 1000, timezone.utc).date().isoformat()
    payment_state = result.get('paymentState')
    is_valid = payment_state in (1, 2)  # 1=paid, 2=free trial
    return is_valid, expires_at
