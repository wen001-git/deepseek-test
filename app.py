import os
from flask import Flask, request, jsonify, render_template, Response, stream_with_context, session, redirect
from deepseek_client import generate_stream
from database import init_db
from search_client import search_bilibili, search_youtube, fetch_video_from_url
from auth import auth_bp
from admin import admin_bp
from prompts import (
    SCRIPT_SYSTEM_PROMPT, VIDEO_TYPES, STYLES, build_script_prompt,
    POSITIONING_SYSTEM_PROMPT, INDUSTRIES, RESOURCES, PLATFORMS,
    ACCOUNT_TYPES, CONTENT_STYLES, CONTENT_FORMATS, build_positioning_prompt,
    VIRAL_TOPIC_SYSTEM_PROMPT, build_viral_topic_prompt,
    MONETIZE_TOPIC_SYSTEM_PROMPT, FOLLOWER_RANGES, build_monetize_topic_prompt,
    REWRITE_SYSTEM_PROMPT, build_rewrite_prompt,
    BREAKDOWN_SYSTEM_PROMPT, build_breakdown_prompt,
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
    public_paths = {'/login'}
    if request.path in public_paths or request.path.startswith('/static'):
        return
    if not session.get('user_id'):
        return redirect('/login')


def stream_response(system_prompt, user_prompt, model):
    def generate():
        try:
            yield from generate_stream(system_prompt, user_prompt, model or None)
        except Exception as e:
            yield f"\n\n[生成出错：{e}]"
    return Response(stream_with_context(generate()), content_type="text/plain; charset=utf-8")


@app.route("/")
def index():
    return render_template(
        "index.html",
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
    prompt = build_viral_topic_prompt(industry, data.get("platform", "抖音"))
    return stream_response(VIRAL_TOPIC_SYSTEM_PROMPT, prompt, data.get("model"))


# ─── 变现选题 ────────────────────────────────────────────────────────────────

@app.route("/api/topics/monetize", methods=["POST"])
def api_topics_monetize():
    data = request.get_json()
    industry = data.get("industry", "").strip()
    if not industry:
        return jsonify({"error": "请选择赛道领域"}), 400
    prompt = build_monetize_topic_prompt(industry, data.get("followers", "0 - 1千"))
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
    # 交叉排名：B站[0], YT[0], B站[1], YT[1], ...
    results = []
    for i in range(max(len(bili_results), len(yt_results))):
        if i < len(bili_results):
            results.append(bili_results[i])
        if i < len(yt_results):
            results.append(yt_results[i])
    error   = None if results else (bili_error or yt_error or "未找到相关视频")
    warning = bili_error if (bili_error and yt_results) else None
    return jsonify({"results": results, "error": error, "warning": warning})


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
    )
    return stream_response(CONTENT_PLAN_SYSTEM_PROMPT, prompt, data.get("model"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True, port=5000)
