import sqlite3
import os
from werkzeug.security import generate_password_hash

DB_PATH = os.getenv('DB_PATH', os.path.join(os.path.dirname(__file__), 'users.db'))

def get_db():
    os.makedirs(os.path.dirname(os.path.abspath(DB_PATH)), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            plain_password TEXT DEFAULT '',
            role TEXT NOT NULL DEFAULT 'user',
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS user_devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            ip_address TEXT,
            device_fingerprint TEXT NOT NULL,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
    """)
    # 兼容旧库：尝试添加 plain_password 列（已存在则忽略）
    try:
        conn.execute("ALTER TABLE users ADD COLUMN plain_password TEXT DEFAULT ''")
        conn.commit()
    except Exception:
        pass

    # 创建默认管理员账号（如果不存在）
    existing = conn.execute("SELECT id FROM users WHERE username = 'admin'").fetchone()
    if not existing:
        conn.execute(
            "INSERT INTO users (username, password_hash, plain_password, role, notes) VALUES (?, ?, ?, 'admin', '默认管理员')",
            ('admin', generate_password_hash('admin123', method='pbkdf2:sha256'), 'admin123')
        )
    conn.commit()
    conn.close()

def get_user_by_username(username):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    conn.close()
    return user

def get_user_by_id(user_id):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return user

def get_all_users():
    conn = get_db()
    users = conn.execute("""
        SELECT u.*, COUNT(d.id) as device_count
        FROM users u
        LEFT JOIN user_devices d ON u.id = d.user_id
        GROUP BY u.id
        ORDER BY u.created_at DESC
    """).fetchall()
    conn.close()
    return users

def create_user(username, password, role='user', notes=''):
    conn = get_db()
    try:
        conn.execute(
            "INSERT INTO users (username, password_hash, plain_password, role, notes) VALUES (?, ?, ?, ?, ?)",
            (username, generate_password_hash(password, method='pbkdf2:sha256'), password, role, notes)
        )
        conn.commit()
        return True, None
    except sqlite3.IntegrityError:
        return False, '用户名已存在'
    finally:
        conn.close()

def delete_user(user_id):
    conn = get_db()
    conn.execute("DELETE FROM users WHERE id = ? AND role != 'admin'", (user_id,))
    conn.commit()
    conn.close()

def update_user_notes(user_id, notes):
    conn = get_db()
    conn.execute("UPDATE users SET notes = ? WHERE id = ?", (notes, user_id))
    conn.commit()
    conn.close()

def get_user_devices(user_id):
    conn = get_db()
    devices = conn.execute(
        "SELECT * FROM user_devices WHERE user_id = ? ORDER BY last_seen DESC",
        (user_id,)
    ).fetchall()
    conn.close()
    return devices

def clear_user_devices(user_id):
    conn = get_db()
    conn.execute("DELETE FROM user_devices WHERE user_id = ?", (user_id,))
    conn.commit()
    conn.close()

def check_and_register_device(user_id, ip, fingerprint, role='user'):
    conn = get_db()
    devices = conn.execute(
        "SELECT device_fingerprint FROM user_devices WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    fingerprints = [d['device_fingerprint'] for d in devices]

    if fingerprint in fingerprints:
        conn.execute(
            "UPDATE user_devices SET last_seen = CURRENT_TIMESTAMP, ip_address = ? WHERE user_id = ? AND device_fingerprint = ?",
            (ip, user_id, fingerprint)
        )
        conn.commit()
        conn.close()
        return True, 'ok'

    if role != 'admin' and len(fingerprints) >= 3:
        conn.close()
        return False, '该账号已在 3 台设备上登录，请联系管理员解绑设备后再试'

    conn.execute(
        "INSERT INTO user_devices (user_id, ip_address, device_fingerprint) VALUES (?, ?, ?)",
        (user_id, ip, fingerprint)
    )
    conn.commit()
    conn.close()
    return True, 'ok'


def update_user_password(user_id, new_password):
    conn = get_db()
    conn.execute(
        "UPDATE users SET password_hash = ?, plain_password = ? WHERE id = ?",
        (generate_password_hash(new_password, method='pbkdf2:sha256'), new_password, user_id)
    )
    conn.commit()
    conn.close()
