from flask import Blueprint, request, session, redirect, render_template, jsonify
from database import (
    get_all_users, create_user, delete_user,
    get_user_devices, clear_user_devices, update_user_notes, update_user_password,
    update_user_expiry, update_user_platform
)

admin_bp = Blueprint('admin', __name__)

def admin_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('role') != 'admin':
            return redirect('/')
        return f(*args, **kwargs)
    return decorated

@admin_bp.route('/admin')
@admin_required
def admin_panel():
    from datetime import date
    users = get_all_users()
    devices_map = {u['id']: get_user_devices(u['id']) for u in users}
    return render_template('admin.html', users=users, devices_map=devices_map,
                           current_user=session.get('username'),
                           today=date.today().isoformat())

@admin_bp.route('/admin/users/add', methods=['POST'])
@admin_required
def add_user():
    username = request.form.get('username', '').strip()
    password = request.form.get('password', '').strip()
    notes = request.form.get('notes', '').strip()
    expires_at = request.form.get('expires_at', '').strip() or None
    platform = request.form.get('platform', 'web').strip()
    if platform not in ('web', 'android'):
        platform = 'web'
    if not username or not password:
        users = get_all_users()
        return render_template('admin.html', users=users,
                               devices_map={u['id']: get_user_devices(u['id']) for u in users},
                               current_user=session.get('username'),
                               error='用户名和密码不能为空')
    ok, err = create_user(username, password, notes=notes, expires_at=expires_at, platform=platform)
    if not ok:
        users = get_all_users()
        return render_template('admin.html', users=users,
                               devices_map={u['id']: get_user_devices(u['id']) for u in users},
                               current_user=session.get('username'),
                               error=err)
    return redirect('/admin')

@admin_bp.route('/admin/users/delete/<int:user_id>', methods=['POST'])
@admin_required
def remove_user(user_id):
    delete_user(user_id)
    return redirect('/admin')

@admin_bp.route('/admin/users/clear-devices/<int:user_id>', methods=['POST'])
@admin_required
def clear_devices(user_id):
    clear_user_devices(user_id)
    return redirect('/admin')

@admin_bp.route('/admin/users/notes/<int:user_id>', methods=['POST'])
@admin_required
def update_notes(user_id):
    notes = request.json.get('notes', '')
    update_user_notes(user_id, notes)
    return jsonify({'ok': True})


@admin_bp.route('/admin/users/password/<int:user_id>', methods=['POST'])
@admin_required
def change_password(user_id):
    new_password = request.json.get('password', '').strip()
    if not new_password:
        return jsonify({'ok': False, 'error': '密码不能为空'})
    update_user_password(user_id, new_password)
    return jsonify({'ok': True})


@admin_bp.route('/admin/users/expiry/<int:user_id>', methods=['POST'])
@admin_required
def update_expiry(user_id):
    expires_at = request.json.get('expires_at', '').strip() or None
    update_user_expiry(user_id, expires_at)
    return jsonify({'ok': True})


@admin_bp.route('/admin/users/platform/<int:user_id>', methods=['POST'])
@admin_required
def change_platform(user_id):
    platform = request.json.get('platform', '').strip()
    if platform not in ('web', 'android'):
        return jsonify({'ok': False, 'error': '无效的平台值'})
    update_user_platform(user_id, platform)
    return jsonify({'ok': True})
