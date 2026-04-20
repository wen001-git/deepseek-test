import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_strings.dart';
import '../../providers/locale_provider.dart';

// ── Parser ────────────────────────────────────────────────────────────────────

/// Parses the Markdown table produced by /api/shot-table into a list of shot maps.
/// Each map has keys matching the header row (e.g. '镜头号', '景别', '画面描述', …).
/// Returns [] if the text doesn't contain a valid table with at least one data row.
List<Map<String, String>> parseShotTable(String markdown) {
  // Collect lines that look like table rows
  final tableLines = markdown
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('|') && l.endsWith('|'))
      .toList();

  if (tableLines.length < 3) return []; // need header + separator + ≥1 row

  // Parse headers from first row
  final headers = _splitCells(tableLines[0]);

  // tableLines[1] is the separator row (|---|...) — skip it

  final shots = <Map<String, String>>[];
  for (var i = 2; i < tableLines.length; i++) {
    final cells = _splitCells(tableLines[i]);
    final map = <String, String>{};
    for (var j = 0; j < headers.length; j++) {
      map[headers[j]] = j < cells.length ? cells[j] : '';
    }
    if (map.isNotEmpty) shots.add(map);
  }
  return shots;
}

List<String> _splitCells(String row) {
  // Remove leading/trailing | then split on |
  final stripped = row.replaceAll(RegExp(r'^\||\|$'), '');
  return stripped.split('|').map((c) => c.trim()).toList();
}

/// Splits a prompt cell formatted as "中：[zh]  EN：[en]" (or "中:[zh] EN:[en]")
/// into its Chinese explanation and English AI prompt parts.
/// If the cell doesn't contain the pattern, returns the whole cell as [zh] with empty [en].
({String zh, String en}) splitPrompt(String cell) {
  // Normalise the full-width colon and trim
  final text = cell.replaceAll('：', ':').trim();
  final enIdx = text.indexOf(RegExp(r'EN\s*:'));
  if (enIdx == -1) return (zh: cell.trim(), en: '');

  String zh = text.substring(0, enIdx).trim();
  String en = text.substring(enIdx).trim();

  // Strip leading "中:" prefix from zh part
  zh = zh.replaceFirst(RegExp(r'^中\s*:\s*'), '').trim();
  // Strip leading "EN:" prefix from en part
  en = en.replaceFirst(RegExp(r'^EN\s*:\s*'), '').trim();

  return (zh: zh, en: en);
}

// ── Main view ─────────────────────────────────────────────────────────────────

/// Renders a list of parsed shot rows as mobile-friendly cards.
class ShotTableView extends ConsumerWidget {
  final List<Map<String, String>> shots;

  const ShotTableView({super.key, required this.shots});

  static const _shotTypeColors = {
    '特写': Color(0xFFef4444),
    '近景': Color(0xFFf59e0b),
    '中景': Color(0xFF6366f1),
    '远景': Color(0xFF10b981),
    '大远景': Color(0xFF3b82f6),
  };
  static const _defaultColor = Color(0xFF8b5cf6);

  Color _colorFor(String type) =>
      _shotTypeColors[type] ?? _defaultColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: shots.map((shot) {
        final shotNum = shot['镜头号'] ?? '';
        final type = shot['景别'] ?? '';
        final duration = shot['时长(秒)'] ?? shot['时长'] ?? '';
        final scene = shot['画面描述'] ?? '';
        final narration = shot['旁白/对白'] ?? shot['旁白'] ?? '';
        final notes = shot['备注'] ?? '';
        final ttiCell = shot['文生图提示词'] ?? '';
        final itvCell = shot['图生视频提示词'] ?? '';

        final color = _colorFor(type);
        final tti = splitPrompt(ttiCell);
        final itv = splitPrompt(itvCell);

        return _ShotCard(
          shotNum: shotNum,
          type: type,
          duration: duration,
          scene: scene,
          narration: narration,
          notes: notes,
          ttiZh: tti.zh,
          ttiEn: tti.en,
          itvZh: itv.zh,
          itvEn: itv.en,
          color: color,
          s: s,
        );
      }).toList(),
    );
  }
}

// ── Shot card ─────────────────────────────────────────────────────────────────

class _ShotCard extends StatelessWidget {
  final String shotNum;
  final String type;
  final String duration;
  final String scene;
  final String narration;
  final String notes;
  final String ttiZh;
  final String ttiEn;
  final String itvZh;
  final String itvEn;
  final Color color;
  final AppStrings s;

  const _ShotCard({
    required this.shotNum,
    required this.type,
    required this.duration,
    required this.scene,
    required this.narration,
    required this.notes,
    required this.ttiZh,
    required this.ttiEn,
    required this.itvZh,
    required this.itvEn,
    required this.color,
    required this.s,
  });

  bool _hasContent(String s) => s.isNotEmpty && s != '—' && s != '-';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: color.withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Shot number circle
                Container(
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    shotNum,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // 景别 chip
                if (_hasContent(type))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                if (_hasContent(type)) const SizedBox(width: 8),
                // Duration chip
                if (_hasContent(duration))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '$duration ${s.seconds}',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 画面描述
                if (_hasContent(scene))
                  _BodyField(
                    emoji: '🎬',
                    label: s.sceneLabel,
                    text: scene,
                    selectable: true,
                    textTheme: textTheme,
                  ),
                // 旁白/对白
                if (_hasContent(narration))
                  _BodyField(
                    emoji: '🎙',
                    label: s.dialogLabel,
                    text: narration,
                    selectable: true,
                    textTheme: textTheme,
                  ),
                // 备注
                if (_hasContent(notes))
                  _BodyField(
                    emoji: '📝',
                    label: s.notesLabel,
                    text: notes,
                    selectable: false,
                    textTheme: textTheme,
                  ),
              ],
            ),
          ),

          // ── AI prompts (collapsible) ───────────────────────────────────────
          if (_hasContent(ttiEn) || _hasContent(itvEn))
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                childrenPadding:
                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Row(children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    s.aiPromptsTitle,
                    style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ]),
                children: [
                  if (_hasContent(ttiEn))
                    _PromptField(
                      icon: '🖼',
                      label: s.textToImageLabel,
                      zh: ttiZh,
                      en: ttiEn,
                      textTheme: textTheme,
                      s: s,
                    ),
                  if (_hasContent(itvEn))
                    _PromptField(
                      icon: '🎥',
                      label: s.imageToVideoLabel,
                      zh: itvZh,
                      en: itvEn,
                      textTheme: textTheme,
                      s: s,
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── Body field ────────────────────────────────────────────────────────────────

class _BodyField extends StatelessWidget {
  final String emoji;
  final String label;
  final String text;
  final bool selectable;
  final TextTheme textTheme;

  const _BodyField({
    required this.emoji,
    required this.label,
    required this.text,
    required this.selectable,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: selectable
                ? SelectableText(text, style: textTheme.bodySmall)
                : Text(text, style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Prompt field (with copy button for EN) ────────────────────────────────────

class _PromptField extends StatelessWidget {
  final String icon;
  final String label;
  final String zh;
  final String en;
  final TextTheme textTheme;
  final AppStrings s;

  const _PromptField({
    required this.icon,
    required this.label,
    required this.zh,
    required this.en,
    required this.textTheme,
    required this.s,
  });

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: en));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.copiedPrompt(label)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(label,
                style: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          // Chinese/description explanation (if available)
          if (zh.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${s.zhPrefix}$zh',
                style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          // EN prompt + copy button
          if (en.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      en,
                      style: const TextStyle(
                          color: Color(0xFFa5b4fc),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: s.copyPromptTooltip,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
