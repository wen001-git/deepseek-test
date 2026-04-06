import os
import re
import time
import tempfile
import requests
from dotenv import load_dotenv
try:
    from youtube_transcript_api import YouTubeTranscriptApi
    _YT_TRANSCRIPT_AVAILABLE = True
except ImportError:
    _YT_TRANSCRIPT_AVAILABLE = False

try:
    from faster_whisper import WhisperModel
    _WHISPER_AVAILABLE = True
except ImportError:
    _WHISPER_AVAILABLE = False

_whisper_model = None  # lazy-loaded on first use

def _get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        _whisper_model = WhisperModel("base", device="cpu", compute_type="int8")
    return _whisper_model

load_dotenv()

BILIBILI_SEARCH_URL = "https://api.bilibili.com/x/web-interface/search/type"
BILIBILI_VIEW_URL   = "https://api.bilibili.com/x/web-interface/view"
BILIBILI_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://www.bilibili.com",
}

YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
YOUTUBE_STATS_URL  = "https://www.googleapis.com/youtube/v3/videos"

_yt_cache: dict = {}   # keyword -> (results, error, timestamp)
YT_CACHE_TTL = 3600    # 1 hour

TRANSCRIPT_MAX_CHARS = 2000


def _fetch_yt_transcript(vid: str):
    """Fetch YouTube transcript. Returns joined text string or None."""
    if not _YT_TRANSCRIPT_AVAILABLE:
        return None
    try:
        segs = YouTubeTranscriptApi.get_transcript(
            vid, languages=['zh-Hans', 'zh-Hant', 'zh', 'en']
        )
        text = " ".join(s['text'] for s in segs)
        return text[:TRANSCRIPT_MAX_CHARS]
    except Exception:
        return None


# ── 通用工具 ──────────────────────────────────────────────────────────────────

def _fmt_play(n) -> str:
    try:
        n = int(n)
    except (TypeError, ValueError):
        return "—"
    if n >= 100_000_000:
        approx = f"{n / 100_000_000:.2f}亿"
        return f"{n:,}（{approx}）"
    if n >= 10_000:
        approx = f"{n / 10_000:.2f}万"
        return f"{n:,}（{approx}）"
    return str(n)


def _strip_html(text: str) -> str:
    return re.sub(r"<[^>]+>", "", text)


def _detect_platform(url: str) -> str:
    if "bilibili.com" in url or "b23.tv" in url:
        return "B站"
    if "youtube.com" in url or "youtu.be" in url:
        return "YouTube"
    if "douyin.com" in url or "iesdouyin.com" in url:
        return "抖音"
    if "xiaohongshu" in url or "xhslink" in url:
        return "小红书"
    if "weixin.qq.com" in url or "channels.weixin" in url:
        return "视频号"
    return "其他"


def _extract_bvid(url: str):
    m = re.search(r"BV[\w]+", url)
    return m.group(0) if m else None


def _extract_youtube_id(url: str):
    m = re.search(r"(?:v=|youtu\.be/|shorts/)([A-Za-z0-9_-]{11})", url)
    return m.group(1) if m else None


JINA_MAX_CHARS = 3000

try:
    import yt_dlp
    _YTDLP_AVAILABLE = True
except ImportError:
    _YTDLP_AVAILABLE = False

try:
    from ddgs import DDGS
    _DDGS_AVAILABLE = True
except ImportError:
    _DDGS_AVAILABLE = False


def fetch_via_ytdlp(url: str) -> 'str | None':
    """Extract video metadata via yt-dlp. Works for Douyin, YouTube, etc."""
    if not _YTDLP_AVAILABLE:
        return None
    try:
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'skip_download': True,
            'extract_flat': False,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                return None
            title = info.get('title') or ''
            desc  = info.get('description') or ''
            tags  = info.get('tags') or []
            uploader = info.get('uploader') or ''
            view_count = info.get('view_count')
            like_count = info.get('like_count')

            parts = []
            if title:
                parts.append(f"标题：{title}")
            if tags:
                parts.append(f"话题标签：{'  '.join('#' + t for t in tags[:10])}")
            if desc and desc != title:
                parts.append(f"文案内容：{desc[:1500]}")
            if uploader:
                parts.append(f"发布者：{uploader}")
            stats = []
            if view_count:
                stats.append(f"播放 {_fmt_play(view_count)}")
            if like_count:
                stats.append(f"点赞 {_fmt_play(like_count)}")
            if stats:
                parts.append(f"视频数据：{'  |  '.join(stats)}")
            return '\n'.join(parts) if parts else None
    except Exception as e:
        print(f"[fetch_via_ytdlp] error: {e}")
        return None


