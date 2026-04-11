import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/constants/app_constants.dart';
import '../data/datasources/api_data_source.dart';
import '../data/datasources/billing_data_source.dart';
import 'auth_provider.dart';

final billingDataSourceProvider =
    Provider<BillingDataSource>((_) => BillingDataSource());

class BillingState {
  final bool isLoading;
  final List<ProductDetails> products;
  final String? error;
  final bool purchaseInProgress;

  const BillingState({
    this.isLoading = false,
    this.products = const [],
    this.error,
    this.purchaseInProgress = false,
  });

  BillingState copyWith({
    bool? isLoading,
    List<ProductDetails>? products,
    String? error,
    bool? purchaseInProgress,
  }) =>
      BillingState(
        isLoading: isLoading ?? this.isLoading,
        products: products ?? this.products,
        error: error,
        purchaseInProgress: purchaseInProgress ?? this.purchaseInProgress,
      );
}

class BillingNotifier extends StateNotifier<BillingState> {
  final BillingDataSource _billing;
  final ApiDataSource _api;
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  BillingNotifier(this._billing, this._api, this._ref)
      : super(const BillingState()) {
    _listenPurchases();
  }

  void _listenPurchases() {
    _sub = _billing.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          await _verifyAndActivate(p);
          await _billing.completePurchase(p);
        } else if (p.status == PurchaseStatus.error) {
          state = state.copyWith(
            purchaseInProgress: false,
            error: '购买失败：${p.error?.message ?? '未知错误'}',
          );
        }
      }
    });
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await _billing.loadProducts();
      if (products.isEmpty) {
        // Either Google Play is unavailable (emulator / no Play Store) or the
        // product IDs are not yet registered in Play Console.
        state = state.copyWith(
          isLoading: false,
          error: 'Google Play 订阅服务不可用。请确认设备已安装 Play 商店，且订阅套餐已在 Play Console 配置。',
        );
        return;
      }
      // Sort: Pro first, Pro+ second
      products.sort((a, b) => a.id.compareTo(b.id));
      state = state.copyWith(isLoading: false, products: products);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载订阅信息失败，请检查网络后重试');
    }
  }

  Future<void> buy(ProductDetails product) async {
    state = state.copyWith(purchaseInProgress: true, error: null);
    try {
      await _billing.buySubscription(product);
    } catch (e) {
      state = state.copyWith(
          purchaseInProgress: false, error: '无法发起购买，请稍后再试');
    }
  }

  Future<void> restore() async {
    state = state.copyWith(purchaseInProgress: true, error: null);
    await _billing.restorePurchases();
  }

  Future<void> _verifyAndActivate(PurchaseDetails p) async {
    try {
      await _api.verifySubscription(p.purchaseID ?? '', p.productID);
      await _ref.read(authProvider.notifier).refreshUser();
      state = state.copyWith(purchaseInProgress: false);
    } catch (e) {
      state = state.copyWith(
          purchaseInProgress: false, error: '订阅验证失败，请联系客服');
    }
  }

  String productName(String productId) {
    final match = state.products.where((p) => p.id == productId).firstOrNull;
    final tierName = productId == AppConstants.productPro ? 'Pro版' : 'Pro+版';
    return match != null ? '$tierName ${match.price}/月' : tierName;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _billing.dispose();
    super.dispose();
  }
}

final billingProvider =
    StateNotifierProvider<BillingNotifier, BillingState>((ref) {
  return BillingNotifier(
    ref.read(billingDataSourceProvider),
    ref.read(apiDataSourceProvider),
    ref,
  );
});
