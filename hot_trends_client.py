import os
import time
import requests

# ── Option B: use self-hosted DailyHotApi on Vercel (optional) ───────────────
# If HOT_API_BASE_URL is set, proxy through it. Otherwise fall back to direct calls.
HOT_API_BASE = os.getenv('HOT_API_BASE_URL', '').rstrip('/')
CACHE_TTL = 1800  # 30 minutes

_cache = {}  # {platform: {'data': [...], 'ts': float}}

PLATFORMS = [
    {'key': 'weibo',        'label': '微博热搜'},
    {'key': 'bilibili',     'label': 'B站热榜'},
    {'key': 'douyin',       'label': '抖音热点'},
    {'key': 'kuaishou',     'label': '快手热榜'},
    {'key': 'baidu',        'label': '百度热搜'},
    {'key': 'zhihu',        'label': '知乎热榜'},
    {'key': 'toutiao',      'label': '今日头条'},
    {'key': 'thepaper',     'label': '澎湃新闻'},
    {'key': 'netease-news', 'label': '网易新闻'},
    {'key': 'qq-news',      'label': '腾讯新闻'},
    {'key': 'sina-news',    'label': '新浪新闻'},
    {'key': 'hupu',         'label': '虎扑'},
    {'key': 'douban-movie', 'label': '豆瓣电影'},
    {'key': 'acfun',        'label': 'AcFun'},
    {'key': '36kr',         'label': '36氪'},
    {'key': 'ithome',       'label': 'IT之家'},
    {'key': 'juejin',       'label': '掘金'},
    {'key': 'csdn',         'label': 'CSDN'},
    {'key': 'huxiu',        'label': '虎嗅'},
    {'key': 'tieba',        'label': '百度贴吧'},
    {'key': 'weread',       'label': '微信读书'},
    {'key': 'github',       'label': 'GitHub'},
    {'key': 'hackernews',   'label': 'Hacker News'},
    {'key': 'producthunt',  'label': 'Product Hunt'},
    {'key': 'v2ex',         'label': 'V2EX'},
    {'key': 'sspai',        'label': '少数派'},
    {'key': 'linuxdo',      'label': 'Linux.do'},
    {'key': 'ngabbs',       'label': 'NGA'},
]

_UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
       'AppleWebKit/537.36 (KHTML, like Gecko) '
       'Chrome/124.0.0.0 Safari/537.36')

# ── Direct fetchers (Plan B fallback) ────────────────────────────────────────

def _fetch_weibo():
    r = requests.get(
        'https://weibo.com/ajax/side/hotSearch',
        headers={'User-Agent': _UA, 'Referer': 'https://weibo.com/'},
        timeout=10,
    )
    r.raise_for_status()
    items = r.json().get('data', {}).get('realtime', [])
    return [
        {
            'title': (i.get('note') or i.get('word', '')).strip(),
            'hot': i.get('num', ''),
            'url': f'https://s.weibo.com/weibo?q={i.get("word", "")}&Refer=top',
        }
        for i in items if i.get('note') or i.get('word')
    ][:30]


def _fetch_bilibili():
    r = requests.get(
        'https://api.bilibili.com/x/web-interface/popular?ps=20&pn=1',
        headers={'User-Agent': _UA, 'Referer': 'https://www.bilibili.com/'},
        timeout=10,
    )
    r.raise_for_status()
    items = r.json().get('data', {}).get('list', [])
    return [
        {
            'title': i.get('title', ''),
            'hot': i.get('stat', {}).get('view', ''),
            'url': f'https://www.bilibili.com/video/{i.get("bvid", "")}' if i.get('bvid') else '',
        }
        for i in items if i.get('title')
    ][:30]


def _fetch_zhihu():
    r = requests.get(
        'https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total?limit=30',
        headers={
            'User-Agent': _UA,
            'x-api-version': '3.0.91',
            'Referer': 'https://www.zhihu.com/',
        },
        timeout=10,
    )
    r.raise_for_status()
    items = r.json().get('data', [])
    return [
        {'title': i.get('target', {}).get('title', ''), 'hot': i.get('detail_text', '')}
        for i in items if i.get('target', {}).get('title')
    ][:30]


def _fetch_baidu():
    r = requests.get(
        'https://top.baidu.com/api/board?tab=realtime',
        headers={'User-Agent': _UA, 'Referer': 'https://top.baidu.com/'},
        timeout=10,
    )
    r.raise_for_status()
    items = r.json().get('data', {}).get('cards', [{}])[0].get('content', [])
    return [
        {
            'title': i.get('word', ''),
            'hot': i.get('hotScore', ''),
            'url': f'https://www.baidu.com/s?wd={i.get("word", "")}',
        }
        for i in items if i.get('word')
    ][:30]


def _fetch_douyin():
    # 抖音热点无公开稳定 API，返回空列表并提示
    return []


_DIRECT_FETCHERS = {
    'weibo':    _fetch_weibo,
    'bilibili': _fetch_bilibili,
    'zhihu':    _fetch_zhihu,
    'baidu':    _fetch_baidu,
    'douyin':   _fetch_douyin,
}

# ── Public interface ──────────────────────────────────────────────────────────

def fetch_hot(platform: str):
    """Returns (data, ts, error). ts is unix timestamp of last successful fetch."""
    now = time.time()
    cached = _cache.get(platform)
    if cached and now - cached['ts'] < CACHE_TTL:
        return cached['data'], cached['ts'], None

    try:
        data = None
        api_error = None

        # Weibo: direct fetcher returns hot values (num field); proxy omits them.
        # Try direct first, fall through to proxy if it fails.
        if platform == 'weibo':
            try:
                data = _fetch_weibo()
                if not data:
                    data = None
            except Exception:
                data = None

        if data is None and HOT_API_BASE:
            # Proxy via DailyHotApi on Render/Vercel
            try:
                resp = requests.get(f'{HOT_API_BASE}/{platform}', timeout=20)
                resp.raise_for_status()
                data = resp.json().get('data', [])[:30]
            except Exception as e:
                # Render free tier cold-start timeout — fall through
                api_error = str(e)
                data = None

        if data is None:
            # Direct fetchers fallback
            fetcher = _DIRECT_FETCHERS.get(platform)
            if not fetcher:
                if HOT_API_BASE and api_error:
                    return [], None, f'获取失败，请稍候重试（服务冷启动中）'
                return [], None, '该平台热榜需配置 HOT_API_BASE_URL 才能使用'
            data = fetcher()

        if not data and platform == 'douyin':
            return [], None, '抖音热点暂无公开接口，请改用其他平台'

        _cache[platform] = {'data': data, 'ts': now}
        return data, now, None

    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else 0
        if status in (401, 403):
            msg = '该平台热榜需要账号授权，建议配置 HOT_API_BASE_URL 使用代理'
        else:
            msg = f'获取失败：{e}'
        if cached:
            return cached['data'], cached['ts'], f'使用缓存数据（{msg}）'
        return [], None, msg
    except Exception as e:
        if cached:
            return cached['data'], cached['ts'], f'使用缓存数据（{e}）'
        return [], None, f'获取失败：{e}'


def bust_cache(platform: str):
    """Force-expire cache for a platform so next fetch is fresh."""
    _cache.pop(platform, None)
