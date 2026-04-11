import 'package:flutter/material.dart';

/// Visualizes the structured JSON returned by the /api/content-plan endpoint.
///
/// Expected [plan] shape:
/// {
///   "daily_count": int,
///   "best_post_times": [String, ...],
///   "type_distribution": [{"name": str, "days": int, "ratio": int}, ...],
///   "weekly_template":   [{"day": str, "type": str, "theme": str}, ...],  // 7 entries
///   "growth_advice": String,
///   "reasons": {"posting_time": str, "content_mix": str, "weekly_rhythm": str}
/// }
class ContentPlanView extends StatelessWidget {
  final Map<String, dynamic> plan;

  const ContentPlanView({super.key, required this.plan});

  // Same palette as the web version
  static const _colors = [
    Color(0xFF6366f1),
    Color(0xFF10b981),
    Color(0xFFf59e0b),
    Color(0xFFef4444),
    Color(0xFF3b82f6),
    Color(0xFF8b5cf6),
    Color(0xFFec4899),
    Color(0xFF14b8a6),
  ];

  Map<String, Color> _buildColorMap(List<dynamic> types) {
    final map = <String, Color>{};
    for (var i = 0; i < types.length; i++) {
      final name = (types[i] as Map)['name'] as String? ?? '';
      map[name] = _colors[i % _colors.length];
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final typeDist = (plan['type_distribution'] as List?) ?? [];
    final weeklyTpl = (plan['weekly_template'] as List?) ?? [];
    final colorMap = _buildColorMap(typeDist);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── A: Meta ────────────────────────────────────────────────────────
        _SectionCard(
          child: Row(children: [
            Expanded(
              child: _MetaTile(
                label: '每天发布',
                value: '${plan['daily_count'] ?? '-'} 条',
              ),
            ),
            Container(width: 1, height: 48, color: colorScheme.outlineVariant),
            Expanded(
              child: _MetaTile(
                label: '最佳发布时间',
                value: ((plan['best_post_times'] as List?) ?? []).join('、'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── B: Distribution bars ────────────────────────────────────────────
        _SectionCard(
          title: '内容类型分布',
          child: Column(
            children: typeDist.map<Widget>((t) {
              final name = t['name'] as String? ?? '';
              final ratio = (t['ratio'] as num?)?.toDouble() ?? 0;
              final color = colorMap[name] ?? _colors[0];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    child: Text(name,
                        style: textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio / 100,
                        minHeight: 10,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 36,
                    child: Text('${ratio.toInt()}%',
                        style: textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // ── C: 30-day calendar ─────────────────────────────────────────────
        _SectionCard(
          title: '30天发布日历',
          child: _CalendarGrid(
            weeklyTemplate: weeklyTpl,
            colorMap: colorMap,
          ),
        ),
        const SizedBox(height: 12),

        // ── D: Weekly template table ────────────────────────────────────────
        _SectionCard(
          title: '一周内容模板',
          child: Column(
            children: weeklyTpl.map<Widget>((w) {
              final day = w['day'] as String? ?? '';
              final type = w['type'] as String? ?? '';
              final theme = w['theme'] as String? ?? '';
              final color = colorMap[type] ?? _colors[0];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(day,
                          style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(type,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(theme,
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.visible),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // ── E: Growth advice ───────────────────────────────────────────────
        if ((plan['growth_advice'] as String?)?.isNotEmpty == true)
          _SectionCard(
            title: '成长建议',
            child: Text(plan['growth_advice'] as String,
                style: textTheme.bodyMedium),
          ),
        const SizedBox(height: 12),

        // ── F: Reasons (expandable) ────────────────────────────────────────
        if ((plan['reasons'] as Map?) != null) ...[
          _ReasonTile(
            label: '💡 为什么选这些发布时间？',
            text: (plan['reasons'] as Map)['posting_time'] as String? ?? '',
          ),
          _ReasonTile(
            label: '💡 为什么这样分配内容类型？',
            text: (plan['reasons'] as Map)['content_mix'] as String? ?? '',
          ),
          _ReasonTile(
            label: '💡 为什么这样安排一周节奏？',
            text: (plan['reasons'] as Map)['weekly_rhythm'] as String? ?? '',
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Calendar grid ──────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final List<dynamic> weeklyTemplate;
  final Map<String, Color> colorMap;

  const _CalendarGrid(
      {required this.weeklyTemplate, required this.colorMap});

  @override
  Widget build(BuildContext context) {
    // Build type list ordered by day-of-week cycle
    final typeByIndex = weeklyTemplate
        .map((w) => w['type'] as String? ?? '')
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(30, (i) {
        final dayNum = i + 1;
        final type = typeByIndex.isNotEmpty
            ? typeByIndex[i % typeByIndex.length]
            : '';
        final theme = weeklyTemplate.isNotEmpty
            ? (weeklyTemplate[i % weeklyTemplate.length]['theme'] as String? ??
                '')
            : '';
        final color = colorMap[type] ?? const Color(0xFF999999);
        return _DayBubble(
          day: dayNum,
          type: type,
          theme: theme,
          color: color,
        );
      }),
    );
  }
}

class _DayBubble extends StatelessWidget {
  final int day;
  final String type;
  final String theme;
  final Color color;

  const _DayBubble(
      {required this.day,
      required this.type,
      required this.theme,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('第 $day 天'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(theme, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Shared section card ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// ── Meta tile ─────────────────────────────────────────────────────────────────

class _MetaTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetaTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Reason expandable ─────────────────────────────────────────────────────────

class _ReasonTile extends StatelessWidget {
  final String label;
  final String text;

  const _ReasonTile({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