def fetch_via_jina(url: str) -> 'str | None':
    """Fetch page content via Jina AI Reader (r.jina.ai). Returns text or None on failure."""
    try:
        resp = requests.get(
            f"https://r.jina.ai/{url}",
            headers={"Accept": "text/plain", "X-No-Cache": "true"},
            timeout=10,
        )
        if resp.status_code == 200 and resp.text.strip():
            return resp.text[:JINA_MAX_CHARS]
    except Exception:
        pass
    return None


def fetch_via_whisper(url: str) -> 'str | None':
    """Download audio via yt-dlp and transcribe with Whisper. Returns transcript or None."""
    if not _YTDLP_AVAILABLE or not _WHISPER_AVAILABLE:
        return None
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path = os.path.join(tmpdir, 'audio.%(ext)s')
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'format': 'bestaudio/best',
                'outtmpl': audio_path,
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '64',
                }],
                'socket_timeout': 15,
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)

            mp3_path = os.path.join(tmpdir, 'audio.mp3')
            if not os.path.exists(mp3_path):
                return None

            model = _get_whisper_model()
            segments, _ = model.transcribe(mp3_path, language='zh', beam_size=1)
            transcript = ' '.join(seg.text.strip() for seg in segments)
            return transcript[:3000] if transcript.strip() else None
    except Exception as e:
        print(f"[fetch_via_whisper] error: {e}")
        return None


DOUYIN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                  "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "Referer": "https://www.douyin.com/",
}


def _resolve_douyin_url(url: str) -> 'str | None':
    """Follow redirects from a Douyin short URL to get the canonical video URL."""
    try:
        resp = requests.head(url, headers=DOUYIN_HEADERS, allow_redirects=True, timeout=8)
        return resp.url
    except Exception:
        return None


def fetch_douyin_info(url: str) -> 'str | None':
    """Fetch Douyin video info by scraping iesdouyin share page. Returns formatted text or None."""
    # Resolve short URL → iesdouyin share URL containing the video ID
    canonical = _resolve_douyin_url(url) if 'v.douyin.com' in url else url
    if not canonical:
        return None
    m = re.search(r'/video/(\d+)', canonical) or re.search(r'(\d{15,})', canonical)
    if not m:
        return None
    video_id = m.group(1)

    try:
        resp = requests.get(
            f'https://www.iesdouyin.com/share/video/{video_id}/',
            headers=DOUYIN_HEADERS,
            timeout=10,
        )
        html = resp.text

        def _scrape(pattern):
            hit = re.search(pattern, html)
            return hit.group(1) if hit else ''

        desc     = _scrape(r'"desc":"(.*?)"(?:,|\})')
        author   = _scrape(r'"nickname":"(.*?)"')
        likes    = _scrape(r'"digg_count":(\d+)')
        comments = _scrape(r'"comment_count":(\d+)')
        shares   = _scrape(r'"share_count":(\d+)')
        collects = _scrape(r'"collect_count":(\d+)')

        if not desc and not author:
            return None

        parts = []
        if desc:
            parts.append(f"视频文案：{desc}")
        if author:
            parts.append(f"发布者：{author}")
        stat_parts = []
        if likes:    stat_parts.append(f"点赞 {_fmt_play(likes)}")
        if comments: stat_parts.append(f"评论 {_fmt_play(comments)}")
        if collects: stat_parts.append(f"收藏 {_fmt_play(collects)}")
        if shares:   stat_parts.append(f"分享 {_fmt_play(shares)}")
        if stat_parts:
            parts.append(f"视频数据：{'  |  '.join(stat_parts)}")

        print(f"[fetch_douyin_info] got info for video {video_id}")
        return '\n'.join(parts)
    except Exception as e:
        print(f"[fetch_douyin_info] error: {e}")
    return None


