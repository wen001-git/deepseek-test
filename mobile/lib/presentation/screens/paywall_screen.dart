import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../core/constants/app_constants.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('升级订阅'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout().then(
                (_) => context.go('/login')),
            child: const Text('退出登录'),
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
            Text('解锁全部AI创作功能',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('每天生成高质量短视频脚本、选题、分镜…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Feature list
            ...[
              '📝 脚本制作 & 分镜拍摄表',
              '🎯 爆款选题 & 变现选题',
              '🔍 多平台视频搜索',
              '✍️ 文案二创 & 爆款仿写',
              '📊 内容规划 & 定位分析',
              '🎬 编导专栏',
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
                const Text('无法加载订阅信息，请检查网络',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(billingProvider.notifier).loadProducts(),
                  child: const Text('重新加载'),
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
                    child: const Text('恢复已购订阅'),
                  ),

            const SizedBox(height: 8),
            Text(
              '订阅将通过Google Play自动续费。取消订阅请前往Google Play设置。',
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
    final limit = AppConstants.dailyLimits[isPro ? 'pro' : 'pro_plus'] ?? (isPro ? 30 : 90);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                isPro ? 'Pro版' : 'Pro+版',
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
              Text('/月',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            Text('每天可生成 $limit 次',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            billing.purchaseInProgress
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: () =>
                        ref.read(billingProvider.notifier).buy(product),
                    child: Text('订阅${isPro ? 'Pro版' : 'Pro+版'}'),
                  ),
          ],
        ),
      ),
    );
  }
}
