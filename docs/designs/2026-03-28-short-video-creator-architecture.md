# Short Video Creator — System Architecture Design

## Background

A web-based AI tool targeting domestic (Chinese) short video creators on platforms like Douyin, Kuaishou, and Xiaohongshu. The tool helps creators with content planning, scripting, and production guidance using DeepSeek API.

## Problem Statement

Short video creators, especially non-technical users, lack accessible tools to:
- Define their account positioning
- Generate viral topic ideas
- Create full shooting scripts
- Analyze why existing videos went viral
- Get filming guidance without professional knowledge

## Proposed Solution

A Flask web application with 7 AI-powered modules, all powered by DeepSeek API (text generation). Mobile-first responsive design with bottom navigation on mobile and sidebar on desktop.

### Architecture

```
deepseek-test/
├── app.py                  # Flask app, 7 API routes
├── prompts.py              # All prompt templates per module
├── deepseek_client.py      # DeepSeek API wrapper (openai SDK)
├── templates/
│   └── index.html          # Responsive frontend (mobile + desktop)
├── docs/
│   └── designs/            # Architecture decision records
└── .env                    # API keys
```

### 7 Modules

| Module | Endpoint | Input | Output |
|--------|----------|-------|--------|
| 定位分析 | POST /api/positioning | Industry, strengths, resources, platforms | Account positioning plan |
| 爆款选题 | POST /api/topics/viral | Industry, platform | 10 viral topic ideas |
| 变现选题 | POST /api/topics/monetize | Industry, follower count | Monetization strategy + topics |
| 脚本制作 | POST /api/script | Topic, type, style, duration | Full shooting script |
| 文案二创 | POST /api/rewrite | Original copy | 3 rewritten versions |
| 爆款拆解 | POST /api/breakdown | Title + content | Viral structure analysis |
| 编导专栏 | POST /api/director | Topic, scene, equipment | Filming guide + shot list |

### Tech Stack

- Backend: Python 3.9 + Flask
- AI: DeepSeek API via openai SDK (base_url=https://api.deepseek.com)
- Frontend: Vanilla HTML/CSS/JS (no framework)
- Config: python-dotenv

### Frontend Layout

- **Mobile (≤768px)**: Fixed top header + scrollable content + fixed bottom tab bar (7 items, horizontally scrollable)
- **Desktop (>768px)**: Left sidebar (220px) + scrollable content area

## Alternatives Considered

### Alternative 1: React/Vue Frontend
- Rejected: Adds build complexity; vanilla JS sufficient for current scope; easier for non-technical deployment

### Alternative 2: Separate microservices per module
- Rejected: Over-engineered for current scale; single Flask app is simpler to deploy

### Alternative 3: Use multiple AI providers (one per module)
- Rejected: Adds cost and complexity; DeepSeek handles all text generation well

### Alternative 4: Next.js full-stack
- Rejected: User unfamiliar with Node.js ecosystem; Python aligns with user's background

## Trade-offs

| Decision | Pro | Con |
|----------|-----|-----|
| Single Flask app | Simple deployment, easy to reason about | Limited scalability if traffic grows |
| Inline HTML template | No build step needed | Harder to maintain as UI grows |
| DeepSeek only | One API key, low cost | Single point of failure for AI |
| No database (yet) | Simple setup | No history persistence |

## Final Decision

Proceed with single Flask app + vanilla frontend. Architecture is simple enough to deploy to Alibaba Cloud ECS without CI/CD pipelines, matching the user's technical level. Add database (SQLite) in a later milestone if history persistence is needed.

## Future Milestones

- **Milestone 3**: SQLite history storage
- **Milestone 4**: 讯飞 ASR integration for video link/upload analysis in 爆款拆解
- **Milestone 5**: TTS voice-over (讯飞/阿里云)
- **Milestone 6**: Kling API for video generation
- **Deployment**: Alibaba Cloud ECS + Nginx