def _extract_search_query(sharetext: str) -> str:
    """Extract a clean search query from Douyin share text."""
    text = sharetext
    # Remove URL
    text = re.sub(r'https?://\S+', '', text)
    # Remove trailing copy-prompt instruction
    text = re.sub(r'复制此链接.*$', '', text, flags=re.DOTALL)
    # Strip leading ASCII noise (share codes like "9.92 11/17 a@N.WZ uSY:/")
    # by keeping only from the first CJK character onward
    m = re.search(r'[\u4e00-\u9fff]', text)
    text = text[m.start():] if m else text
    return text.strip()


_ARTICLE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                  "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "Accept-Language": "zh-CN,zh;q=0.9",
}
# Domains known to return readable article text
_ARTICLE_DOMAINS = (
    'sohu.com', 'sina.com', 'sina.cn', 'cj.sina', '36kr.com',
    'zhihu.com', 'baidu.com', 'toutiao.com', 'ifeng.com',
    'thepaper.cn', 'weixin.qq.com', 'qq.com', 'guancha.cn',
    'wenxuecity.com', 'zaobao.com',
)


def _fetch_article_text(url: str, keywords: list = None, max_chars: int = 1500) -> 'str | None':
    """Fetch article text from whitelisted domains, extract paragraphs containing keywords."""
    if not any(d in url for d in _ARTICLE_DOMAINS):
        return None
    try:
        resp = requests.get(url, headers=_ARTICLE_HEADERS, timeout=8, allow_redirects=True)
        if resp.status_code != 200:
            return None
        # Strip scripts/styles/tags
        html = re.sub(r'<(?:script|style)[^>]*>.*?</(?:script|style)>', '', resp.text,
                      flags=re.DOTALL | re.IGNORECASE)
        text = re.sub(r'<[^>]+>', ' ', html)
        text = re.sub(r'[ \t]+', ' ', text)
        # Split into non-empty lines and find the richest paragraphs
        lines = [l.strip() for l in text.splitlines() if len(l.strip()) > 30]
        if not lines:
            return None
        # Prefer lines that contain any keyword
        if keywords:
            scored = [(sum(k in l for k in keywords), l) for l in lines]
            scored.sort(key=lambda x: -x[0])
            best = [l for _, l in scored if _ > 0][:8]
            if not best:
                best = lines[:6]
        else:
            best = lines[:8]
        result = ' '.join(best)
        return result[:max_chars] if len(result) > 50 else None
    except Exception:
        return None


def fetch_via_search(sharetext: str) -> 'str | None':
    """Search DuckDuckGo with two queries, fetch full article text from top results."""
    if not _DDGS_AVAILABLE:
        return None
    query = _extract_search_query(sharetext)
    if not query:
        return None

    # Extract short title (first clause before hashtags)
    short_title = re.split(r'#|\s{2,}', query)[0].strip()
    article_query = short_title + ' 视频 文案 解说'

    all_results = []
    try:
        with DDGS() as ddgs:
            r1 = list(ddgs.text(query, max_results=4, region='cn-zh'))
            r2 = list(ddgs.text(article_query, max_results=4, region='cn-zh'))
            # Deduplicate by URL
            seen = set()
            for r in r1 + r2:
                u = r.get('href', '')
                if u and u not in seen:
                    seen.add(u)
                    all_results.append(r)
    except Exception as e:
        print(f"[fetch_via_search] DDG error: {e}")
        return None

    keywords = [w for w in short_title.split() if len(w) > 1][:6]
    parts = []
    for r in all_results[:6]:
        title = r.get('title', '')
        url   = r.get('href', '')
        body  = r.get('body', '')
        full = _fetch_article_text(url, keywords=keywords) if url else None
        if full:
            parts.append(f"[{title}]\n{full}")
        elif body:
            parts.append(f"[{title}]\n{body}")
        if len(parts) >= 4:
            break

    if not parts:
        return None
    print(f"[fetch_via_search] {len(parts)} results for: {query[:60]}")
    return '\n\n'.join(parts)[:4000]


