import os
import re
from flask import Flask, request, jsonify, render_template, Response, stream_with_context, session, redirect
from deepseek_client import generate_stream
from database import init_db
from search_client import search_bilibili, search_youtube, search_weixin_video, search_xiaohongshu, search_douyin, fetch_video_from_url, fetch_video_content
from hot_trends_client import fetch_hot, bust_cache, PLATFORMS as HOT_PLATFORMS
from database import get_user_by_id, get_user_devices
from auth import auth_bp
from admin import admin_bp
from prompts import (
    SCRIPT_SYSTEM_PROMPT, VIDEO_TYPES, STYLES, build_script_prompt,
    POSITIONING_SYSTEM_PROMPT, INDUSTRIES, RESOURCES, PLATFORMS,
    ACCOUNT_TYPES, CONTENT_STYLES, CONTENT_FORMATS, build_positioning_prompt,
    VIRAL_TOPIC_SYSTEM_PROMPT, build_viral_topic_prompt,
    MONETIZE_TOPIC_SYSTEM_PROMPT, FOLLOWER_RANGES, build_monetize_topic_prompt,
    SHOT_TABLE_SYSTEM_PROMPT, build_shot_table_prompt,
    REWRITE_SYSTEM_PROMPT, build_rewrite_prompt,
    BREAKDOWN_SYSTEM_PROMPT, build_breakdown_prompt, build_breakdown_sharetext_prompt,
    IMITATE_SYSTEM_PROMPT, build_imitate_prompt,
    DIRECTOR_SYSTEM_PROMPT, SCENES, EQUIPMENT, build_director_prompt,
    CONTENT_PLAN_SYSTEM_PROMPT, DAILY_HOURS_OPTIONS, build_content_plan_prompt,
)

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'dev-secret-change-in-production')

app.register_blueprint(auth_bp)
app.register_blueprint(admin_bp)

init_db()

@app.before_request
def require_login():
    public_paths = {'/login', '/ping'}
    if request.path in public_paths or request.path.startswith('/static'):
        return
    if not session.get('user_id'):
        return redirect('/login')


@app.route('/ping')
def ping():
    return 'ok', 200


def stream_response(system_prompt, user_prompt, model):
    is_admin = session.get('role') == 'admin'
    def generate():
        if is_admin:
            import json as _json
            marker = _json.dumps({"sys": system_prompt, "usr": user_prompt}, ensure_ascii=False)
            yield f"[DEBUG:{marker}:DEBUG]\n"
        try:
            yield from generate_stream(system_prompt, user_prompt, model or None)
        except Exception as e:
            yield f"\n\n[生成出错：{e}]"
    return Response(stream_with_context(generate()), content_type="text/plain; charset=utf-8",
                    headers={"X-Accel-Buffering": "no", "Cache-Control": "no-cache"})


@app.route("/")
def index():
    user = get_user_by_id(session.get('user_id')) or {}
    devices = get_user_devices(session.get('user_id')) if session.get('user_id') else []
    return render_template(
        "index.html",
        is_admin=session.get('role') == 'admin',
        profile_username=session.get('username', ''),
        profile_role=session.get('role', 'user'),
        profile_expires=user['expires_at'] if user else None,
        profile_devices=len(devices),
        profile_created=str(user['created_at'] or '')[:10] if user else '',
        today=__import__('datetime').date.today().isoformat(),
        video_types=VIDEO_TYPES,
        styles=STYLES,
        industries=INDUSTRIES,
        resources=RESOURCES,
        platforms=PLATFORMS,
        account_types=ACCOUNT_TYPES,
        content_styles=CONTENT_STYLES,
        content_formats=CONTENT_FORMATS,
        follower_ranges=FOLLOWER_RANGES,
        scenes=SCENES,
        equipment=EQUIPMENT,
        daily_hours_options=DAILY_HOURS_OPTIONS,
    )


# ─── 脚本制作 ────────────────────────────────────────────────────────────────

