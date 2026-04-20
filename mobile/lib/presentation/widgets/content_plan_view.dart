import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/locale_provider.dart';

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
class ContentPlanView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
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
                label: s.postsPerDay,
                value: s.postsCount(plan['daily_count'] ?? '-'),
              ),
            ),
            Container(width: 1, height: 48, color: colorScheme.outlineVariant),
            Expanded(
              child: _MetaTile(
                label: s.bestPostTimes,
                value: ((plan['best_post_times'] as List?) ?? []).join('、'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── B: Distribution bars ────────────────────────────────────────────
        _SectionCard(
          title: s.contentTypeDist,
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

        // ── C: 30-day flat list (no popup, every day has a script button) ──
        _SectionCard(
          title: s.thirtyDayCalendar,
          child: Column(
            children: List.generate(30, (i) {
              final dayNum = i + 1;
              final entry = weeklyTpl.isNotEmpty
                  ? weeklyTpl[i % weeklyTpl.length] as Map
                  : <String, dynamic>{};
              final type = entry['type'] as String? ?? '';
              final theme = entry['theme'] as String? ?? '';
              final color = colorMap[type] ?? const Color(0xFF999999);
              return _DayListItem(
                dayNum: dayNum,
                type: type,
                theme: theme,
                color: color,
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // ── E: Growth advice ───────────────────────────────────────────────
        if ((plan['growth_advice'] as String?)?.isNotEmpty == true)
          _SectionCard(
            title: s.growthAdvice,
            child: Text(plan['growth_advice'] as String,
                style: textTheme.bodyMedium),
          ),
        const SizedBox(height: 12),

        // ── F: Reasons (expandable) ────────────────────────────────────────
        if ((plan['reasons'] as Map?) != null) ...[
          _ReasonTile(
            label: s.whyPostTimes,
            text: (plan['reasons'] as Map)['posting_time'] as String? ?? '',
          ),
          _ReasonTile(
            label: s.whyContentMix,
            text: (plan['reasons'] as Map)['content_mix'] as String? ?? '',
          ),
          _ReasonTile(
            label: s.whyWeeklyRhythm,
            text: (plan['reasons'] as Map)['weekly_rhythm'] as String? ?? '',
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Day list item (replaces popup bubble) ─────────────────────────────────────
// Shows one row: day circle | type badge | theme text | 制作脚本 button.
// Theme text is selectable so users can copy it before tapping the button.

class _DayListItem extends StatelessWidget {
  final int dayNum;
  final String type;
  final String theme;
  final Color color;

  const _DayListItem({
    required this.dayNum,
    required this.type,
    required this.theme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Colored day circle
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$dayNum',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          // Theme text — selectable for copying
          Expanded(
            child: SelectableText(
              theme,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 4),
          // Navigate to script screen with topic pre-filled
          _ScriptButton(topic: '$type：$theme'),
        ],
      ),
    );
  }
}

// ── Compact "制作脚本" button ──────────────────────────────────────────────────

class _ScriptButton extends ConsumerWidget {
  final String topic;
  const _ScriptButton({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return SizedBox(
      height: 26,
      child: TextButton(
        onPressed: () => GoRouter.of(context).go('/script', extra: topic),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF6366f1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 12),
            const SizedBox(width: 2),
            Text(s.makeScript, style: const TextStyle(fontSize: 11)),
          ],
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