def fetch_video_content(url: str, sharetext: str = '') -> 'str | None':
    """Try Douyin API, yt-dlp metadata, Whisper, search engine, then Jina as fallback."""
    # 0. Douyin-specific: try unofficial API for real video metadata
    if 'douyin.com' in url or 'iesdouyin.com' in url:
        douyin_info = fetch_douyin_info(url)
        if douyin_info:
            # Also append search snippets for extra context
            search_extra = fetch_via_search(sharetext) if sharetext else None
            if search_extra:
                return douyin_info + '\n\n【网络相关资讯】\n' + search_extra[:1000]
            return douyin_info

    # 1. Try yt-dlp metadata (title, description, hashtags)
    metadata = fetch_via_ytdlp(url)

    # 2. Try Whisper transcription for actual spoken content
    transcript = fetch_via_whisper(url)

    if not metadata and not transcript:
        # 3. Try search engine — find web coverage of this video
        if sharetext:
            search_result = fetch_via_search(sharetext)
            if search_result:
                return search_result
        return fetch_via_jina(url)

    parts = []
    if metadata:
        parts.append(metadata)
    if transcript:
        parts.append(f"\n视频语音文案（Whisper转录）：\n{transcript}")
    return '\n'.join(parts) if parts else None


# ── B站关键词搜索 ─────────────────────────────────────────────────────────────

def search_bilibili(topic: str) -> tuple:
    """Returns (list[{title,url,snippet,platform,source}], error_str|None)"""
    params = {
        "search_type": "video",
        "keyword":     topic,
        "order":       "click",
        "page":        1,
    }
    try:
        resp = requests.get(BILIBILI_SEARCH_URL, params=params,
                            headers=BILIBILI_HEADERS, timeout=8)
        resp.raise_for_status()
        data = resp.json()
        if data.get("code") != 0:
            return [], "B站搜索暂时不可用，请稍后重试"

        results = []
        for item in data.get("data", {}).get("result", [])[:5]:
            title  = _strip_html(item.get("title", "（无标题）"))
            bvid   = item.get("bvid", "")
            play   = _fmt_play(item.get("play", 0))
            author = item.get("author", "")
            results.append({
                "title":    title,
                "url":      f"https://www.bilibili.com/video/{bvid}" if bvid else "",
                "snippet":  f"▶ {play} 播放  ·  UP: {author}",
                "platform": "B站",
                "source":   "real",
            })

        if not results:
            return [], "未找到相关视频，请换个关键词试试"
        return results, None

    except requests.Timeout:
        return [], "B站搜索超时，请稍后重试"
    except Exception as e:
        return [], f"B站搜索失败：{e}"


# ── YouTube 关键词搜索 ────────────────────────────────────────────────────────

def search_youtube(topic: str) -> tuple:
    """Returns (list[{title,url,snippet,platform,source}], error_str|None)"""
    api_key = os.getenv("YOUTUBE_API_KEY")
    if not api_key:
        return [], None  # 未配置时静默跳过

    # 命中缓存直接返回，节省 API 配额
    cached = _yt_cache.get(topic)
    if cached and time.time() - cached[2] < YT_CACHE_TTL:
        return cached[0], cached[1]

    try:
        resp = requests.get(YOUTUBE_SEARCH_URL, params={
            "part":             "snippet",
            "q":                topic,
            "type":             "video",
            "maxResults":       6,
            "relevanceLanguage":"zh",
            "key":              api_key,
        }, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if "error" in data:
            return [], f"YouTube API 错误：{data['error'].get('message', '')}"
        items = data.get("items", [])
        if not items:
            return [], None
    except requests.Timeout:
        return [], "YouTube 搜索超时"
    except Exception as e:
        return [], f"YouTube 搜索失败：{e}"

    # 获取播放量
    video_ids = [i["id"]["videoId"] for i in items]
    stats = {}
    try:
        sr = requests.get(YOUTUBE_STATS_URL, params={
            "part": "statistics",
            "id":   ",".join(video_ids),
            "key":  api_key,
        }, timeout=8)
        for v in sr.json().get("items", []):
            stats[v["id"]] = v.get("statistics", {})
    except Exception:
        pass

    results = []
    for item in items[:5]:
        vid  = item["id"]["videoId"]
        s    = item["snippet"]
        play = _fmt_play(stats.get(vid, {}).get("viewCount", ""))
        results.append({
            "title":    s.get("title", "（无标题）"),
            "url":      f"https://www.youtube.com/watch?v={vid}",
            "snippet":  f"▶ {play} 播放  ·  {s.get('channelTitle', '')}",
            "platform": "YouTube",
            "source":   "real",
        })
    _yt_cache[topic] = (results, None, time.time())
    return results, None


# ── 微信视频号搜索（搜狗） ────────────────────────────────────────────────────

SOGOU_WEIXIN_URL = 'https://weixin.sogou.com/weixin'
SOGOU_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Referer': 'https://weixin.sogou.com/',
}


