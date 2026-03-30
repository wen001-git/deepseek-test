# 内容规划模块 + 定位分析发展建议

## Background
用户反馈定位分析缺少内容排期规划。将其拆为独立模块（📅 内容规划），同时在定位分析中补充发展建议。

## Problem Statement
- 定位分析只有"起步建议"，缺乏中长期发展路径
- 账号规划（每天发几条、内容配比、30天日历）内容量大，塞入定位分析会过于臃肿

## Proposed Solution

### 1. 定位分析增加"发展建议"
在 `build_positioning_prompt()` 第6项加入：3-6个月阶段性成长目标和策略。

### 2. 新增"内容规划"模块
**输入：** 行业、目标平台、当前粉丝量、每天可用创作时间

**AI返回 JSON 格式数据（非流式）：**
```json
{
  "daily_count": 1,
  "best_post_times": ["18:00", "20:00"],
  "type_distribution": [
    {"name": "干货教程", "days": 12, "ratio": 40}
  ],
  "weekly_template": [
    {"day": "周一", "type": "干货教程", "theme": "主题"}
  ],
  "thirty_day_plan": [
    {"day": 1, "type": "干货教程", "theme": "主题简述"}
  ],
  "growth_advice": "发展建议文字"
}
```

**前端可视化：**
- 内容类型分布：彩色进度条 + 图例
- 30天日历：彩色圆圈（按内容类型着色）+ 点击展开当天主题
- 一周模板表格

**颜色系统（前端预定义，按顺序分配给 type_distribution）：**
`["#6366f1", "#10b981", "#f59e0b", "#ef4444", "#3b82f6", "#8b5cf6", "#ec4899", "#14b8a6"]`

## Files Modified
- `prompts.py` — 更新 build_positioning_prompt，新增 CONTENT_PLAN_SYSTEM_PROMPT + build_content_plan_prompt
- `app.py` — 新增 POST /api/content-plan 路由（JSON，非流式）
- `templates/index.html` — 新增侧边栏项、面板、CSS、JS渲染逻辑

## Trade-offs
| 决策 | 原因 |
|------|------|
| JSON 而非流式 | 可视化需要完整结构化数据，无法边流边渲染 |
| 颜色前端预定义 | AI 不可靠地返回颜色值，前端按顺序分配更稳定 |
| 独立模块 | 内容规划可独立使用，不强依赖定位分析 |

## Final Decision
按上述方案实施。
