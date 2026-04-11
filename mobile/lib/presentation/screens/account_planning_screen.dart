/// 账号规划工作流 — 2-step workflow combining 定位分析 and 内容规划.
///
/// Step 1: 定位分析 (positioning analysis)
///   Inputs: industry, strengths, account_types, content_styles,
///           content_formats, platforms
///
/// Step 2: 内容规划 (content planning) — locked until Step 1 completes
///   Auto-filled: industry (from Step 1), target_audience (extracted from result)
///   Extra inputs: platform, followers, daily_hours
///   Payload includes: positioning_result from Step 1
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/api_constants.dart';
import '../widgets/streaming_widget.dart';
import '../widgets/content_plan_view.dart';

class AccountPlanningScreen extends ConsumerStatefulWidget {
  const AccountPlanningScreen({super.key});
  @override
  ConsumerState<AccountPlanningScreen> createState() =>
      _AccountPlanningScreenState();
}

class _AccountPlanningScreenState
    extends ConsumerState<AccountPlanningScreen> {
  // ── Step 1 inputs ────────────────────────────────────────────────────────
  final _industryCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  List<String> _accountTypes = [];
  List<String> _contentStyles = [];
  List<String> _contentFormats = [];
  List<String> _platforms = [];

  static const _accountTypeOptions = ['个人品牌', '企业号', '品牌号', '机构号'];
  static const _contentStyleOptions = [
    '干货知识', '真实经历', '生活场景', '特技风格', '励志鸡汤', '热点追踪'
  ];
  static const _contentFormatOptions = ['口播', 'Vlog', '知识讲解', '剧情', '测评', '教程'];
  static const _platformOptions = ['抖音', 'B站', '小红书', '视频号', 'YouTube'];

  // ── Step 1 result ────────────────────────────────────────────────────────
  final _step1Key = GlobalKey<StreamingWidgetState>();
  bool _step1Done = false;
  String _positioningResult = '';

  // ── Step 2 inputs ────────────────────────────────────────────────────────
  final _cpIndustryCtrl = TextEditingController();
  final _cpAudienceCtrl = TextEditingController();
  String _cpPlatform = '抖音';
  String _cpFollowers = '0 - 1千';
  String _cpDailyHours = '1-2小时';

  static const _cpPlatforms = ['抖音', 'B站', '小红书', '视频号', 'YouTube'];
  static const _cpFollowerRanges = [
    '0 - 1千', '1千 - 1万', '1万 - 10万', '10万以上'
  ];
  static const _cpDailyHoursOptions = [
    '0.5小时内', '1-2小时', '2-4小时', '4小时以上'
  ];

  // ── Step 2 result ────────────────────────────────────────────────────────
  final _step2Key = GlobalKey<StreamingWidgetState>(); // controls StreamingWidget
  final _step2CardKey = GlobalKey(); // used only for scroll-into-view
  bool _step2Done = false;
  Map<String, dynamic>? _step2Plan;
  int _step2StreamingChars = 0;

  @override
  void dispose() {
    _industryCtrl.dispose();
    _strengthsCtrl.dispose();
    _cpIndustryCtrl.dispose();
    _cpAudienceCtrl.dispose();
    super.dispose();
  }

  void _submitStep1() {
    if (_industryCtrl.text.trim().isEmpty ||
        _strengthsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写行业领域和特长优势')));
      return;
    }
    // Dismiss keyboard first, then start streaming after the IME hide
    // animation completes (~300 ms) to avoid compositor jank.
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _step1Key.currentState?.start();
    });
  }

  void _onStep1Complete(String text) {
    // Auto-fill Step 2
    _cpIndustryCtrl.text = _industryCtrl.text.trim();

    // Extract 目标人群 from result text.
    // The AI outputs: "4. 【目标人群】：<description>\n\n5. **【起步建议】"
    // The regex captures everything from 】 to the next 【, so it includes
    // the trailing "5. **" before the next section header. We clean that up
    // below and force the cursor to position 0 so the field shows the start.
    final audienceMatch =
        RegExp(r'【目标人群[^】]*】([^【]+)').firstMatch(text);
    if (audienceMatch != null) {
      String audience = audienceMatch.group(1)!.trim();
      // Strip leading colon/semicolon that the AI appends to section headers
      audience = audience.replaceFirst(RegExp(r'^[：:；;]\s*'), '');
      // Strip trailing numbered section marker, e.g. "\n5. **" or "\n5. "
      audience = audience
          .replaceFirst(RegExp(r'\n+\s*\d+[\.\s][^\n]*$'), '')
          .trim();
      if (audience.isNotEmpty) {
        // Set cursor to start so maxLines:2 shows the beginning, not the end
        _cpAudienceCtrl.value = TextEditingValue(
          text: audience,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    }

    setState(() {
      _positioningResult = text;
      _step1Done = true;
    });

    // Scroll to step 2 after a brief delay
    Future.delayed(const Duration(milliseconds: 400), () {
      Scrollable.ensureVisible(
        _step2CardKey.currentContext ?? context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _submitStep2() {
    if (_cpIndustryCtrl.text.trim().isEmpty ||
        _cpPlatform.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写行业领域和目标平台')));
      return;
    }
    setState(() { _step2Plan = null; _step2StreamingChars = 0; });
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _step2Key.currentState?.start();
    });
  }

  void _onStep2Complete(String text) {
    setState(() => _step2Done = true);
    try {
      var s = text
          .replaceFirst(RegExp(r'^\[DEBUG:[\s\S]*?:DEBUG\]\n'), '')
          .trim();
      if (s.startsWith('```')) {
        s = s
            .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '')
            .trim();
      }
      final plan = jsonDecode(s) as Map<String, dynamic>;
      setState(() { _step2Plan = plan; _step2StreamingChars = 0; });
    } catch (_) {
      setState(() => _step2StreamingChars = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('账号规划工作流'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Stepper ─────────────────────────────────────────────────
            _WorkflowStepper(step1Done: _step1Done, step2Done: _step2Done),
            const SizedBox(height: 20),

            // ════════════════════════════════════════════════════════════
            // STEP 1 — 定位分析
            // ════════════════════════════════════════════════════════════
            _StepCard(
              stepNumber: 1,
              title: '定位分析',
              subtitle: '分析账号定位、目标人群和内容方向',
              isDone: _step1Done,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _industryCtrl,
                    decoration: const InputDecoration(
                      labelText: '行业领域 *',
                      hintText: '例如：健身、美食、教育、时尚',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _strengthsCtrl,
                    decoration: const InputDecoration(
                      labelText: '特长优势 *',
                      hintText: '例如：专业健身教练，10年从业经验',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _ChipGroup(
                    label: '账号类型',
                    options: _accountTypeOptions,
                    selected: _accountTypes,
                    multiSelect: true,
                    onChanged: (v) => setState(() => _accountTypes = v),
                  ),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    label: '内容风格偏好',
                    options: _contentStyleOptions,
                    selected: _contentStyles,
                    multiSelect: true,
                    onChanged: (v) => setState(() => _contentStyles = v),
                  ),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    label: '内容形式偏好',
                    options: _contentFormatOptions,
                    selected: _contentFormats,
                    multiSelect: true,
                    onChanged: (v) => setState(() => _contentFormats = v),
                  ),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    label: '目标平台',
                    options: _platformOptions,
                    selected: _platforms,
                    multiSelect: true,
                    onChanged: (v) => setState(() => _platforms = v),
                  ),
                  const SizedBox(height: 16),
                  StreamingWidget(
                    key: _step1Key,
                    title: '定位分析',
                    isAdmin: auth.isAdmin,
                    onComplete: _onStep1Complete,
                    streamBuilder: (model) =>
                        api.streamPost(ApiConstants.positioning, {
                      'industry': _industryCtrl.text.trim(),
                      'strengths': _strengthsCtrl.text.trim(),
                      'account_types': _accountTypes,
                      'content_styles': _contentStyles,
                      'content_formats': _contentFormats,
                      'platforms': _platforms,
                      'model': model,
                    }),
                  ),
                  FilledButton.icon(
                    onPressed: _submitStep1,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('开始定位分析'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ════════════════════════════════════════════════════════════
            // STEP 2 — 内容规划 (locked until step 1 completes)
            // ════════════════════════════════════════════════════════════
            _StepCard(
              key: _step2CardKey,
              stepNumber: 2,
              title: '内容规划',
              subtitle: '基于定位分析结果，制定内容发布计划',
              isDone: _step2Done,
              locked: !_step1Done,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _cpIndustryCtrl,
                    enabled: _step1Done,
                    decoration: const InputDecoration(
                      labelText: '行业领域',
                      hintText: '自动填入（来自步骤一）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpAudienceCtrl,
                    enabled: _step1Done,
                    decoration: const InputDecoration(
                      labelText: '目标受众',
                      hintText: '自动提取（来自定位分析结果）',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _cpPlatform,
                    decoration: const InputDecoration(labelText: '目标平台'),
                    items: _cpPlatforms
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: _step1Done
                        ? (v) => setState(() => _cpPlatform = v!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _cpFollowers,
                    decoration: const InputDecoration(labelText: '当前粉丝量'),
                    items: _cpFollowerRanges
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: _step1Done
                        ? (v) => setState(() => _cpFollowers = v!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _cpDailyHours,
                    decoration: const InputDecoration(labelText: '每日可用时间'),
                    items: _cpDailyHoursOptions
                        .map((h) =>
                            DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: _step1Done
                        ? (v) => setState(() => _cpDailyHours = v!)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_step1Done) ...[
                    if (_step2Plan == null)
                      StreamingWidget(
                        key: _step2Key,
                        title: '内容规划',
                        isAdmin: auth.isAdmin,
                        onComplete: _onStep2Complete,
                        onProgress: (n) =>
                            setState(() => _step2StreamingChars = n),
                        streamBuilder: (model) =>
                            api.streamPost(ApiConstants.contentPlan, {
                          'industry': _cpIndustryCtrl.text.trim(),
                          'platform': _cpPlatform,
                          'followers': _cpFollowers,
                          'daily_hours': _cpDailyHours,
                          'positioning_result': _positioningResult,
                          'target_audience': _cpAudienceCtrl.text.trim(),
                          'model': model,
                        }),
                      ),
                    if (_step2Plan != null)
                      ContentPlanView(plan: _step2Plan!),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _step2StreamingChars > 0 ? null : _submitStep2,
                      icon: _step2StreamingChars > 0
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.calendar_month),
                      label: Text(_step2StreamingChars > 0
                          ? '生成中 $_step2StreamingChars 字...'
                          : (_step2Plan != null ? '重新生成' : '生成内容规划')),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              color: colorScheme.outline, size: 16),
                          const SizedBox(width: 6),
                          Text('完成步骤一后解锁',
                              style: TextStyle(color: colorScheme.outline)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Stepper ───────────────────────────────────────────────────────────────────

class _WorkflowStepper extends StatelessWidget {
  final bool step1Done;
  final bool step2Done;
  const _WorkflowStepper({required this.step1Done, required this.step2Done});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(children: [
      _StepCircle(number: 1, done: step1Done, active: !step1Done),
      Expanded(
        child: Container(
          height: 2,
          color: step1Done ? primary : Colors.grey.shade300,
        ),
      ),
      _StepCircle(number: 2, done: step2Done, active: step1Done),
    ]);
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final bool done;
  final bool active;
  const _StepCircle(
      {required this.number, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = done
        ? primary
        : active
            ? primary
            : Colors.grey.shade300;
    final fg = done || active ? Colors.white : Colors.grey;

    return Column(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text('$number',
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        number == 1 ? '定位分析' : '内容规划',
        style: TextStyle(
            fontSize: 11,
            color: (done || active) ? primary : Colors.grey,
            fontWeight: (done || active) ? FontWeight.w600 : FontWeight.normal),
      ),
    ]);
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool locked;
  final Widget child;

  const _StepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isDone,
    this.locked = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: locked ? 0 : 2,
      color: locked ? colorScheme.surfaceContainerHighest.withOpacity(0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: locked
                      ? Colors.grey.shade300
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Step $stepNumber',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: locked
                          ? Colors.grey
                          : colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: locked ? colorScheme.outline : null)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.outline)),
                ]),
              ),
              if (isDone)
                Icon(Icons.check_circle,
                    color: colorScheme.primary, size: 20),
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Chip group (single or multi-select) ──────────────────────────────────────

class _ChipGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final bool multiSelect;
  final void Function(List<String>) onChanged;

  const _ChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.multiSelect,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 13)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          return FilterChip(
            label: Text(opt, style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            onSelected: (v) {
              final next = List<String>.from(selected);
              if (!multiSelect) {
                next.clear();
                if (v) next.add(opt);
              } else {
                if (v) {
                  next.add(opt);
                } else {
                  next.remove(opt);
                }
              }
              onChanged(next);
            },
          );
        }).toList(),
      ),
    ]);
  }
}
