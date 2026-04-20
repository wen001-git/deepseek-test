import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/constants/app_constants.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(billingProvider.notifier).loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingProvider);
    final auth = ref.watch(authProvider);

    // If user now has access (after purchase verified), go home
    if (auth.isAuthenticated &&
        (auth.isAdmin || auth.tier == 'pro' || auth.tier == 'pro_plus')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
    }

    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.upgradeTitle),
        actions: [
          TextButton(
            onPressed: _logout,
            child: Text(s.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Icon(Icons.workspace_premium,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(s.unlockAll,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(s.paywallSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Feature list
            ...[
              s.feat1, s.feat2, s.feat3, s.feat4, s.feat5, s.feat6,
            ].map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ]),
                )),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Error
            if (billing.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(billing.error!,
                    style: const TextStyle(color: Colors.red)),
              ),

            // Products
            if (billing.isLoading)
              const CircularProgressIndicator()
            else if (billing.products.isEmpty)
              Column(children: [
                Text(s.loadError, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(billingProvider.notifier).loadProducts(),
                  child: Text(s.reload),
                ),
              ])
            else
              ...billing.products.map((p) => _ProductCard(product: p)),

            const SizedBox(height: 16),

            // Restore
            billing.purchaseInProgress
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: () =>
                        ref.read(billingProvider.notifier).restore(),
                    child: Text(s.restore),
                  ),

            const SizedBox(height: 8),
            Text(
              s.autoRenewNote,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductDetails product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = product.id == AppConstants.productPro;
    final billing = ref.watch(billingProvider);
    final s = ref.watch(stringsProvider);
    final limit = AppConstants.dailyLimits[isPro ? 'pro' : 'pro_plus'] ?? (isPro ? 30 : 90);
    final tierLabel = isPro ? s.tierPro : s.tierProPlus;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                tierLabel,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(product.price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
              Text(s.perMonth,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            Text(s.timesPerDayN(limit), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            billing.purchaseInProgress
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: () =>
                        ref.read(billingProvider.notifier).buy(product),
                    child: Text(s.subscribeTo(tierLabel)),
                  ),
          ],
        ),
      ),
    );
  }
}
