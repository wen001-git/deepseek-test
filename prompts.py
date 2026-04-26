# ─── 脚本制作 ────────────────────────────────────────────────────────────────

SCRIPT_SYSTEM_PROMPT = """你是一位专业的短视频文案创作者，擅长为抖音、快手等平台创作爆款内容。
你的文案特点：
- 开头3秒抓住眼球，制造悬念或共鸣
- 语言简洁有力，口语化，易于理解
- 有明确的情绪节奏，带动观众情绪
- 结尾有引导互动的钩子（点赞/关注/评论）
"""

VIDEO_TYPES = {
    "美食": "美食探店/制作",
    "旅行": "旅行/风景",
    "教程": "知识/技能教程",
    "种草": "产品种草/推荐",
    "搞笑": "搞笑/生活",
    "励志": "励志/正能量",
}

STYLES = {
    "幽默": "风趣幽默，接地气",
    "专业": "专业权威，有深度",
    "种草": "真实分享，有感染力",
    "悬疑": "制造悬念，引发好奇",
}


def build_script_prompt(topic: str, video_type: str = "通用", style: str = "幽默", duration: int = 60) -> str:
    type_desc = VIDEO_TYPES.get(video_type, video_type)
    style_desc = STYLES.get(style, style)
    return f"""请为以下主题创作一篇完整的短视频拍摄脚本：

主题：{topic}
视频类型：{type_desc}
文案风格：{style_desc}
视频时长：约 {duration} 秒

要求：
1. 第一句话必须是吸引人的开场白（钩子）
2. 中间部分分 3-4 个节点，每个节点包含：台词 + 镜头说明（景别/动作）
3. 结尾加互动引导
4. 标注每段大概对应的时间点（秒）
5. 在脚本后附上 5 个适合发布的话题标签

请直接输出脚本，不要解释。"""


SHOT_TABLE_SYSTEM_PROMPT = """你是一位专业的短视频导演和 AI 内容创作者。根据给定的脚本，生成详细的分镜拍摄表，字段必须严格按照要求输出 Markdown 表格。"""

def build_shot_table_prompt(script: str) -> str:
    return f"""根据以下短视频脚本，生成完整的分镜拍摄表。

脚本内容：
{script}

请输出一个 Markdown 表格，包含以下列（严格按顺序）：
| 镜头号 | 景别 | 画面描述 | 文生图提示词 | 图生视频提示词 | 时长(秒) | 旁白/对白 | 备注 |

说明：
- 景别：特写、近景、中景、远景、大远景 中选一
- 画面描述：场景、人物动作、气氛等，具体可视化
- 文生图提示词：先用中文描述画面内容（帮助理解），再换行写"EN："开头的英文提示词，供 Midjourney/Stable Diffusion 等工具使用。格式示例：中：博主特写，夸张表情，古色香的招牌背景 EN：close-up of blogger with exaggerated expression, antique signboard background, cinematic, 8k
- 图生视频提示词：先用中文描述镜头运动（帮助理解），再换行写"EN："开头的英文提示词，供 Runway/Kling 等工具使用。格式示例：中：缓慢推进镜头，跟随手指方向 EN：slow push-in shot following pointing finger, smooth motion
- 时长：每个镜头建议秒数，所有镜头合计应与视频总时长相符
- 旁白/对白：该镜头对应的台词或画外音，无则填"—"
- 备注：拍摄注意事项、特效说明等，无则填"—"

只输出表格，不要其他说明文字。"""


# ─── 定位分析 ────────────────────────────────────────────────────────────────

POSITIONING_SYSTEM_PROMPT = """你是一位资深短视频账号运营顾问，帮助创作者找到精准的账号定位。
你的建议要：
- 结合创作者的实际情况，给出可落地的方向
- 找到差异化优势，避免同质化竞争
- 语言通俗易懂，不用行话
"""

INDUSTRIES = [
    "美食", "旅行", "母婴育儿", "健身运动", "教育知识",
    "财经理财", "时尚穿搭", "美妆护肤", "科技数码", "游戏娱乐",
    "宠物", "家居生活", "职场干货", "情感婚姻", "三农农村", "其他",
]

RESOURCES = ["愿意出镜", "不愿意出镜", "专业摄影设备", "只有手机", "有剪辑技能", "没有剪辑基础"]

PLATFORMS = ["抖音", "快手", "小红书", "视频号", "B站"]

ACCOUNT_TYPES = [
    "个人IP（个人品牌打造）",
    "企业账号（企业形象展示）",
    "品牌账号（品牌推广营销）",
    "机构账号（MCN/工作室）",
]

