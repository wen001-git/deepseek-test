/// All AI feature screens.
/// Each screen uses StreamingWidget which now owns the model selector
/// (快速生成 / 深度思考) and the admin Prompt Debug panel.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/api_constants.dart';
import '../widgets/streaming_widget.dart';
import '../widgets/content_plan_view.dart';

// ── 1. 脚本制作 ────────────────────────────────────────────────────────────────

class ScriptScreen extends ConsumerStatefulWidget {
  const ScriptScreen({super.key});
  @override
  ConsumerState<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends ConsumerState<ScriptScreen> {
  final _topicCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  String _type = '通用';
  String _style = '幽默';
  int _duration = 60;
  String _scriptResult = '';

  static const _types = ['通用', '知识科普', '生活记录', '剧情故事', '产品测评', '才艺展示'];
  static const _styles = ['幽默', '治愈', '励志', '悬疑', '温情', '干货'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('脚本制作'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_topicCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入视频主题')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成脚本'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                  labelText: '视频主题 *', hintText: '例如：如何在30天内减掉10斤'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: '视频类型'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _style,
              decoration: const InputDecoration(labelText: '内容风格'),
              items: _styles
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _style = v!),
            ),
            const SizedBox(height: 12),
            Text('时长：$_duration 秒'),
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 300,
              divisions: 19,
              label: '$_duration秒',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '脚本制作',
              isAdmin: auth.isAdmin,
              onComplete: (text) => setState(() => _scriptResult = text),
              streamBuilder: (model) => api.streamPost(ApiConstants.script, {
                'topic': _topicCtrl.text.trim(),
                'type': _type,
                'style': _style,
                'duration': _duration,
                'model': model,
              }),
            ),
            // 生成分镜拍摄表 — appears after script is generated
            if (_scriptResult.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/shot-table', extra: _scriptResult),
                  icon: const Icon(Icons.view_list_outlined),
                  label: const Text('生成分镜拍摄表'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 2. 分镜拍摄表 ──────────────────────────────────────────────────────────────
// Route kept for direct navigation from ScriptScreen (passes script via extra).

class ShotTableScreen extends ConsumerStatefulWidget {
  final String? initialScript;
  const ShotTableScreen({super.key, this.initialScript});
  @override
  ConsumerState<ShotTableScreen> createState() => _ShotTableScreenState();
}

class _ShotTableScreenState extends ConsumerState<ShotTableScreen> {
  late final _scriptCtrl =
      TextEditingController(text: widget.initialScript ?? '');
  final _streamKey = GlobalKey<StreamingWidgetState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('分镜拍摄表'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_scriptCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请粘贴视频脚本')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成分镜表'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _scriptCtrl,
              decoration: const InputDecoration(
                  labelText: '视频脚本 *', hintText: '粘贴已生成的脚本内容'),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '分镜拍摄表',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.shotTable, {
                'script': _scriptCtrl.text.trim(),
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3. 定位分析 (standalone, kept for backward compat) ────────────────────────

class PositioningScreen extends ConsumerStatefulWidget {
  const PositioningScreen({super.key});
  @override
  ConsumerState<PositioningScreen> createState() => _PositioningScreenState();
}

class _PositioningScreenState extends ConsumerState<PositioningScreen> {
  final _industryCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  List<String> _platforms = [];
  List<String> _contentFormats = [];

  static const _platformOptions = ['抖音', 'B站', '小红书', '视频号', 'YouTube'];
  static const _formatOptions = ['口播', 'Vlog', '知识讲解', '剧情', '测评', '教程'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('定位分析'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_industryCtrl.text.trim().isEmpty ||
              _strengthsCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请填写行业领域和特长优势')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始分析'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _industryCtrl,
              decoration: const InputDecoration(
                  labelText: '行业领域 *', hintText: '例如：健身、美食、教育'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _strengthsCtrl,
              decoration: const InputDecoration(
                  labelText: '特长优势 *', hintText: '例如：专业健身教练、10年经验'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            const Text('目标平台', style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              children: _platformOptions
                  .map((p) => FilterChip(
                        label: Text(p),
                        selected: _platforms.contains(p),
                        onSelected: (v) => setState(
                            () => v ? _platforms.add(p) : _platforms.remove(p)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text('内容形式', style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              children: _formatOptions
                  .map((f) => FilterChip(
                        label: Text(f),
                        selected: _contentFormats.contains(f),
                        onSelected: (v) => setState(() => v
                            ? _contentFormats.add(f)
                            : _contentFormats.remove(f)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '定位分析',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.positioning, {
                'industry': _industryCtrl.text.trim(),
                'strengths': _strengthsCtrl.text.trim(),
                'platforms': _platforms,
                'content_formats': _contentFormats,
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 4. 爆款选题 ────────────────────────────────────────────────────────────────

class ViralTopicsScreen extends ConsumerStatefulWidget {
  const ViralTopicsScreen({super.key});
  @override
  ConsumerState<ViralTopicsScreen> createState() => _ViralTopicsScreenState();
}

class _ViralTopicsScreenState extends ConsumerState<ViralTopicsScreen> {
  final _industryCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  String _platform = '抖音';
  String? _contentDirection;
  List<String> _viralElements = [];

  static const _platforms = ['抖音', 'B站', '小红书', '视频号', 'YouTube'];
  static const _directions = ['晒过程', '讲故事', '教知识', '聊观点'];
  static const _elements = [
    '成本的', '人群的', '奇葩的', '最差的', '怀旧的', '荷尔蒙的', '头牌的', '颜值的'
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('爆款选题'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_industryCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入赛道领域')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成选题'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _industryCtrl,
              decoration: const InputDecoration(
                  labelText: '赛道领域 *', hintText: '例如：职场成长、健身减脂'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _strengthsCtrl,
              decoration: const InputDecoration(
                  labelText: '特长优势（可选）', hintText: '例如：健身教练、10年经验'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _platform,
              decoration: const InputDecoration(labelText: '目标平台'),
              items: _platforms
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: 12),
            const Text('内容方向（单选）',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _directions
                  .map((d) => ChoiceChip(
                        label: Text(d),
                        selected: _contentDirection == d,
                        onSelected: (v) => setState(() =>
                            _contentDirection = v ? d : null),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('爆款元素（可多选）',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _elements
                  .map((e) => FilterChip(
                        label: Text(e),
                        selected: _viralElements.contains(e),
                        onSelected: (v) => setState(() =>
                            v ? _viralElements.add(e) : _viralElements.remove(e)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '爆款选题',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.viralTopics, {
                'industry': _industryCtrl.text.trim(),
                'strengths': _strengthsCtrl.text.trim(),
                'platform': _platform,
                'content_direction': _contentDirection ?? '',
                'viral_elements': _viralElements,
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5. 变现选题 ────────────────────────────────────────────────────────────────

class MonetizeTopicsScreen extends ConsumerStatefulWidget {
  const MonetizeTopicsScreen({super.key});
  @override
  ConsumerState<MonetizeTopicsScreen> createState() =>
      _MonetizeTopicsScreenState();
}

class _MonetizeTopicsScreenState extends ConsumerState<MonetizeTopicsScreen> {
  final _industryCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  String _followers = '0 - 1千';
  String? _monetizeDirection;
  List<String> _contentTone = [];

  static const _followerRanges = [
    '0 - 1千', '1千 - 1万', '1万 - 10万', '10万 - 100万', '100万以上'
  ];
  static const _directions = ['广告接单', '带货变现', '知识付费', '私域引流', '直播带货'];
  static const _toneOptions = ['种草氛围', '专业信任', '生活场景', '测评对比', '教程干货'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('变现选题'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_industryCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入赛道领域')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成选题'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _industryCtrl,
              decoration: const InputDecoration(labelText: '赛道领域 *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _strengthsCtrl,
              decoration: const InputDecoration(
                  labelText: '特长优势（可选）', hintText: '例如：10年销售经验'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _followers,
              decoration: const InputDecoration(labelText: '粉丝量'),
              items: _followerRanges
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _followers = v!),
            ),
            const SizedBox(height: 12),
            const Text('变现方向（单选）',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _directions
                  .map((d) => ChoiceChip(
                        label: Text(d),
                        selected: _monetizeDirection == d,
                        onSelected: (v) => setState(
                            () => _monetizeDirection = v ? d : null),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('内容基调（可多选）',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _toneOptions
                  .map((t) => FilterChip(
                        label: Text(t),
                        selected: _contentTone.contains(t),
                        onSelected: (v) => setState(() =>
                            v ? _contentTone.add(t) : _contentTone.remove(t)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '变现选题',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.monetizeTopics, {
                'industry': _industryCtrl.text.trim(),
                'strengths': _strengthsCtrl.text.trim(),
                'followers': _followers,
                'monetize_direction': _monetizeDirection ?? '',
                'content_tone': _contentTone,
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 6. 文案二创 ────────────────────────────────────────────────────────────────

class RewriteScreen extends ConsumerStatefulWidget {
  const RewriteScreen({super.key});
  @override
  ConsumerState<RewriteScreen> createState() => _RewriteScreenState();
}

class _RewriteScreenState extends ConsumerState<RewriteScreen> {
  final _originalCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('文案二创'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_originalCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请粘贴原始文案')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始二创'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _originalCtrl,
              decoration: const InputDecoration(
                  labelText: '原始文案 *', hintText: '粘贴要改写的视频文案'),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '文案二创',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) => api.streamPost(ApiConstants.rewrite, {
                'original': _originalCtrl.text.trim(),
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 7. 爆款拆解 ────────────────────────────────────────────────────────────────
// 3 modes: URL链接, 搜索视频, 手动输入 (matching web)

enum _BreakdownMode { url, search, manual }

class BreakdownScreen extends ConsumerStatefulWidget {
  const BreakdownScreen({super.key});
  @override
  ConsumerState<BreakdownScreen> createState() => _BreakdownScreenState();
}

class _BreakdownScreenState extends ConsumerState<BreakdownScreen> {
  _BreakdownMode _mode = _BreakdownMode.url;

  // URL mode
  final _urlCtrl = TextEditingController();

  // Search mode
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<dynamic> _searchResults = [];
  String? _searchError;

  // Manual mode
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  final _streamKey = GlobalKey<StreamingWidgetState>();

  Future<void> _searchVideos() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final api = ref.read(apiDataSourceProvider);
      final data = await api.post(
          ApiConstants.searchViral, {'topic': _searchCtrl.text.trim()});
      setState(() {
        _searchResults = (data['results'] as List?) ?? [];
        _searchError = data['error'] as String?;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> r) {
    // Fill manual fields and switch to stream
    _titleCtrl.text = r['title'] as String? ?? '';
    _contentCtrl.text =
        '来源：${r['platform'] ?? ''}\n${r['snippet'] ?? ''}';
    setState(() => _mode = _BreakdownMode.manual);
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    switch (_mode) {
      case _BreakdownMode.url:
        if (_urlCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请输入视频链接或分享文案')));
          return;
        }
      case _BreakdownMode.search:
        if (_titleCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先搜索并选择一个视频')));
          return;
        }
      case _BreakdownMode.manual:
        if (_titleCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请输入视频标题')));
          return;
        }
    }
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _streamKey.currentState?.start(); });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('爆款拆解'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generate,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始拆解'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode selector
            SegmentedButton<_BreakdownMode>(
              segments: const [
                ButtonSegment(
                    value: _BreakdownMode.url,
                    icon: Icon(Icons.link, size: 14),
                    label: Text('链接解析', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: _BreakdownMode.search,
                    icon: Icon(Icons.search, size: 14),
                    label: Text('搜索视频', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: _BreakdownMode.manual,
                    icon: Icon(Icons.edit_outlined, size: 14),
                    label: Text('手动输入', style: TextStyle(fontSize: 12))),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),

            // ── URL mode ───────────────────────────────────────────────
            if (_mode == _BreakdownMode.url) ...[
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: '视频链接或分享文案 *',
                  hintText: '粘贴抖音/B站/小红书链接或分享文案',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                '支持：抖音、B站、小红书、视频号链接',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline),
              ),
            ],

            // ── Search mode ────────────────────────────────────────────
            if (_mode == _BreakdownMode.search) ...[
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                        labelText: '搜索关键词', hintText: '例如：减肥、副业赚钱'),
                    onFieldSubmitted: (_) => _searchVideos(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _searchVideos, child: const Text('搜索')),
              ]),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_searchError!,
                      style: const TextStyle(color: Colors.red)),
                ),
              ..._searchResults.map((r) {
                final result = r as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        (result['platform'] as String? ?? '?')[0],
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(result['title'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        '${result['platform'] ?? ''} · ${result['view_count'] ?? ''}播放',
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () => _selectSearchResult(result),
                  ),
                );
              }),
            ],

            // ── Manual mode ─────────────────────────────────────────────
            if (_mode == _BreakdownMode.manual) ...[
              TextFormField(
                controller: _titleCtrl,
                decoration:
                    const InputDecoration(labelText: '视频标题 *'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                    labelText: '视频内容（可选）', hintText: '粘贴视频文案或内容描述'),
                maxLines: 4,
              ),
            ],

            const SizedBox(height: 16),

            // Streaming output
            StreamingWidget(
              key: _streamKey,
              title: '爆款拆解',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) {
                if (_mode == _BreakdownMode.url) {
                  return api.streamPost(ApiConstants.breakdownSharetext, {
                    'sharetext': _urlCtrl.text.trim(),
                    'model': model,
                  });
                }
                return api.streamPost(ApiConstants.breakdown, {
                  'title': _titleCtrl.text.trim(),
                  'content': _contentCtrl.text.trim(),
                  'model': model,
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 8. 爆款仿写 ────────────────────────────────────────────────────────────────

class ImitateScreen extends ConsumerStatefulWidget {
  const ImitateScreen({super.key});
  @override
  ConsumerState<ImitateScreen> createState() => _ImitateScreenState();
}

class _ImitateScreenState extends ConsumerState<ImitateScreen> {
  final _refTitleCtrl = TextEditingController();
  final _myTopicCtrl = TextEditingController();
  final _refContentCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  String _style = '幽默';
  int _duration = 60;
  String _scriptResult = '';

  static const _styles = ['幽默', '治愈', '励志', '悬疑', '温情', '干货'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('爆款仿写'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_refTitleCtrl.text.trim().isEmpty ||
              _myTopicCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请填写参考视频标题和你的话题')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始仿写'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _refTitleCtrl,
              decoration:
                  const InputDecoration(labelText: '参考视频标题 *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _refContentCtrl,
              decoration:
                  const InputDecoration(labelText: '参考视频内容（可选）'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _myTopicCtrl,
              decoration: const InputDecoration(
                  labelText: '我的话题 *', hintText: '例如：如何快速学会吉他'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _style,
              decoration: const InputDecoration(labelText: '风格'),
              items: _styles
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _style = v!),
            ),
            const SizedBox(height: 12),
            Text('时长：$_duration 秒'),
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 300,
              divisions: 19,
              label: '$_duration秒',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '爆款仿写',
              isAdmin: auth.isAdmin,
              onComplete: (text) => setState(() => _scriptResult = text),
              streamBuilder: (model) => api.streamPost(ApiConstants.imitate, {
                'ref_title': _refTitleCtrl.text.trim(),
                'ref_content': _refContentCtrl.text.trim(),
                'my_topic': _myTopicCtrl.text.trim(),
                'style': _style,
                'duration': _duration,
                'model': model,
              }),
            ),
            // 生成分镜拍摄表 — appears after imitation is generated
            if (_scriptResult.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/shot-table', extra: _scriptResult),
                  icon: const Icon(Icons.view_list_outlined),
                  label: const Text('生成分镜拍摄表'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 9. 视频搜索 (standalone, kept for backward compat) ────────────────────────

class SearchViralScreen extends ConsumerStatefulWidget {
  const SearchViralScreen({super.key});
  @override
  ConsumerState<SearchViralScreen> createState() => _SearchViralScreenState();
}

class _SearchViralScreenState extends ConsumerState<SearchViralScreen> {
  final _topicCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _results = [];
  String? _error;

  Future<void> _search() async {
    if (_topicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入搜索关键词')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final api = ref.read(apiDataSourceProvider);
      final data = await api.post(
          ApiConstants.searchViral, {'topic': _topicCtrl.text.trim()});
      setState(() {
        _results = (data['results'] as List?) ?? [];
        _error = data['error'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('视频搜索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _topicCtrl,
                  decoration: const InputDecoration(
                      labelText: '搜索关键词', hintText: '例如：减肥、副业赚钱'),
                  onFieldSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('搜索')),
            ]),
          ),
          if (_loading) const CircularProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (r['platform'] as String? ?? '?')[0],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(r['title'] as String? ?? '',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${r['platform'] ?? ''} · ${r['view_count'] ?? ''} 播放',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 10. 分享拆解 (standalone, kept for backward compat) ───────────────────────

class BreakdownSharetextScreen extends ConsumerStatefulWidget {
  const BreakdownSharetextScreen({super.key});
  @override
  ConsumerState<BreakdownSharetextScreen> createState() =>
      _BreakdownSharetextScreenState();
}

class _BreakdownSharetextScreenState
    extends ConsumerState<BreakdownSharetextScreen> {
  final _sharetextCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('分享拆解'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_sharetextCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请粘贴视频链接或分享文案')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始拆解'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _sharetextCtrl,
              decoration: const InputDecoration(
                labelText: '视频链接或分享文案 *',
                hintText: '粘贴抖音/B站/小红书视频链接或分享文案',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '分享拆解',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.breakdownSharetext, {
                'sharetext': _sharetextCtrl.text.trim(),
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 11. 编导专栏 ───────────────────────────────────────────────────────────────

class DirectorScreen extends ConsumerStatefulWidget {
  const DirectorScreen({super.key});
  @override
  ConsumerState<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends ConsumerState<DirectorScreen> {
  final _topicCtrl = TextEditingController();
  final _sceneCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  List<String> _equipment = ['仅手机'];

  static const _equipmentOptions = [
    '仅手机', '手机+补光灯', '相机', '专业摄像机', '无人机'
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('编导专栏'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_topicCtrl.text.trim().isEmpty ||
              _sceneCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请填写视频主题和拍摄场景')));
            return;
          }
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _streamKey.currentState?.start(); });
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成建议'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _topicCtrl,
              decoration: const InputDecoration(labelText: '视频主题 *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sceneCtrl,
              decoration: const InputDecoration(
                  labelText: '拍摄场景 *', hintText: '例如：室内卧室、户外公园'),
            ),
            const SizedBox(height: 12),
            const Text('拍摄设备', style: TextStyle(fontWeight: FontWeight.w500)),
            Wrap(
              spacing: 8,
              children: _equipmentOptions
                  .map((e) => FilterChip(
                        label: Text(e),
                        selected: _equipment.contains(e),
                        onSelected: (v) => setState(() =>
                            v ? _equipment.add(e) : _equipment.remove(e)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            StreamingWidget(
              key: _streamKey,
              title: '编导专栏',
              isAdmin: auth.isAdmin,
              streamBuilder: (model) =>
                  api.streamPost(ApiConstants.director, {
                'topic': _topicCtrl.text.trim(),
                'scene': _sceneCtrl.text.trim(),
                'equipment': _equipment,
                'model': model,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 12. 内容规划 (standalone, kept for backward compat) ───────────────────────

class ContentPlanScreen extends ConsumerStatefulWidget {
  const ContentPlanScreen({super.key});
  @override
  ConsumerState<ContentPlanScreen> createState() => _ContentPlanScreenState();
}

class _ContentPlanScreenState extends ConsumerState<ContentPlanScreen> {
  final _industryCtrl = TextEditingController();
  final _streamKey = GlobalKey<StreamingWidgetState>();
  String _platform = '抖音';
  String _followers = '0 - 1千';
  String _dailyHours = '1-2小时';

  // Visualization state
  Map<String, dynamic>? _parsedPlan;
  int _streamingChars = 0;

  static const _platforms = ['抖音', 'B站', '小红书', '视频号', 'YouTube'];
  static const _followerRanges = ['0 - 1千', '1千 - 1万', '1万 - 10万', '10万以上'];
  static const _dailyHoursOptions = ['0.5小时内', '1-2小时', '2-4小时', '4小时以上'];

  @override
  void dispose() {
    _industryCtrl.dispose();
    super.dispose();
  }

  void _onPlanComplete(String text) {
    try {
      // Strip optional admin debug prefix
      var s = text
          .replaceFirst(RegExp(r'^\[DEBUG:[\s\S]*?:DEBUG\]\n'), '')
          .trim();
      // Strip markdown code fences the model sometimes wraps JSON in
      if (s.startsWith('```')) {
        s = s
            .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '')
            .trim();
      }
      final plan = jsonDecode(s) as Map<String, dynamic>;
      setState(() {
        _parsedPlan = plan;
        _streamingChars = 0;
      });
    } catch (_) {
      // JSON parse failed — keep raw streaming widget visible so user sees output
      setState(() => _streamingChars = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final api = ref.read(apiDataSourceProvider);
    final streaming = _streamingChars > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
        title: const Text('内容规划'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: streaming
            ? null // disabled while generating
            : () {
                if (_industryCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写行业领域')));
                  return;
                }
                setState(() { _parsedPlan = null; _streamingChars = 0; });
                FocusScope.of(context).unfocus();
                Future.delayed(const Duration(milliseconds: 300),
                    () { if (mounted) _streamKey.currentState?.start(); });
              },
        icon: streaming
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.calendar_month),
        label: Text(streaming
            ? '生成中 $_streamingChars 字...'
            : (_parsedPlan != null ? '重新生成' : '生成内容规划')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _industryCtrl,
              enabled: !streaming,
              decoration: const InputDecoration(labelText: '行业领域 *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _platform,
              decoration: const InputDecoration(labelText: '目标平台'),
              items: _platforms
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: streaming ? null : (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _followers,
              decoration: const InputDecoration(labelText: '当前粉丝量'),
              items: _followerRanges
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: streaming ? null : (v) => setState(() => _followers = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _dailyHours,
              decoration: const InputDecoration(labelText: '每日可用时间'),
              items: _dailyHoursOptions
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: streaming ? null : (v) => setState(() => _dailyHours = v!),
            ),
            const SizedBox(height: 16),

            // StreamingWidget handles the API call; hidden once plan is parsed
            if (_parsedPlan == null)
              StreamingWidget(
                key: _streamKey,
                title: '内容规划',
                isAdmin: auth.isAdmin,
                onComplete: _onPlanComplete,
                onProgress: (n) => setState(() => _streamingChars = n),
                streamBuilder: (model) =>
                    api.streamPost(ApiConstants.contentPlan, {
                  'industry': _industryCtrl.text.trim(),
                  'platform': _platform,
                  'followers': _followers,
                  'daily_hours': _dailyHours,
                  'model': model,
                }),
              ),

            // Visualization shown after successful JSON parse
            if (_parsedPlan != null)
              ContentPlanView(plan: _parsedPlan!),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
