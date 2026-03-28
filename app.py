from flask import Flask, request, jsonify, render_template
from deepseek_client import generate_text
from prompts import (
    SCRIPT_SYSTEM_PROMPT, VIDEO_TYPES, STYLES, build_script_prompt,
    POSITIONING_SYSTEM_PROMPT, INDUSTRIES, RESOURCES, PLATFORMS, build_positioning_prompt,
    VIRAL_TOPIC_SYSTEM_PROMPT, build_viral_topic_prompt,
    MONETIZE_TOPIC_SYSTEM_PROMPT, FOLLOWER_RANGES, build_monetize_topic_prompt,
    REWRITE_SYSTEM_PROMPT, build_rewrite_prompt,
    BREAKDOWN_SYSTEM_PROMPT, build_breakdown_prompt,
    DIRECTOR_SYSTEM_PROMPT, SCENES, EQUIPMENT, build_director_prompt,
)

app = Flask(__name__)


@app.route("/")
def index():
    return render_template(
        "index.html",
        video_types=VIDEO_TYPES,
        styles=STYLES,
        industries=INDUSTRIES,
        resources=RESOURCES,
        platforms=PLATFORMS,
        follower_ranges=FOLLOWER_RANGES,
        scenes=SCENES,
        equipment=EQUIPMENT,
    )


# ─── 脚本制作 ────────────────────────────────────────────────────────────────

@app.route("/api/script", methods=["POST"])
def api_script():
    try:
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
        return jsonify({"content": generate_text(SCRIPT_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 定位分析 ────────────────────────────────────────────────────────────────

@app.route("/api/positioning", methods=["POST"])
def api_positioning():
    try:
        data = request.get_json()
        industry = data.get("industry", "").strip()
        strengths = data.get("strengths", "").strip()
        if not industry or not strengths:
            return jsonify({"error": "请填写行业领域和特长优势"}), 400
        prompt = build_positioning_prompt(
            industry,
            strengths,
            data.get("resources", []),
            data.get("platforms", []),
        )
        return jsonify({"content": generate_text(POSITIONING_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 爆款选题 ────────────────────────────────────────────────────────────────

@app.route("/api/topics/viral", methods=["POST"])
def api_topics_viral():
    try:
        data = request.get_json()
        industry = data.get("industry", "").strip()
        platform = data.get("platform", "抖音").strip()
        if not industry:
            return jsonify({"error": "请选择赛道领域"}), 400
        prompt = build_viral_topic_prompt(industry, platform)
        return jsonify({"content": generate_text(VIRAL_TOPIC_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 变现选题 ────────────────────────────────────────────────────────────────

@app.route("/api/topics/monetize", methods=["POST"])
def api_topics_monetize():
    try:
        data = request.get_json()
        industry = data.get("industry", "").strip()
        followers = data.get("followers", "0 - 1千").strip()
        if not industry:
            return jsonify({"error": "请选择赛道领域"}), 400
        prompt = build_monetize_topic_prompt(industry, followers)
        return jsonify({"content": generate_text(MONETIZE_TOPIC_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 文案二创 ────────────────────────────────────────────────────────────────

@app.route("/api/rewrite", methods=["POST"])
def api_rewrite():
    try:
        data = request.get_json()
        original = data.get("original", "").strip()
        if not original:
            return jsonify({"error": "请粘贴原始文案"}), 400
        prompt = build_rewrite_prompt(original)
        return jsonify({"content": generate_text(REWRITE_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 爆款拆解 ────────────────────────────────────────────────────────────────

@app.route("/api/breakdown", methods=["POST"])
def api_breakdown():
    try:
        data = request.get_json()
        title = data.get("title", "").strip()
        content = data.get("content", "").strip()
        if not title:
            return jsonify({"error": "请输入视频标题"}), 400
        prompt = build_breakdown_prompt(title, content)
        return jsonify({"content": generate_text(BREAKDOWN_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── 编导专栏 ────────────────────────────────────────────────────────────────

@app.route("/api/director", methods=["POST"])
def api_director():
    try:
        data = request.get_json()
        topic = data.get("topic", "").strip()
        scene = data.get("scene", "").strip()
        if not topic or not scene:
            return jsonify({"error": "请填写视频主题和拍摄场景"}), 400
        prompt = build_director_prompt(
            topic,
            scene,
            data.get("equipment", ["仅手机"]),
        )
        return jsonify({"content": generate_text(DIRECTOR_SYSTEM_PROMPT, prompt)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True, port=5000)
