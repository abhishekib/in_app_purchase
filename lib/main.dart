import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable StoreKit 2 for iOS
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    InAppPurchaseStoreKitPlatform.registerPlatform();
    InAppPurchaseStoreKitPlatform.enableStoreKit2();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'In-App Purchase Demo',
      debugShowCheckedModeBanner: false,
      home: PurchaseScreen(),
      initialBinding: BindingsBuilder(() {
        Get.put(InAppPurchaseUtils());
      }),
    );
  }
}

class InAppPurchaseUtils extends GetxController {
  static InAppPurchaseUtils get to => Get.find();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchasesSubscription;
  final RxBool isAvailable = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<ProductDetails> availableProducts = <ProductDetails>[].obs;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    _purchasesSubscription.cancel();
    super.onClose();
  }

  Future<void> initialize() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Debug: Print bundle ID
      await debugBundleId();

      // Check if in-app purchases are available
      isAvailable.value = await _iap.isAvailable();
      log('IAP Available: ${isAvailable.value}');
      
      if (!isAvailable.value) {
        errorMessage.value = 'In-app purchases not available on this device';
        return;
      }

      // Set up purchase stream listener
      _purchasesSubscription = _iap.purchaseStream.listen(
        handlePurchaseUpdates,
        onDone: () => _purchasesSubscription.cancel(),
        onError: (error) {
          log('Purchase stream error: $error');
          errorMessage.value = 'Purchase stream error: $error';
        },
      );

      // Load available products
      await loadProducts();
      
    } catch (e) {
      log('Initialization error: $e');
      errorMessage.value = 'Initialization error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> debugBundleId() async {
    try {
      const platform = MethodChannel('flutter.io/packageInfo');
      final result = await platform.invokeMethod('getAll');
      log('App Bundle Info is: $result');
    } catch (e) {
      log('Error getting bundle info: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      final Set<String> productIds = {'shoe_purchase'}; // Add more product IDs as needed
      
      log('Querying products: $productIds');
      final response = await _iap.queryProductDetails(productIds);
      
      log('Query response - Error: ${response.error}');
      log('Query response - Product details count: ${response.productDetails.length}');
      log('Query response - Not found IDs: ${response.notFoundIDs}');
      
      if (response.error != null) {
        errorMessage.value = 'Error loading products: ${response.error!.message}';
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        errorMessage.value = 'Products not found: ${response.notFoundIDs.join(', ')}';
        log('Products not found in store: ${response.notFoundIDs}');
      }

      availableProducts.value = response.productDetails;
      
      for (final product in response.productDetails) {
        log('Available product: ${product.id} - ${product.title} - ${product.price}');
      }
      
    } catch (e) {
      log('Error loading products: $e');
      errorMessage.value = 'Error loading products: $e';
    }
  }

  void handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      log('Purchase update: ${purchaseDetails.status} for ${purchaseDetails.productID}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          log('Purchase pending for ${purchaseDetails.productID}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _completePurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          final errorMsg = purchaseDetails.error?.message ?? 'Purchase failed';
          log('Purchase error: $errorMsg');
          errorMessage.value = errorMsg;
          break;
        case PurchaseStatus.canceled:
          log('Purchase canceled for ${purchaseDetails.productID}');
          errorMessage.value = 'Purchase was canceled';
          break;
      }
    }
  }

  Future<void> _completePurchase(PurchaseDetails purchaseDetails) async {
    try {
      log('Completing purchase for ${purchaseDetails.productID}');
      await _iap.completePurchase(purchaseDetails);
      Get.snackbar('Success', 'Purchase completed successfully!');
      
      // Handle your purchase logic here
      // For example, unlock premium features, add coins, etc.
      
    } catch (e) {
      log('Error completing purchase: $e');
      errorMessage.value = 'Error completing purchase: $e';
    }
  }

  Future<void> buyConsumableProduct(String productId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      log('Attempting to buy product: $productId');

      // Find the product in our available products
      final product = availableProducts.firstWhereOrNull(
        (p) => p.id == productId,
      );

      if (product == null) {
        errorMessage.value = 'Product not available: $productId';
        log('Product not found in available products: $productId');
        return;
      }

      log('Found product: ${product.id} - ${product.title} - ${product.price}');

      final param = PurchaseParam(productDetails: product);

      log('Initiating purchase...');
      final success = await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );

      log('Purchase initiation result: $success');

    } on PlatformException catch (e) {
      log('Platform exception during purchase: ${e.message}');
      errorMessage.value = 'Platform error: ${e.message}';
    } catch (e) {
      log('Error during purchase: $e');
      errorMessage.value = 'Purchase error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      log('Restoring purchases...');
      await _iap.restorePurchases();
      
    } catch (e) {
      log('Error restoring purchases: $e');
      errorMessage.value = 'Error restoring purchases: $e';
    } finally {
      isLoading.value = false;
    }
  }
}

class PurchaseScreen extends StatelessWidget {
  final String productId = 'shoe_purchase'; // Your product ID here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => InAppPurchaseUtils.to.initialize(),
          ),
        ],
      ),
      body: Center(
        child: GetX<InAppPurchaseUtils>(
          builder: (iap) {
            if (iap.isLoading.value) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading...'),
                ],
              );
            }

            if (iap.errorMessage.value.isNotEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      iap.errorMessage.value,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: iap.initialize,
                    child: const Text('Retry'),
                  ),
                ],
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!iap.isAvailable.value)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'In-app purchases not available',
                      style: TextStyle(color: Colors.orange, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                if (iap.availableProducts.isEmpty && iap.isAvailable.value)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No products available',
                      style: TextStyle(color: Colors.orange, fontSize: 16),
                    ),
                  ),

                // Show available products
                ...iap.availableProducts.map((product) => Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(product.description),
                        const SizedBox(height: 10),
                        Text(
                          product.price,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: () => iap.buyConsumableProduct(product.id),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                            child: Text(
                              'Buy Now',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

                const SizedBox(height: 20),
                
                // Restore purchases button
                TextButton(
                  onPressed: iap.restorePurchases,
                  child: const Text('Restore Purchases'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}