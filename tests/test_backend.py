"""
Comprehensive backend tests for 短视频创作助手.

Tech stack:
  - Backend: Python 3 / Flask 3
  - DB: SQLite (in-memory via env override)
  - Auth: Session-based (web) + JWT (mobile)

Run:
  python -m pytest tests/test_backend.py -v
"""

import os
import json
import tempfile
import pytest

# ── Point DB at a temp file so tests never touch users.db ────────────────────
_tmp_db = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
_tmp_db.close()
os.environ['DB_PATH'] = _tmp_db.name
os.environ['JWT_SECRET'] = 'test-secret'
os.environ['SECRET_KEY'] = 'test-flask-secret'
os.environ['ALLOW_PLAY_SUBSCRIPTION_DEV_BYPASS'] = 'true'
# Clear any SOCKS proxy that would break the httpx client
for _k in ('http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'all_proxy'):
    os.environ.pop(_k, None)

# Mock deepseek_client before importing app (avoids real AI calls & proxy issues)
from unittest.mock import MagicMock, patch
import sys

_mock_dc = MagicMock()
_mock_dc.generate_stream = MagicMock(return_value=iter(['mocked response']))
_mock_dc.generate_text = MagicMock(return_value='mocked text')
sys.modules['deepseek_client'] = _mock_dc

# Also mock search_client and hot_trends_client to avoid network calls
_mock_sc = MagicMock()
_mock_sc.search_bilibili = MagicMock(return_value=([], None))
_mock_sc.search_youtube = MagicMock(return_value=([], None))
_mock_sc.search_weixin_video = MagicMock(return_value=([], None))
_mock_sc.search_xiaohongshu = MagicMock(return_value=([], None))
_mock_sc.search_douyin = MagicMock(return_value=([], None))
_mock_sc.fetch_video_from_url = MagicMock(return_value=(None, 'mocked'))
_mock_sc.fetch_video_content = MagicMock(return_value='')
sys.modules['search_client'] = _mock_sc

_mock_ht = MagicMock()
_mock_ht.fetch_hot = MagicMock(return_value=([], '2026-01-01', None))
_mock_ht.bust_cache = MagicMock()
_mock_ht.PLATFORMS = ['weibo', 'bilibili', 'douyin', 'zhihu', 'baidu', 'toutiao']
sys.modules['hot_trends_client'] = _mock_ht

# Import app AFTER mocks and env vars are set
from app import app as flask_app
from database import (
    init_db, create_user, get_user_by_username,
    check_and_increment_quota, check_and_register_device,
    update_user_subscription, DAILY_LIMITS,
)
from mobile_auth import create_mobile_token, decode_mobile_token


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope='session', autouse=True)
def init_database():
    """Initialise the temp database once per test session."""
    init_db()


@pytest.fixture(scope='session')
def client():
    flask_app.config['TESTING'] = True
    flask_app.config['SECRET_KEY'] = 'test-flask-secret'
    with flask_app.test_client() as c:
        yield c


@pytest.fixture(scope='session')
def admin_session(client):
    """Return a test client already logged in as the default admin."""
    client.post('/login', data={'username': 'admin', 'password': 'admin123'})
    return client


@pytest.fixture(scope='session')
def regular_user():
    """Create a regular (free-tier) user once and return their info."""
    create_user('testuser', 'pass1234', role='user')
    user = get_user_by_username('testuser')
    return user


@pytest.fixture(scope='session')
def jwt_token(regular_user):
    """Valid JWT for the regular user."""
    return create_mobile_token(regular_user['id'], regular_user['username'], regular_user['role'])


@pytest.fixture(scope='session')
def admin_jwt():
    """Valid JWT for the admin user."""
    admin = get_user_by_username('admin')
    return create_mobile_token(admin['id'], admin['username'], admin['role'])


# ─────────────────────────────────────────────────────────────────────────────
# 1. Tech-stack smoke test
# ─────────────────────────────────────────────────────────────────────────────

