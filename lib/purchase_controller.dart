// Create a new file: lib/controllers/purchase_controller.dart
import 'dart:developer';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseController extends GetxController {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final String _productId = 'shoe_subscription';
  Set<String> _kIds = <String>{'shoe_subscription', 'shoe_purchase'};
  var isLoading = false.obs;
  var isAvailable = false.obs;
  var products = <ProductDetails>[].obs;
  var purchaseStatus = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  Future<void> initialize() async {
    isAvailable.value = await _inAppPurchase.isAvailable();
    if (!isAvailable.value) {
      log('Not Avalilable ${isAvailable.value}');
      return;
    }
    log('Available ${isAvailable.value}');

    await getProducts();
    _listenToPurchaseUpdated();
  }

  Future<void> getProducts() async {
    isLoading.value = true;
    try {
      ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails({_productId});
      log(
        '---->${response.productDetails} <----->\nerror in response::: ${response.error} <--->\nID Which we didn"found::: ${response.notFoundIDs.toString()}',
      );
      products.value = response.productDetails;
    } finally {
      isLoading.value = false;
    }
  }

  void _listenToPurchaseUpdated() {
    _inAppPurchase.purchaseStream.listen((
      List<PurchaseDetails> purchaseDetailsList,
    ) {
      _handlePurchase(purchaseDetailsList);
    });
  }

  void _handlePurchase(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.productID == _productId) {
        if (purchaseDetails.status == PurchaseStatus.purchased) {
          // Handle consumable purchase
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
          purchaseStatus.value = 'Purchase successful!';
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          purchaseStatus.value =
              'Purchase error: ${purchaseDetails.error?.message}';
        }
      }
    }
  }

  Future<void> buyProduct() async {
    if (products.isEmpty) {
      purchaseStatus.value = 'Product not available';
      return;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: products.first,
        applicationUserName: null,
      );
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam,autoConsume: true);
    } catch (e) {
      purchaseStatus.value = 'Error: $e';
    }
  }
}