@app.route("/api/script", methods=["POST"])
def api_script():
    data = request.get_json()
    topic = data.get("topic", "").strip()
    if not topic:
        return jsonify({"error": "请输入视频主题"}), 400
    prompt = build_script_prompt(
        topic,
        data.get("type", "通用"),
        data.get("style", "幽默"),
        int(data.get("duration", 60)),
    )
    return stream_response(SCRIPT_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 分镜拍摄表 ──────────────────────────────────────────────────────────────

@app.route("/api/shot-table", methods=["POST"])
def api_shot_table():
    data = request.get_json()
    script = data.get("script", "").strip()
    if not script:
        return jsonify({"error": "请先生成脚本"}), 400
    return stream_response(SHOT_TABLE_SYSTEM_PROMPT, build_shot_table_prompt(script), data.get("model"))


# ─── 定位分析 ────────────────────────────────────────────────────────────────

@app.route("/api/positioning", methods=["POST"])
def api_positioning():
    data = request.get_json()
    industry = data.get("industry", "").strip()
    strengths = data.get("strengths", "").strip()
    if not industry or not strengths:
        return jsonify({"error": "请填写行业领域和特长优势"}), 400
    prompt = build_positioning_prompt(
        industry, strengths,
        data.get("resources", []),
        data.get("platforms", []),
        data.get("account_types", []),
        data.get("content_styles", []),
        data.get("content_formats", []),
    )
    return stream_response(POSITIONING_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 爆款选题 ────────────────────────────────────────────────────────────────

@app.route("/api/topics/viral", methods=["POST"])
def api_topics_viral():
    data = request.get_json()
    industry = data.get("industry", "").strip()
    if not industry:
        return jsonify({"error": "请选择赛道领域"}), 400
    prompt = build_viral_topic_prompt(
        industry,
        data.get("strengths", ""),
        data.get("platform", "抖音"),
        data.get("content_direction", ""),
        data.get("viral_elements", []),
    )
    return stream_response(VIRAL_TOPIC_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 变现选题 ────────────────────────────────────────────────────────────────

@app.route("/api/topics/monetize", methods=["POST"])
def api_topics_monetize():
    data = request.get_json()
    industry = data.get("industry", "").strip()
    if not industry:
        return jsonify({"error": "请选择赛道领域"}), 400
    prompt = build_monetize_topic_prompt(
        industry,
        data.get("followers", "0 - 1千"),
        data.get("strengths", ""),
        data.get("monetize_direction", ""),
        data.get("content_tone", []),
    )
    return stream_response(MONETIZE_TOPIC_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 文案二创 ────────────────────────────────────────────────────────────────

@app.route("/api/rewrite", methods=["POST"])
def api_rewrite():
    data = request.get_json()
    original = data.get("original", "").strip()
    if not original:
        return jsonify({"error": "请粘贴原始文案"}), 400
    return stream_response(REWRITE_SYSTEM_PROMPT, build_rewrite_prompt(original), data.get("model"))


# ─── 爆款拆解 ────────────────────────────────────────────────────────────────

@app.route("/api/breakdown", methods=["POST"])
def api_breakdown():
    data = request.get_json()
    title = data.get("title", "").strip()
    if not title:
        return jsonify({"error": "请输入视频标题"}), 400
    prompt = build_breakdown_prompt(title, data.get("content", ""))
    return stream_response(BREAKDOWN_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 爆款仿写 ────────────────────────────────────────────────────────────────

@app.route("/api/imitate", methods=["POST"])
def api_imitate():
    data = request.get_json()
    ref_title = data.get("ref_title", "").strip()
    my_topic  = data.get("my_topic", "").strip()
    if not ref_title or not my_topic:
        return jsonify({"error": "请填写参考视频标题和你的话题"}), 400
    prompt = build_imitate_prompt(
        ref_title,
        data.get("ref_content", ""),
        my_topic,
        data.get("style", "幽默"),
        int(data.get("duration", 60)),
    )
    return stream_response(IMITATE_SYSTEM_PROMPT, prompt, data.get("model"))


@app.route("/api/search-viral", methods=["POST"])
def api_search_viral():
    data = request.get_json()
    topic = data.get("topic", "").strip()
    if not topic:
        return jsonify({"results": [], "error": "请输入搜索关键词"}), 400
    bili_results, bili_error = search_bilibili(topic)
    yt_results,   yt_error   = search_youtube(topic)
    wx_results,   wx_error   = search_weixin_video(topic)
    xhs_results,  xhs_error  = search_xiaohongshu(topic)
    dy_results,   dy_error   = search_douyin(topic)
    # 交叉排名：B站, YT, 视频号, 小红书, 抖音 循环交叉
    results = []
    for i in range(max(len(bili_results), len(yt_results), len(wx_results), len(xhs_results), len(dy_results))):
        if i < len(bili_results):  results.append(bili_results[i])
        if i < len(yt_results):    results.append(yt_results[i])
        if i < len(wx_results):    results.append(wx_results[i])
        if i < len(xhs_results):   results.append(xhs_results[i])
        if i < len(dy_results):    results.append(dy_results[i])
    other = yt_results or wx_results or xhs_results or dy_results
    error = None if results else (bili_error or yt_error or wx_error or xhs_error or dy_error or "未找到相关视频")
    warnings = []
    if bili_error and other: warnings.append(f"B站：{bili_error}")
    if wx_error  and (bili_results or yt_results or xhs_results): warnings.append(f"视频号：{wx_error}")
    warning = "；".join(warnings) if warnings else None
    return jsonify({"results": results, "error": error, "warning": warning})


@app.route("/api/breakdown-sharetext", methods=["POST"])
def api_breakdown_sharetext():
    data = request.get_json()
    sharetext = data.get("sharetext", "").strip()
    if not sharetext:
        return jsonify({"error": "请粘贴视频链接或分享文案"}), 400
    # Accept pre-fetched content from frontend (e.g. from /api/fetch-url for B站/YouTube)
    fetched_content = data.get("fetched_content", "").strip()
    if not fetched_content:
        url_match = re.search(r'https?://\S+', sharetext)
        if url_match:
            fetched_content = fetch_video_content(url_match.group(0), sharetext=sharetext) or ''
    prompt = build_breakdown_sharetext_prompt(sharetext, fetched_content)
    system = BREAKDOWN_SYSTEM_PROMPT if fetched_content else ""
    return stream_response(system, prompt, data.get("model"))


@app.route("/api/fetch-url", methods=["POST"])
def api_fetch_url():
    data = request.get_json()
    url = data.get("url", "").strip()
    if not url:
        return jsonify({"result": None, "error": "请输入视频链接"}), 400
    result, error = fetch_video_from_url(url)
    return jsonify({"result": result, "error": error})


# ─── 编导专栏 ────────────────────────────────────────────────────────────────

@app.route("/api/director", methods=["POST"])
def api_director():
    data = request.get_json()
    topic = data.get("topic", "").strip()
    scene = data.get("scene", "").strip()
    if not topic or not scene:
        return jsonify({"error": "请填写视频主题和拍摄场景"}), 400
    prompt = build_director_prompt(topic, scene, data.get("equipment", ["仅手机"]))
    return stream_response(DIRECTOR_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 内容规划 ────────────────────────────────────────────────────────────────

@app.route("/api/content-plan", methods=["POST"])
def api_content_plan():
    data = request.get_json()
    industry = data.get("industry", "").strip()
    platform = data.get("platform", "").strip()
    if not industry or not platform:
        return jsonify({"error": "请填写行业领域和目标平台"}), 400
    prompt = build_content_plan_prompt(
        industry,
        platform,
        data.get("followers", "0 - 1千"),
        data.get("daily_hours", "1-2小时"),
        data.get("positioning_result", ""),
        data.get("target_audience", ""),
    )
    return stream_response(CONTENT_PLAN_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 热点追踪 ────────────────────────────────────────────────────────────────

@app.route("/api/hot-trends")
def api_hot_trends():
    if session.get('role') != 'admin':
        return jsonify({"error": "无权限"}), 403
    platform = request.args.get("platform", "weibo")
    force = request.args.get("force") == "1"
    if force:
        bust_cache(platform)
    data, ts, error = fetch_hot(platform)
    return jsonify({"data": data, "ts": ts, "error": error, "platforms": HOT_PLATFORMS})


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True, port=5000)
