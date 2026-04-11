import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  final bool adminOnly;
  const _NavItem(this.route, this.icon, this.label, {this.adminOnly = false});
}

// Grid matches the web sidebar exactly:
// 账号规划(workflow), 爆款选题, 变现选题, 脚本制作, 文案二创,
// 爆款拆解, 爆款仿写, 编导专栏, 热点追踪(admin)
const _items = [
  _NavItem('/account-planning', Icons.route_outlined, '账号规划'),
  _NavItem('/viral-topics', Icons.trending_up, '爆款选题'),
  _NavItem('/monetize-topics', Icons.monetization_on_outlined, '变现选题'),
  _NavItem('/script', Icons.article_outlined, '脚本制作'),
  _NavItem('/rewrite', Icons.edit_note, '文案二创'),
  _NavItem('/breakdown', Icons.analytics_outlined, '爆款拆解'),
  _NavItem('/imitate', Icons.copy_outlined, '爆款仿写'),
  _NavItem('/director', Icons.movie_creation_outlined, '编导专栏'),
  _NavItem('/hot-trends', Icons.whatshot_outlined, '热点追踪', adminOnly: true),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final visibleItems = _items.where((i) => !i.adminOnly || auth.isAdmin).toList();
    final titles = ['短视频创作助手', '我的账号'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          // Tab 0: 14-feature grid
          _FeaturesGrid(items: visibleItems),
          // Tab 1: Profile
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: '工具箱',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

// ── Feature grid ──────────────────────────────────────────────────────────────

class _FeaturesGrid extends StatelessWidget {
  final List<_NavItem> items;
  const _FeaturesGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: items.map((item) => _FeatureCard(item: item)).toList(),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _NavItem item;
  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 36, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile tab (inline — no separate route needed) ───────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final tierName = AppConstants.tierNames[auth.tier] ?? auth.tier;
    final dailyLimit = auth.dailyLimit;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                auth.username.isNotEmpty ? auth.username[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 36,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(auth.username,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            _InfoTile(label: '账号类型', value: auth.role == 'admin' ? '管理员' : '普通用户'),
            const Divider(height: 1),
            _InfoTile(
                label: '订阅套餐',
                value: tierName,
                valueColor: Theme.of(context).colorScheme.primary),
            const Divider(height: 1),
            _InfoTile(label: '每日生成次数', value: '$dailyLimit 次'),
            if (auth.expiresAt != null) ...[
              const Divider(height: 1),
              _InfoTile(label: '到期时间', value: auth.expiresAt!),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (auth.tier == 'free' && !auth.isAdmin)
          FilledButton.icon(
            onPressed: () => context.go('/paywall'),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('升级订阅'),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
      ]),
    );
  }
}