class TestTechStack:
    def test_flask_app_starts(self, client):
        resp = client.get('/ping')
        assert resp.status_code == 200
        assert resp.data == b'ok'

    def test_jwt_library_works(self):
        import jwt
        token = jwt.encode({'sub': 'test'}, 'secret', algorithm='HS256')
        decoded = jwt.decode(token, 'secret', algorithms=['HS256'])
        assert decoded['sub'] == 'test'

    def test_sqlite_available(self):
        import sqlite3
        con = sqlite3.connect(':memory:')
        cur = con.execute('SELECT 1')
        assert cur.fetchone()[0] == 1
        con.close()


# ─────────────────────────────────────────────────────────────────────────────
# 2. Database layer
# ─────────────────────────────────────────────────────────────────────────────

class TestDatabase:
    def test_init_creates_admin(self):
        admin = get_user_by_username('admin')
        assert admin is not None
        assert admin['role'] == 'admin'

    def test_create_user_success(self):
        ok, err = create_user('dbuser1', 'pw', role='user')
        assert ok is True
        assert err is None

    def test_create_user_duplicate(self):
        create_user('dupuser', 'pw')
        ok, err = create_user('dupuser', 'pw')
        assert ok is False
        assert '已存在' in err

    def test_create_user_with_expiry(self):
        ok, err = create_user('expiryuser', 'pw', expires_at='2099-12-31')
        assert ok is True
        u = get_user_by_username('expiryuser')
        assert u['expires_at'] == '2099-12-31'

    def test_quota_admin_always_allowed(self):
        admin = get_user_by_username('admin')
        allowed, msg = check_and_increment_quota(admin['id'], 'admin')
        assert allowed is True
        assert msg is None

    def test_quota_free_user_limit(self):
        create_user('quotauser', 'pw', role='user')
        u = get_user_by_username('quotauser')
        limit = DAILY_LIMITS['free']  # 3
        for _ in range(limit):
            allowed, _ = check_and_increment_quota(u['id'], 'user')
            assert allowed is True
        # Next call should be denied
        allowed, msg = check_and_increment_quota(u['id'], 'user')
        assert allowed is False
        assert '上限' in msg

    def test_device_registration_first_device(self):
        create_user('devuser1', 'pw')
        u = get_user_by_username('devuser1')
        ok, reason = check_and_register_device(u['id'], '127.0.0.1', 'device-aaa')
        assert ok is True

    def test_device_registration_max_devices(self):
        create_user('devuser2', 'pw')
        u = get_user_by_username('devuser2')
        check_and_register_device(u['id'], '127.0.0.1', 'dev-1')
        check_and_register_device(u['id'], '127.0.0.1', 'dev-2')
        check_and_register_device(u['id'], '127.0.0.1', 'dev-3')
        ok, reason = check_and_register_device(u['id'], '127.0.0.1', 'dev-4')
        assert ok is False
        assert '3 台' in reason

    def test_admin_device_limit_not_enforced(self):
        admin = get_user_by_username('admin')
        for i in range(5):
            ok, _ = check_and_register_device(admin['id'], '127.0.0.1', f'admin-dev-x{i}', role='admin')
            assert ok is True

    def test_update_user_subscription(self):
        create_user('subuser', 'pw')
        u = get_user_by_username('subuser')
        update_user_subscription(u['id'], 'pro', 'tok_abc', 'creator_pro_monthly', '2099-12-31')
        from database import get_user_by_id
        updated = get_user_by_id(u['id'])
        assert updated['subscription_tier'] == 'pro'
        assert updated['expires_at'] == '2099-12-31'


# ─────────────────────────────────────────────────────────────────────────────
# 3. JWT / mobile_auth
# ─────────────────────────────────────────────────────────────────────────────

class TestMobileAuth:
    def test_create_and_decode_token(self):
        token = create_mobile_token(1, 'alice', 'user')
        payload = decode_mobile_token(token)
        assert payload['user_id'] == 1
        assert payload['username'] == 'alice'
        assert payload['role'] == 'user'

    def test_expired_token_raises(self):
        import jwt
        from datetime import datetime, timezone, timedelta
        payload = {
            'user_id': 1,
            'username': 'alice',
            'role': 'user',
            'exp': datetime.now(timezone.utc) - timedelta(seconds=1),
            'iat': datetime.now(timezone.utc) - timedelta(hours=1),
        }
        token = jwt.encode(payload, os.environ['JWT_SECRET'], algorithm='HS256')
        with pytest.raises(jwt.ExpiredSignatureError):
            decode_mobile_token(token)

    def test_invalid_token_raises(self):
        import jwt
        with pytest.raises(jwt.InvalidTokenError):
            decode_mobile_token('not.a.valid.token')

    def test_tampered_token_raises(self):
        import jwt
        token = create_mobile_token(1, 'alice', 'user')
        tampered = token[:-5] + 'XXXXX'
        with pytest.raises(jwt.InvalidTokenError):
            decode_mobile_token(tampered)


