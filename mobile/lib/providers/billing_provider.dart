import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/constants/app_constants.dart';
import '../data/datasources/api_data_source.dart';
import '../data/datasources/billing_data_source.dart';
import 'auth_provider.dart';
import 'locale_provider.dart';

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
          final s = _ref.read(stringsProvider);
          state = state.copyWith(
            purchaseInProgress: false,
            error: s.purchaseFailed(p.error?.message ?? s.purchaseFailedUnknown),
          );
        }
      }
    });
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await _billing.loadProducts();
      final s = _ref.read(stringsProvider);
      if (products.isEmpty) {
        // Either Google Play is unavailable (emulator / no Play Store) or the
        // product IDs are not yet registered in Play Console.
        state = state.copyWith(
          isLoading: false,
          error: s.playUnavailable,
        );
        return;
      }
      // Sort: Pro first, Pro+ second
      products.sort((a, b) => a.id.compareTo(b.id));
      state = state.copyWith(isLoading: false, products: products);
    } catch (e) {
      final s = _ref.read(stringsProvider);
      state = state.copyWith(isLoading: false, error: s.loadPlansFailed);
    }
  }

  Future<void> buy(ProductDetails product) async {
    state = state.copyWith(purchaseInProgress: true, error: null);
    try {
      await _billing.buySubscription(product);
    } catch (e) {
      final s = _ref.read(stringsProvider);
      state = state.copyWith(
          purchaseInProgress: false, error: s.launchPurchaseFailed);
    }
  }

  Future<void> restore() async {
    state = state.copyWith(purchaseInProgress: true, error: null);
    await _billing.restorePurchases();
  }

  Future<void> _verifyAndActivate(PurchaseDetails p) async {
    try {
      final purchaseToken = p.verificationData.serverVerificationData;
      if (purchaseToken.isEmpty) {
        throw StateError('Missing Play purchase token');
      }
      await _api.verifySubscription(purchaseToken, p.productID);
      await _ref.read(authProvider.notifier).refreshUser();
      state = state.copyWith(purchaseInProgress: false);
    } catch (e) {
      final s = _ref.read(stringsProvider);
      state = state.copyWith(
          purchaseInProgress: false, error: s.verifySubscriptionFailed);
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
