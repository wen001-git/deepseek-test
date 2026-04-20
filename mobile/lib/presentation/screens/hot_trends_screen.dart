import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class HotTrendsScreen extends ConsumerStatefulWidget {
  const HotTrendsScreen({super.key});

  @override
  ConsumerState<HotTrendsScreen> createState() => _HotTrendsScreenState();
}

class _HotTrendsScreenState extends ConsumerState<HotTrendsScreen> {
  String _platform = 'weibo';
  bool _loading = false;
  List<dynamic> _data = [];
  String? _error;
  String? _ts;

  static const _platforms = [
    ('weibo', '微博'),
    ('bilibili', 'B站'),
    ('douyin', '抖音'),
    ('zhihu', '知乎'),
    ('baidu', '百度'),
    ('toutiao', '头条'),
  ];

  Future<void> _load({bool force = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiDataSourceProvider);
      final data = await api.get(ApiConstants.hotTrends, params: {
        'platform': _platform,
        if (force) 'force': '1',
      });
      setState(() {
        _data = (data['data'] as List?) ?? [];
        _ts = data['ts'] != null ? data['ts'].toString() : null;
        _error = data['error'] != null ? data['error'].toString() : null;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: Text(ref.watch(stringsProvider).hotTrendsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _platforms.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.$2),
                  selected: _platform == p.$1,
                  onSelected: (_) {
                    setState(() => _platform = p.$1);
                    _load();
                  },
                ),
              )).toList(),
            ),
          ),
          if (_ts != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${ref.watch(stringsProvider).updatedAt} $_ts',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          const SizedBox(height: 4),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _data.length,
                    itemBuilder: (ctx, i) {
                      final item = _data[i];
                      final title = item is Map ? (item['title'] ?? item['word'] ?? item.toString()) : item.toString();
                      final hot = item is Map ? (item['hot'] ?? item['heat'] ?? '') : '';
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(title.toString()),
                        trailing: hot.toString().isNotEmpty
                            ? Text(hot.toString(),
                                style: const TextStyle(color: Colors.orange, fontSize: 12))
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
