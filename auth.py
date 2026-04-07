from datetime import date
from flask import Blueprint, request, session, redirect, render_template, jsonify
from werkzeug.security import check_password_hash
from database import get_user_by_username, check_and_register_device

auth_bp = Blueprint('auth', __name__)

def get_client_ip():
    # Render 等反向代理会把真实 IP 放在 X-Forwarded-For
    forwarded = request.headers.get('X-Forwarded-For')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.remote_addr

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if session.get('user_id'):
        return redirect('/')

    error = None
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        fingerprint = request.form.get('device_fingerprint', 'unknown')

        user = get_user_by_username(username)

        if not user or not check_password_hash(user['password_hash'], password):
            error = '用户名或密码错误'
        elif not user['is_active']:
            error = '账号已被禁用，请联系管理员'
        elif user['expires_at'] and date.today().isoformat() > user['expires_at']:
            error = '账号已过期，请联系管理员续期'
        elif fingerprint == 'unknown':
            error = '设备识别失败，请刷新页面后重试'
        else:
            ip = get_client_ip()
            allowed, reason = check_and_register_device(user['id'], ip, fingerprint, user['role'])
            if not allowed:
                error = reason
            else:
                session.clear()
                session['user_id'] = user['id']
                session['username'] = user['username']
                session['role'] = user['role']
                return redirect('/')

    return render_template('login.html', error=error)

@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect('/login')
