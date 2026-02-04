import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _api;
  
  CartModel _cart = CartModel.empty();
  bool _isLoading = false;

  CartModel get cart => _cart;
  bool get isLoading => _isLoading;

  CartProvider({required ApiService apiService}) : _api = apiService;

  Future<void> fetchCart() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _cart = await _api.getCart();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      _cart = CartModel.empty();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    try {
      await _api.addToCart(productId, quantity: quantity);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      return false;
    }
  }

  Future<bool> updateQuantity(String productId, int quantity) async {
    try {
      await _api.updateCartQuantity(productId, quantity);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      return false;
    }
  }

  Future<bool> removeFromCart(String productId) async {
    try {
      await _api.removeFromCart(productId);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      return false;
    }
  }

  Future<bool> clearCart() async {
    try {
      await _api.clearCart();
      _cart = CartModel.empty();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      return false;
    }
  }
}
