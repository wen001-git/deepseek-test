import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  final bool adminOnly;
  const _NavItem(this.route, this.icon, this.label, {this.adminOnly = false});
}

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
    final s = ref.watch(stringsProvider);
    final allItems = [
      _NavItem('/account-planning', Icons.route_outlined, s.accountPlanning),
      _NavItem('/viral-topics', Icons.trending_up, s.viralTopics),
      _NavItem('/monetize-topics', Icons.monetization_on_outlined, s.monetizeTopics),
      _NavItem('/script', Icons.article_outlined, s.scriptWriting),
      _NavItem('/rewrite', Icons.edit_note, s.contentRewrite),
      _NavItem('/breakdown', Icons.analytics_outlined, s.breakdown),
      _NavItem('/imitate', Icons.copy_outlined, s.imitate),
      _NavItem('/director', Icons.movie_creation_outlined, s.director),
      _NavItem('/hot-trends', Icons.whatshot_outlined, s.hotTrends, adminOnly: true),
    ];
    final visibleItems = allItems.where((i) => !i.adminOnly || auth.isAdmin).toList();
    final titles = [s.appName, s.myAccountTitle];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          _FeaturesGrid(items: visibleItems),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.apps_outlined),
            selectedIcon: const Icon(Icons.apps),
            label: s.toolbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: s.myTab,
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
    final s = ref.watch(stringsProvider);
    final tierName = s.tierName(auth.tier);
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
            _InfoTile(label: s.accountType, value: auth.role == 'admin' ? s.adminRole : s.normalUser),
            const Divider(height: 1),
            _InfoTile(
                label: s.subscription,
                value: tierName,
                valueColor: Theme.of(context).colorScheme.primary),
            const Divider(height: 1),
            _InfoTile(label: s.dailyLimit, value: s.timesPerDay(dailyLimit)),
            if (auth.expiresAt != null) ...[
              const Divider(height: 1),
              _InfoTile(label: s.expiresAt, value: auth.expiresAt!),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // Language toggle
        Card(
          child: SwitchListTile(
            title: Text(s.language),
            subtitle: Text(s.isZh ? s.chinese : s.english),
            secondary: const Icon(Icons.language),
            value: s.isZh,
            onChanged: (_) => ref.read(localeProvider.notifier).toggle(),
          ),
        ),
        const SizedBox(height: 16),
        if (auth.tier == 'free' && !auth.isAdmin)
          FilledButton.icon(
            onPressed: () => context.go('/paywall'),
            icon: const Icon(Icons.workspace_premium),
            label: Text(s.upgradeBtn),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: Text(s.logout),
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