def search_weixin_video(topic: str) -> tuple:
    """Search WeChat 视频号 content.
    Strategy 1: Sogou WeChat search with robust GBK decoding + broad XPath
    Strategy 2: DuckDuckGo '{topic} 视频号' filtered for WeChat-related results
    Returns (list[{title,url,snippet,platform,source}], error_str|None)"""

    # ── Strategy 1: Sogou WeChat search ──────────────────────────────────────
    try:
        from lxml import html as lxml_html
        resp = requests.get(
            SOGOU_WEIXIN_URL,
            params={'query': topic, 'type': '2', 'ie': 'utf8'},
            headers=SOGOU_HEADERS,
            timeout=10,
        )
        if resp.status_code == 200 and 'antispider' not in resp.url:
            # Sogou is GBK/GB2312 — decode explicitly
            text = None
            for enc in ('gb2312', 'gbk', 'utf-8'):
                try:
                    text = resp.content.decode(enc)
                    break
                except UnicodeDecodeError:
                    continue
            if text is None:
                text = resp.content.decode('utf-8', errors='replace')

            tree = lxml_html.fromstring(text)

            results = []
            # Try class-based selectors first
            items = (tree.xpath('//ul[contains(@class,"news-box")]/li') or
                     tree.xpath('//li[contains(@class,"news-item")]') or
                     tree.xpath('//div[contains(@class,"news-item")]'))

            if items:
                for item in items[:5]:
                    a_els = item.xpath('.//h3//a | .//h4//a')
                    if not a_els:
                        continue
                    title = _strip_html(a_els[0].text_content()).strip()
                    href  = a_els[0].get('href', '')
                    if not title or not href:
                        continue
                    if href.startswith('/'):
                        href = 'https://weixin.sogou.com' + href
                    snippets = item.xpath('.//*[contains(@class,"txt")]//text()')
                    snippet  = re.sub(r'\s+', ' ', ' '.join(snippets)).strip()[:120]

                    # Account name — try several common Sogou class patterns
                    account = ''
                    for axp in ('.//*[contains(@class,"account")]//text()',
                                './/*[contains(@class,"s-p")]//text()',
                                './/*[contains(@class,"author")]//text()'):
                        els = item.xpath(axp)
                        if els:
                            account = els[0].strip()
                            break

                    # Date — try common time/date class patterns
                    date = ''
                    for dxp in ('.//*[contains(@class,"time")]//text()',
                                './/span[contains(@class,"date")]//text()',
                                './/p[contains(@class,"s-p2")]//text()'):
                        els = item.xpath(dxp)
                        if els:
                            date = els[0].strip()
                            break

                    # Build display like B站's "UP: author · date"
                    meta_parts = []
                    if account:
                        meta_parts.append(f"公号: {account}")
                    if date:
                        meta_parts.append(date)
                    if meta_parts:
                        display = '  ·  '.join(meta_parts)
                        if snippet and not account:
                            display += f"  {snippet[:60]}"
                    else:
                        display = snippet[:80]

                    results.append({'title': title, 'url': href, 'snippet': display,
                                     'platform': '视频号', 'source': 'real'})
            else:
                # Broad fallback: all h3 > a links on the page
                for a in tree.xpath('//h3//a[@href]')[:5]:
                    title = _strip_html(a.text_content()).strip()
                    href  = a.get('href', '')
                    if not title or not href:
                        continue
                    if href.startswith('/'):
                        href = 'https://weixin.sogou.com' + href
                    results.append({'title': title, 'url': href, 'snippet': '',
                                     'platform': '视频号', 'source': 'real'})

            if results:
                return results, None
    except Exception:
        pass

    # ── Strategy 2: DuckDuckGo — broad query filtered for WeChat relevance ────
    # Note: site:mp.weixin.qq.com returns URLs-as-titles because WeChat hides
    # meta-data from crawlers. Instead search broadly and filter by content.
    try:
        from ddgs import DDGS
        results = []
        with DDGS() as ddgs:
            for r in ddgs.text(f'{topic} 视频号', max_results=12):
                href  = r.get('href', '')
                title = r.get('title', '').strip()
                body  = r.get('body', '')
                if not title or not href:
                    continue
                # Skip results that look like bare URLs (WeChat hiding meta)
                if title.startswith('http') or title.startswith('mp.weixin'):
                    continue
                # Keep only results mentioning WeChat/视频号 in URL or text
                is_weixin_url = 'weixin.qq.com' in href or 'weixin.sogou.com' in href
                mentions_wx   = '视频号' in (title + body) or '微信' in (title + body)
                if not is_weixin_url and not mentions_wx:
                    continue
                results.append({'title': title, 'url': href,
                                 'snippet': body[:120],
                                 'platform': '视频号', 'source': 'real'})
                if len(results) >= 5:
                    break
        if results:
            return results, None
    except Exception:
        pass

    return [], "未找到相关视频号内容，请换个关键词"