CONTENT_STYLES = [
    "干货知识", "搞笑娱乐", "生活记录", "情感共鸣",
    "种草带货", "励志正能量", "剧情故事", "测评分享",
    "才艺展示", "萌宠可爱", "亲子互动", "旅行探索",
    "美食制作", "时尚穿搭", "健康养生", "职场技巧",
    "科普知识", "悬疑反转", "挑战实验", "游戏解说",
]

CONTENT_FORMATS = [
    "口播", "情景剧", "教程", "Vlog", "测评",
    "图文", "探店", "开箱", "街头采访", "混剪", "动画/插画", "多形式",
]


def build_positioning_prompt(industry: str, strengths: str, resources: list, platforms: list,
                             account_types: list = None, content_styles: list = None,
                             content_formats: list = None) -> str:
    resources_str = "、".join(resources) if resources else "未填写"
    platforms_str = "、".join(platforms) if platforms else "未填写"
    account_types_str = "、".join(account_types) if account_types else "未填写"
    content_styles_str = "、".join(content_styles) if content_styles else "未填写"
    content_formats_str = "、".join(content_formats) if content_formats else "未填写"
    return f"""请根据以下信息，为这位创作者制定短视频账号定位方案：

行业和领域：{industry}
特长和优势：{strengths}
账号类型：{account_types_str}
内容风格偏好：{content_styles_str}
内容形式偏好：{content_formats_str}
可用资源：{resources_str}
目标平台：{platforms_str}

请输出以下内容：
1. 【账号定位】：一句话概括账号方向（20字以内）
2. 【内容方向】：3-5 个具体的内容方向，每个方向举一个选题例子
3. 【差异化优势】：与同赛道其他账号相比，这位创作者的独特之处
4. 【目标人群】：描述最可能关注该账号的人群画像
5. 【起步建议】：新账号冷启动的 3 条实操建议
6. 【发展建议】：3-6 个月的阶段性成长目标和策略（分阶段描述：第1个月、第2-3个月、第4-6个月各应专注什么，达到什么里程碑）

请直接输出，语言通俗易懂。"""


# ─── 内容规划 ────────────────────────────────────────────────────────────────

CONTENT_PLAN_SYSTEM_PROMPT = """你是一位短视频内容运营专家，擅长为创作者制定科学的内容发布计划。
你的方案要：
- 结合创作者的实际时间和资源，给出可执行的排期
- 内容类型搭配合理，兼顾涨粉、互动、变现
- 先用 Markdown 写出完整的中文规划说明，再在最末尾附上结构化 JSON 数据块，JSON 必须完整，key 名称与要求完全一致
"""

DAILY_HOURS_OPTIONS = ["< 1小时", "1-2小时", "2-4小时", "4小时以上"]


def build_content_plan_prompt(industry: str, platform: str, followers: str, daily_hours: str, positioning_result: str = '', target_audience: str = '') -> str:
    pos_section = f"\n\n【定位分析参考】（请结合以下定位分析结果制定内容规划）：\n{positioning_result.strip()}" if positioning_result.strip() else ""
    ta_section = f"\n目标客户画像：{target_audience.strip()}" if target_audience.strip() else ""
    return f"""请为以下创作者制定30天内容发布计划：

行业/领域：{industry}
目标平台：{platform}
当前粉丝量：{followers}
每天可用创作时间：{daily_hours}{ta_section}{pos_section}

请严格按以下顺序输出（先完整写完第一部分全部内容，再输出第二部分 JSON，中间不要穿插）：

【第一部分】用清晰的中文 Markdown 格式写出完整的内容规划说明，必须包含以下全部四点：
- 每天发布条数和最佳发布时间（说明选择理由）
- 内容类型分配比例及各类型的作用（涨粉/互动/变现/留存）
- 一周内容排期（周一到周日，每天具体可执行的选题方向）
- 针对当前粉丝阶段的发展建议

【第二部分】第一部分全部写完后，在最末尾紧接着附上以下 JSON 数据块（不要在第一部分中间插入 JSON），key 名称必须完全一致，不要省略任何字段：
```json
{{
  "daily_count": <整数>,
  "best_post_times": ["HH:MM", "HH:MM"],
  "type_distribution": [{{"name": "类型名", "days": <整数>, "ratio": <整数不带%>}}],
  "weekly_template": [{{"day": "周一", "type": "类型名", "theme": "具体选题方向"}}],
  "growth_advice": "50-80字发展建议"
}}
```

要求：type_distribution 各 days 之和 = 30，ratio 之和 = 100；weekly_template 含周一到周日共 7 条。"""


# ─── 爆款选题 ────────────────────────────────────────────────────────────────

VIRAL_TOPIC_SYSTEM_PROMPT = """你是一位专注于短视频内容策划的爆款选题专家，对各大平台热门内容有深入研究。
你的选题要：
- 有强烈的点击欲望和传播性
- 贴近目标用户的真实需求和痛点
- 有明确的故事性或实用价值
"""