# ─────────────────────────────────────────────────────────────────────────────
# 4. Mobile API — /api/mobile/*
# ─────────────────────────────────────────────────────────────────────────────

class TestMobileLogin:
    def _post(self, client, payload):
        return client.post(
            '/api/mobile/login',
            data=json.dumps(payload),
            content_type='application/json',
        )

    def test_login_success(self, client):
        resp = self._post(client, {
            'username': 'admin',
            'password': 'admin123',
            'device_id': 'test-device-001',
        })
        assert resp.status_code == 200
        body = resp.get_json()
        assert 'token' in body
        assert 'user' in body
        assert body['user']['username'] == 'admin'

    def test_login_wrong_password(self, client):
        resp = self._post(client, {
            'username': 'admin',
            'password': 'wrongpass',
            'device_id': 'test-device-001',
        })
        assert resp.status_code == 401
        assert '密码' in resp.get_json()['error']

    def test_login_missing_username(self, client):
        resp = self._post(client, {'password': 'pw', 'device_id': 'dev'})
        assert resp.status_code == 400

    def test_login_missing_device_id(self, client):
        resp = self._post(client, {'username': 'admin', 'password': 'admin123'})
        assert resp.status_code == 400

    def test_login_unknown_device_id(self, client):
        """device_id='unknown' should be rejected."""
        resp = self._post(client, {
            'username': 'admin',
            'password': 'admin123',
            'device_id': 'unknown',
        })
        assert resp.status_code == 400

    def test_login_inactive_user(self, client):
        create_user('inactiveuser', 'pw')
        from database import get_db
        conn = get_db()
        conn.execute("UPDATE users SET is_active=0 WHERE username='inactiveuser'")
        conn.commit()
        conn.close()
        resp = self._post(client, {
            'username': 'inactiveuser',
            'password': 'pw',
            'device_id': 'dev-xyz',
        })
        assert resp.status_code == 403
        assert '禁用' in resp.get_json()['error']

    def test_login_expired_account(self, client):
        create_user('expireduser', 'pw', expires_at='2000-01-01')
        resp = self._post(client, {
            'username': 'expireduser',
            'password': 'pw',
            'device_id': 'dev-exp',
        })
        assert resp.status_code == 403
        assert '过期' in resp.get_json()['error']

    def test_login_returns_correct_tier_info(self, client):
        create_user('tieruser', 'pw')
        u = get_user_by_username('tieruser')
        update_user_subscription(u['id'], 'pro', 'tok', 'creator_pro_monthly', '2099-12-31')
        resp = self._post(client, {
            'username': 'tieruser',
            'password': 'pw',
            'device_id': 'dev-tier',
        })
        assert resp.status_code == 200
        user_data = resp.get_json()['user']
        assert user_data['subscription_tier'] == 'pro'
        assert user_data['daily_limit'] == 30


class TestMobileMe:
    def test_me_with_valid_token(self, client, jwt_token):
        resp = client.get(
            '/api/mobile/me',
            headers={'Authorization': f'Bearer {jwt_token}'},
        )
        assert resp.status_code == 200
        assert 'user' in resp.get_json()

    def test_me_without_token(self, client):
        resp = client.get('/api/mobile/me')
        assert resp.status_code == 401

    def test_me_with_bad_token(self, client):
        resp = client.get(
            '/api/mobile/me',
            headers={'Authorization': 'Bearer invalid.token.here'},
        )
        assert resp.status_code == 401


class TestMobileLogout:
    def test_logout_success(self, client, admin_jwt):
        resp = client.post(
            '/api/mobile/logout',
            data=json.dumps({'device_id': 'some-device'}),
            content_type='application/json',
            headers={'Authorization': f'Bearer {admin_jwt}'},
        )
        assert resp.status_code == 200
        assert resp.get_json()['ok'] is True

    def test_logout_without_auth(self, client):
        resp = client.post('/api/mobile/logout')
        assert resp.status_code == 401


