import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final s = ref.watch(stringsProvider);
    final tierName = s.tierName(auth.tier);
    final dailyLimit = auth.dailyLimit;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: Text(s.myAccountTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 24),

          // Info card
          Card(
            child: Column(children: [
              _InfoTile(label: s.accountType, value: auth.role == 'admin' ? s.adminRole : s.normalUser),
              const Divider(height: 1),
              _InfoTile(label: s.subscription, value: tierName,
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

          // Upgrade button (if free tier)
          if (auth.tier == 'free' && !auth.isAdmin)
            FilledButton.icon(
              onPressed: () => context.push('/paywall'),
              icon: const Icon(Icons.workspace_premium),
              label: Text(s.upgradeBtn),
            ),

          const SizedBox(height: 16),

          // Logout
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
      ),
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
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ]),
    );
  }
}