def build_viral_topic_prompt(industry: str, strengths: str = '',
                              platform: str = '抖音',
                              content_direction: str = '',
                              viral_elements: list = None) -> str:
    direction_hint = ''
    if content_direction:
        direction_hint += f'内容方向偏好：{content_direction}\n'
    if viral_elements:
        direction_hint += f'爆款元素偏好：{"、".join(viral_elements)}\n'
    if direction_hint:
        direction_hint = f'\n创作偏好（请结合以下方向生成选题）：\n{direction_hint.rstrip()}'

    strengths_section = f'\n创作者特长和优势：{strengths.strip()}' if strengths.strip() else ''

    return f"""请为以下赛道生成 10 个爆款选题：

赛道/领域：{industry}
发布平台：{platform}{strengths_section}{direction_hint}

要求：
- 每个选题包含：标题 + 爆款理由（为什么这个选题容易火）
- 标题要有冲击力，能引发好奇或共鸣
- 涵盖不同类型：干货类、情绪类、故事类、测评类等

请按以下格式输出（直接列出，不要多余说明）：
1. 【标题】xxx
   【爆款理由】xxx

2. 【标题】xxx
   【爆款理由】xxx
（以此类推）"""


# ─── 变现选题 ────────────────────────────────────────────────────────────────

MONETIZE_TOPIC_SYSTEM_PROMPT = """你是一位短视频商业化顾问，精通各种变现模式和对应的内容策略。
你的建议要：
- 结合赛道特点，推荐最适合的变现方式
- 给出具体可操作的选题方向
- 分析变现潜力和实施难度
"""

FOLLOWER_RANGES = ["0 - 1千", "1千 - 1万", "1万 - 10万", "10万以上"]


def build_monetize_topic_prompt(industry: str, followers: str, strengths: str = '',
                                monetize_direction: str = '',
                                content_tone: list = None) -> str:
    strengths_section = f'\n创作者特长和优势：{strengths.strip()}' if strengths.strip() else ''

    direction_hint = ''
    if monetize_direction:
        direction_hint += f'变现方式偏好：{monetize_direction}\n'
    if content_tone:
        direction_hint += f'内容调性偏好：{"、".join(content_tone)}\n'
    if direction_hint:
        direction_hint = f'\n创作偏好（请结合以下方向生成选题）：\n{direction_hint.rstrip()}'

    return f"""请为以下账号制定变现选题方案：

赛道/领域：{industry}
当前粉丝量级：{followers}{strengths_section}{direction_hint}

请输出以下内容：
1. 【最适合的变现方式】：列出 2-3 种最适合该赛道和量级的变现路径（如：接广告/带货/知识付费/私域引流等），说明理由
2. 【变现选题方向】：针对每种变现方式，给出 3 个对应的具体选题，并说明如何在内容中自然植入变现点
3. 【操作路径】：从现在开始，分 3 步走的变现计划

请直接输出，语言实用具体。"""


# ─── 文案二创 ────────────────────────────────────────────────────────────────

REWRITE_SYSTEM_PROMPT = """你是一位擅长内容改写和二次创作的短视频文案专家。
改写要求：
- 保留原文核心信息，不改变事实
- 换新的角度、结构或表达方式
- 每个版本要有明显的差异化风格
"""


def build_rewrite_prompt(original: str) -> str:
    return f"""请对以下短视频文案进行二次创作，输出 3 个不同风格的改写版本：

【原始文案】：
{original}

改写要求：
版本1 — 悬疑反转风：用设置悬念、制造反转的方式重写
版本2 — 干货清单风：用"X个技巧/方法/原因"的结构改写
版本3 — 情感共鸣风：从情感角度切入，引发观众共鸣

每个版本都要包含：开场钩子 + 正文 + 互动引导

请直接输出 3 个版本，每个版本前标注风格名称。"""


# ─── 爆款拆解 ────────────────────────────────────────────────────────────────

BREAKDOWN_SYSTEM_PROMPT = """你是一位专业的短视频爆款内容分析师，擅长拆解爆款视频的底层逻辑和结构公式。
分析要：
- 深入挖掘内容背后的传播逻辑
- 提炼可复用的公式和方法论
- 语言专业但通俗，让创作者能直接借鉴
"""


def build_breakdown_prompt(title: str, content: str) -> str:
    content_section = f"\n【视频内容/文案】：\n{content}" if content.strip() else ""
    return f"""请对以下短视频进行爆款拆解分析：

【视频标题】：{title}{content_section}

请从以下维度进行深度拆解：
1. 【钩子分析】：开头如何在 3 秒内抓住观众？用了什么钩子技巧？
2. 【内容结构】：整体结构是什么？（起承转合/问题-解决方案/故事弧线等）
3. 【情绪节奏】：视频在哪些节点制造了情绪高潮？如何保持观众留存？
4. 【传播因子】：是什么让人想转发或评论？
5. 【爆款公式】：总结出 1 个可复用的内容公式，并给出套用示例

请直接输出分析，语言专业实用。"""