class TestMobileVerifySubscription:
    def test_verify_unknown_product(self, client, admin_jwt):
        resp = client.post(
            '/api/mobile/verify-subscription',
            data=json.dumps({'purchase_token': 'tok', 'product_id': 'unknown_product'}),
            content_type='application/json',
            headers={'Authorization': f'Bearer {admin_jwt}'},
        )
        assert resp.status_code == 400
        assert '未知' in resp.get_json()['error']

    def test_verify_missing_fields(self, client, admin_jwt):
        resp = client.post(
            '/api/mobile/verify-subscription',
            data=json.dumps({}),
            content_type='application/json',
            headers={'Authorization': f'Bearer {admin_jwt}'},
        )
        assert resp.status_code == 400
        assert '缺少' in resp.get_json()['error']

    def test_verify_dev_mode_pro(self, client, jwt_token):
        """In explicit dev bypass mode any token should be accepted."""
        resp = client.post(
            '/api/mobile/verify-subscription',
            data=json.dumps({
                'purchase_token': 'any_token_dev',
                'product_id': 'creator_pro_monthly',
            }),
            content_type='application/json',
            headers={'Authorization': f'Bearer {jwt_token}'},
        )
        assert resp.status_code == 200
        body = resp.get_json()
        assert body['valid'] is True
        assert body['tier'] == 'pro'

    def test_verify_dev_mode_pro_plus(self, client, jwt_token):
        resp = client.post(
            '/api/mobile/verify-subscription',
            data=json.dumps({
                'purchase_token': 'any_token_dev',
                'product_id': 'creator_pro_plus_monthly',
            }),
            content_type='application/json',
            headers={'Authorization': f'Bearer {jwt_token}'},
        )
        assert resp.status_code == 200
        assert resp.get_json()['tier'] == 'pro_plus'

    def test_verify_missing_play_config_without_bypass(self, client, jwt_token, monkeypatch):
        monkeypatch.delenv('GOOGLE_PLAY_PACKAGE_NAME', raising=False)
        monkeypatch.delenv('GOOGLE_SERVICE_ACCOUNT_JSON', raising=False)
        monkeypatch.delenv('ALLOW_PLAY_SUBSCRIPTION_DEV_BYPASS', raising=False)
        resp = client.post(
            '/api/mobile/verify-subscription',
            data=json.dumps({
                'purchase_token': 'prod_like_token',
                'product_id': 'creator_pro_monthly',
            }),
            content_type='application/json',
            headers={'Authorization': f'Bearer {jwt_token}'},
        )
        assert resp.status_code == 502
        assert 'GOOGLE_PLAY_PACKAGE_NAME' in resp.get_json()['error']
        assert 'GOOGLE_SERVICE_ACCOUNT_JSON' in resp.get_json()['error']


# ─────────────────────────────────────────────────────────────────────────────
# 5. API routes — input validation (no real AI calls)
# ─────────────────────────────────────────────────────────────────────────────

