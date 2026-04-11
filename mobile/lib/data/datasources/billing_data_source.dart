import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/app_constants.dart';

class BillingDataSource {
  static const _productIds = {
    AppConstants.productPro,
    AppConstants.productProPlus,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return [];
    final response = await _iap.queryProductDetails(_productIds);
    return response.productDetails;
  }

  Future<bool> buySubscription(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void dispose() => _subscription?.cancel();
}
