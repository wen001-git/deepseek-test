import re
import requests

BILIBILI_SEARCH_URL = "https://api.bilibili.com/x/web-interface/search/type"
BILIBILI_VIEW_URL   = "https://api.bilibili.com/x/web-interface/view"
BILIBILI_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://www.bilibili.com",
}


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


# ── B站关键词搜索 ─────────────────────────────────────────────────────────────

def search_bilibili(topic: str) -> tuple:
    """Returns (list[{title,url,snippet,platform,source}], error_str|None)"""
    params = {
        "search_type": "video",
        "keyword":     topic,
        "order":       "click",
        "duration":    1,
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
        for item in data.get("data", {}).get("result", [])[:8]:
            title = _strip_html(item.get("title", "（无标题）"))
            bvid  = item.get("bvid", "")
            play  = _fmt_play(item.get("play", 0))
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
        return [], "搜索超时，请稍后重试"
    except Exception as e:
        return [], f"搜索失败：{e}"


# ── URL 解析 ──────────────────────────────────────────────────────────────────

def fetch_video_from_url(url: str) -> tuple:
    """
    Try to fetch video metadata from a URL.
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

    # Non-Bilibili URL — return minimal info so the user can fill in the title manually
    return {
        "title":    "",
        "url":      url,
        "snippet":  f"来自 {platform}（无法自动获取标题，请手动填写）",
        "platform": platform,
        "source":   "url",
    }, None