class TestApiInputValidation:
    """
    All AI endpoints require an authenticated session.
    We inject auth via the Bearer token mechanism that app.py's before_request
    hook supports (sets session from JWT).
    """

    def _auth_headers(self, admin_jwt):
        return {'Authorization': f'Bearer {admin_jwt}'}

    def _post(self, client, path, body, admin_jwt):
        return client.post(
            path,
            data=json.dumps(body),
            content_type='application/json',
            headers=self._auth_headers(admin_jwt),
        )

    def test_script_missing_topic(self, client, admin_jwt):
        resp = self._post(client, '/api/script', {}, admin_jwt)
        assert resp.status_code == 400
        assert '主题' in resp.get_json()['error']

    def test_shot_table_missing_script(self, client, admin_jwt):
        resp = self._post(client, '/api/shot-table', {}, admin_jwt)
        assert resp.status_code == 400

    def test_positioning_missing_industry(self, client, admin_jwt):
        resp = self._post(client, '/api/positioning', {'strengths': 'good'}, admin_jwt)
        assert resp.status_code == 400

    def test_positioning_missing_strengths(self, client, admin_jwt):
        resp = self._post(client, '/api/positioning', {'industry': 'tech'}, admin_jwt)
        assert resp.status_code == 400

    def test_viral_topics_missing_industry(self, client, admin_jwt):
        resp = self._post(client, '/api/topics/viral', {}, admin_jwt)
        assert resp.status_code == 400

    def test_monetize_topics_missing_industry(self, client, admin_jwt):
        resp = self._post(client, '/api/topics/monetize', {}, admin_jwt)
        assert resp.status_code == 400

    def test_rewrite_missing_original(self, client, admin_jwt):
        resp = self._post(client, '/api/rewrite', {}, admin_jwt)
        assert resp.status_code == 400

    def test_breakdown_missing_title(self, client, admin_jwt):
        resp = self._post(client, '/api/breakdown', {}, admin_jwt)
        assert resp.status_code == 400

    def test_imitate_missing_ref_title(self, client, admin_jwt):
        resp = self._post(client, '/api/imitate', {'my_topic': 'test'}, admin_jwt)
        assert resp.status_code == 400

    def test_imitate_missing_my_topic(self, client, admin_jwt):
        resp = self._post(client, '/api/imitate', {'ref_title': 'test'}, admin_jwt)
        assert resp.status_code == 400

    def test_search_viral_missing_topic(self, client, admin_jwt):
        resp = self._post(client, '/api/search-viral', {}, admin_jwt)
        assert resp.status_code == 400

    def test_breakdown_sharetext_missing_sharetext(self, client, admin_jwt):
        resp = self._post(client, '/api/breakdown-sharetext', {}, admin_jwt)
        assert resp.status_code == 400

    def test_fetch_url_missing_url(self, client, admin_jwt):
        resp = self._post(client, '/api/fetch-url', {}, admin_jwt)
        assert resp.status_code == 400

    def test_director_missing_topic(self, client, admin_jwt):
        resp = self._post(client, '/api/director', {'scene': 'outdoor'}, admin_jwt)
        assert resp.status_code == 400

    def test_director_missing_scene(self, client, admin_jwt):
        resp = self._post(client, '/api/director', {'topic': 'cooking'}, admin_jwt)
        assert resp.status_code == 400

    def test_content_plan_missing_industry(self, client, admin_jwt):
        resp = self._post(client, '/api/content-plan', {'platform': 'douyin'}, admin_jwt)
        assert resp.status_code == 400

    def test_content_plan_missing_platform(self, client, admin_jwt):
        resp = self._post(client, '/api/content-plan', {'industry': 'fitness'}, admin_jwt)
        assert resp.status_code == 400


# ─────────────────────────────────────────────────────────────────────────────
# 6. Hot trends — admin-only
# ─────────────────────────────────────────────────────────────────────────────

class TestHotTrends:
    def test_hot_trends_requires_admin(self, client, jwt_token):
        """Non-admin JWT should be denied."""
        resp = client.get(
            '/api/hot-trends',
            headers={'Authorization': f'Bearer {jwt_token}'},
        )
        assert resp.status_code == 403

    def test_hot_trends_admin_can_access(self, client, admin_jwt):
        resp = client.get(
            '/api/hot-trends?platform=weibo',
            headers={'Authorization': f'Bearer {admin_jwt}'},
        )
        # 200 even if scraping fails (returns error field but still 200)
        assert resp.status_code == 200
        body = resp.get_json()
        assert 'platforms' in body


# ─────────────────────────────────────────────────────────────────────────────
# 7. Auth — session-based web login
# ─────────────────────────────────────────────────────────────────────────────

class TestWebLogin:
    def test_login_page_accessible(self):
        # Use a fresh client — shared client may already have a session
        with flask_app.test_client() as fresh:
            resp = fresh.get('/login')
            assert resp.status_code == 200

    def test_login_wrong_credentials(self):
        # Use a fresh client — shared client may already have a session
        with flask_app.test_client() as fresh:
            # Web login requires device_fingerprint; omitting it gives "设备识别失败"
            resp = fresh.post('/login', data={
                'username': 'admin',
                'password': 'wrong',
                'device_fingerprint': 'test-fp',
            })
            assert resp.status_code == 200  # stays on login page with error

    def test_login_redirects_to_home(self, client):
        resp = client.post(
            '/login',
            data={'username': 'admin', 'password': 'admin123'},
            follow_redirects=False,
        )
        assert resp.status_code in (302, 303)

    def test_unauthenticated_access_redirects_to_login(self):
        # Fresh client with no session
        with flask_app.test_client() as fresh:
            resp = fresh.get('/', follow_redirects=False)
            assert resp.status_code == 302
            assert '/login' in resp.headers.get('Location', '')


