import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stepwhere/purchase_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'StepWhere',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'StepWhere App'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final PurchaseController purchaseController = Get.put(PurchaseController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Obx(() {
              if (purchaseController.isLoading.value) {
                return const CircularProgressIndicator();
              }

              if (!purchaseController.isAvailable.value) {
                return const Text('In-app purchases not available');
              }

              if (purchaseController.products.isEmpty) {
                return const Text('Product not found');
              }

              return Column(
                children: [
                  Text(
                    purchaseController.products.first.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    purchaseController.products.first.description,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    purchaseController.products.first.price,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
            Obx(
              () => Text(
                purchaseController.purchaseStatus.value,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: purchaseController.buyProduct,
        tooltip: 'Buy Subscription',
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