# ── URL 解析 ──────────────────────────────────────────────────────────────────

def fetch_video_from_url(url: str) -> tuple:
    """
    Returns ({title, url, snippet, platform, source}, error_str|None)
    """
    platform = _detect_platform(url)

    if platform == "B站":
        bvid = _extract_bvid(url)
        if bvid:
            try:
                resp = requests.get(BILIBILI_VIEW_URL, params={"bvid": bvid},
                                    headers=BILIBILI_HEADERS, timeout=4)
                resp.raise_for_status()
                data = resp.json()
                if data.get("code") == 0:
                    v    = data["data"]
                    play = _fmt_play(v.get("stat", {}).get("view", 0))
                    name = v.get("owner", {}).get("name", "")
                    desc = v.get("desc", "").strip()
                    return {
                        "title":    v.get("title", ""),
                        "url":      f"https://www.bilibili.com/video/{bvid}",
                        "snippet":  f"▶ {play} 播放  ·  UP: {name}" + (f"\n{desc[:100]}" if desc else ""),
                        "platform": "B站",
                        "source":   "real",
                    }, None
            except Exception:
                pass
        return None, "无法解析该 B站链接，请检查 URL 是否正确"

    if platform == "YouTube":
        vid     = _extract_youtube_id(url)
        api_key = os.getenv("YOUTUBE_API_KEY")
        if vid and api_key:
            try:
                sr = requests.get(YOUTUBE_STATS_URL, params={
                    "part": "snippet,statistics",
                    "id":   vid,
                    "key":  api_key,
                }, timeout=8)
                items = sr.json().get("items", [])
                if items:
                    v    = items[0]
                    play = _fmt_play(v.get("statistics", {}).get("viewCount", ""))
                    sn   = v.get("snippet", {})
                    transcript = _fetch_yt_transcript(vid)
                    return {
                        "title":      sn.get("title", ""),
                        "url":        f"https://www.youtube.com/watch?v={vid}",
                        "snippet":    f"▶ {play} 播放  ·  {sn.get('channelTitle', '')}",
                        "platform":   "YouTube",
                        "source":     "real",
                        "transcript": transcript,
                    }, None
            except Exception:
                pass
        return None, "无法解析该 YouTube 链接，请检查链接或确认已配置 YOUTUBE_API_KEY"

    # 其他平台 — 返回最小信息，让用户手动填写标题
    return {
        "title":    "",
        "url":      url,
        "snippet":  f"来自 {platform}（无法自动获取标题，请手动填写）",
        "platform": platform,
        "source":   "url",
    }, None