def build_breakdown_sharetext_prompt(sharetext: str, fetched_content: str = '') -> str:
    if fetched_content.strip():
        return f"""请对以下短视频进行爆款拆解分析：

【分享文案】：{sharetext}

【已抓取的视频数据与相关内容】：
{fetched_content}

请完成以下两部分：

**第一部分：视频基础信息提取**
- 视频标题/文案（从上方数据中提取）
- 话题标签
- 发布者
- 核心数据（点赞/评论/收藏/分享）
- 视频文案内容（根据上方网络资讯，提炼出视频的核心叙述内容，100-200字）

**第二部分：深度爆款拆解分析**
1. 【钩子分析】：开头如何在 3 秒内抓住观众？用了什么钩子技巧？
2. 【内容结构】：整体结构是什么？（起承转合/问题-解决方案/故事弧线等）
3. 【情绪节奏】：视频在哪些节点制造了情绪高潮？如何保持观众留存？
4. 【传播因子】：是什么让人想转发或评论？
5. 【爆款公式】：总结出 1 个可复用的内容公式，并给出套用示例"""
    return f"请抓取这个视频的标题、话题、文案内容，并进行视频拆解分析：{sharetext}"


# ─── 爆款仿写 ────────────────────────────────────────────────────────────────

IMITATE_SYSTEM_PROMPT = """你是一位资深短视频创作顾问，擅长提炼爆款视频的底层公式，并将其迁移应用到全新话题上。
你的创作原则：
- 神形分离：结构/节奏/情绪弧线与原视频相同，但内容、角度、文案完全原创
- 钩子优先：开头必须在 3 秒内抓住眼球
- 完整脚本：包含台词 + 镜头说明 + 时间节点
"""


def build_imitate_prompt(ref_title: str, ref_content: str, my_topic: str,
                         style: str = "幽默", duration: int = 60) -> str:
    ref_section = f"\n【参考视频文案/内容】：\n{ref_content}" if ref_content.strip() else ""
    style_desc = STYLES.get(style, style)
    return f"""请完成以下「爆款仿写」任务：

## 参考爆款
【标题】：{ref_title}{ref_section}

## 我的创作需求
【我的话题】：{my_topic}
【视频风格】：{style_desc}
【目标时长】：约 {duration} 秒

## 输出要求
**第一部分：公式提炼**（3-5 行，简明扼要）
- 钩子类型：___
- 内容结构：___
- 情绪节奏：___
- 传播因子：___

**第二部分：仿写脚本**
按提炼的公式，为「{my_topic}」创作一个完整短视频脚本：
- 每段标注时间点（秒）和镜头说明
- 结尾加互动引导
- 附 5 个话题标签

注意：内容须完全原创，不得抄袭参考视频的具体文案。"""


# ─── 编导专栏 ────────────────────────────────────────────────────────────────

DIRECTOR_SYSTEM_PROMPT = """你是一位经验丰富的短视频编导，精通拍摄技巧、镜头语言和后期节奏。
你的建议要：
- 针对创作者的实际设备条件给出可落地的方案
- 包含具体的景别、运镜、灯光建议
- 让没有拍摄经验的人也能看懂并执行
"""

SCENES = ["室内家居", "室内专业摄影棚", "户外自然", "户外城市街道", "餐厅/咖啡厅", "办公室", "其他"]

EQUIPMENT = ["仅手机", "手机+稳定器", "单反/微单", "专业摄像机", "无人机", "GoPro运动相机"]


def build_director_prompt(topic: str, scene: str, equipment: list) -> str:
    equipment_str = "、".join(equipment) if equipment else "手机"
    return f"""请为以下短视频提供完整的编导拍摄方案：

视频主题：{topic}
拍摄场景：{scene}
可用设备：{equipment_str}

请输出以下内容：
1. 【拍摄思路】：这条视频的整体拍摄逻辑和视觉风格建议
2. 【分镜方案】：列出 4-6 个镜头，每个镜头说明：
   - 景别（特写/近景/中景/全景）
   - 拍摄角度（正面/侧面/俯拍/仰拍）
   - 运镜方式（固定/推拉/横移/跟拍）
   - 画面内容描述
3. 【灯光建议】：根据场景和设备，给出简单可行的补光方案
4. 【剪辑节奏】：建议的剪辑节奏和转场风格
5. 【拍摄小技巧】：2-3 条针对该题材的实用拍摄技巧

请直接输出方案，语言通俗易懂，适合新手执行。"""
