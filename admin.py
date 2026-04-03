from flask import Blueprint, request, session, redirect, render_template, jsonify
from database import (
    get_all_users, create_user, delete_user,
    get_user_devices, clear_user_devices, update_user_notes
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
    users = get_all_users()
    return render_template('admin.html', users=users, current_user=session.get('username'))

@admin_bp.route('/admin/users/add', methods=['POST'])
@admin_required
def add_user():
    username = request.form.get('username', '').strip()
    password = request.form.get('password', '').strip()
    notes = request.form.get('notes', '').strip()
    if not username or not password:
        users = get_all_users()
        return render_template('admin.html', users=users,
                               current_user=session.get('username'),
                               error='用户名和密码不能为空')
    ok, err = create_user(username, password, notes=notes)
    if not ok:
        users = get_all_users()
        return render_template('admin.html', users=users,
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