# ─────────────────────────────────────────────────────────────────────────────
# 8. Quota enforcement via mobile JWT
# ─────────────────────────────────────────────────────────────────────────────

class TestQuotaEnforcement:
    def test_free_user_quota_exhaustion_returns_429(self, client):
        """
        Create a fresh free user, exhaust their daily quota by manipulating
        the DB directly, then confirm the next API call returns 429.
        """
        create_user('quotafreeuser', 'pw', role='user')
        u = get_user_by_username('quotafreeuser')
        token = create_mobile_token(u['id'], u['username'], u['role'])

        from database import get_db
        from datetime import date
        today = date.today().isoformat()
        conn = get_db()
        conn.execute(
            "UPDATE users SET daily_usage_count=3, daily_usage_date=? WHERE id=?",
            (today, u['id']),
        )
        conn.commit()
        conn.close()

        resp = client.post(
            '/api/script',
            data=json.dumps({'topic': 'cats'}),
            content_type='application/json',
            headers={'Authorization': f'Bearer {token}'},
        )
        assert resp.status_code == 429
        body = resp.get_json()
        assert '上限' in body['error']


# ─────────────────────────────────────────────────────────────────────────────
# 9. Edge cases & security
# ─────────────────────────────────────────────────────────────────────────────

class TestEdgeCases:
    def test_api_without_auth_is_rejected(self, client):
        with flask_app.test_client() as fresh:
            resp = fresh.post(
                '/api/script',
                data=json.dumps({'topic': 'cats'}),
                content_type='application/json',
            )
            # Should redirect to /login (302) or return 401
            assert resp.status_code in (302, 401)

    def test_mobile_login_sql_injection_attempt(self, client):
        resp = client.post(
            '/api/mobile/login',
            data=json.dumps({
                'username': "admin'--",
                'password': 'anything',
                'device_id': 'dev-inject',
            }),
            content_type='application/json',
        )
        # Should return 401 (no such user), not 200 or 500
        assert resp.status_code == 401

    def test_very_long_username_rejected_gracefully(self, client):
        long_name = 'a' * 5000
        resp = client.post(
            '/api/mobile/login',
            data=json.dumps({
                'username': long_name,
                'password': 'pw',
                'device_id': 'dev-long',
            }),
            content_type='application/json',
        )
        assert resp.status_code in (400, 401)

    def test_ping_always_200(self, client):
        resp = client.get('/ping')
        assert resp.status_code == 200

    def test_unknown_route_404(self, client):
        resp = client.get('/this-does-not-exist')
        assert resp.status_code in (302, 404)

    def test_duplicate_device_registration_updates_timestamp(self):
        create_user('dupdevuser', 'pw')
        u = get_user_by_username('dupdevuser')
        ok1, _ = check_and_register_device(u['id'], '1.1.1.1', 'dup-dev')
        ok2, msg = check_and_register_device(u['id'], '2.2.2.2', 'dup-dev')
        assert ok1 is True
        assert ok2 is True  # same device, should update last_seen

    def test_daily_quota_resets_next_day(self):
        """If daily_usage_date is yesterday, counter should reset to 0."""
        create_user('resetquotauser', 'pw', role='user')
        u = get_user_by_username('resetquotauser')

        from database import get_db
        conn = get_db()
        conn.execute(
            "UPDATE users SET daily_usage_count=3, daily_usage_date='2000-01-01' WHERE id=?",
            (u['id'],),
        )
        conn.commit()
        conn.close()

        # Should be allowed since the date is old
        allowed, _ = check_and_increment_quota(u['id'], 'user')
        assert allowed is True

    def test_nonexistent_user_quota_returns_false(self):
        allowed, msg = check_and_increment_quota(999999, 'user')
        assert allowed is False
        assert '不存在' in msg
