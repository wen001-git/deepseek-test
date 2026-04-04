import os
import re
import time
import requests
from dotenv import load_dotenv
try:
    from youtube_transcript_api import YouTubeTranscriptApi
    _YT_TRANSCRIPT_AVAILABLE = True
except ImportError:
    _YT_TRANSCRIPT_AVAILABLE = False

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
        return f"{n / 100_000_000:.1f}亿"
    if n >= 10_000:
        return f"{n // 10_000}万"
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
                                    headers=BILIBILI_HEADERS, timeout=8)
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
