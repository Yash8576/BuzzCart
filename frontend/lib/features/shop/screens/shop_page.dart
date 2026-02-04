import 'package:flutter/material.dart';

class ShopPage extends StatelessWidget {
  final String? productId;

  const ShopPage({super.key, this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
      ),
      body: Center(
        child: Text(
          productId != null 
              ? 'Product Detail: $productId' 
              : 'Shop Page - Coming Soon',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
