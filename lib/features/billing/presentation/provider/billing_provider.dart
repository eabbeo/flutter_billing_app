import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:meshop_app/features/product/domain/entities/product.dart';
import 'package:meshop_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final bool isPrinting;
  final bool printSuccess;
  final String? error;
  final bool clearError;

  const BillingState({
    this.cartItems = const [],
    this.isPrinting = false,
    this.printSuccess = false,
    this.error,
    this.clearError = false,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  BillingState copyWith({
    List<CartItem>? cartItems,
    bool? isPrinting,
    bool? printSuccess,
    String? error,
    bool clearError = false,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [cartItems, isPrinting, printSuccess, error, clearError];
}

class BillingProvider extends ChangeNotifier {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingState _state = const BillingState();
  BillingState get state => _state;

  BillingProvider({required this.getProductByBarcodeUseCase});

  void _emit(BillingState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> scanBarcode(String barcode) async {
    final result = await getProductByBarcodeUseCase(barcode);
    result.fold(
      (failure) => _emit(state.copyWith(error: 'Product not found: $barcode')),
      (product) {
        addProductToCart(product);
      },
    );
  }

  void addProductToCart(Product product) {
    final cleanState = state.copyWith(clearError: true); // Clears error
    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      _emit(cleanState.copyWith(cartItems: backendItems, clearError: true));
    } else {
      final newItem = CartItem(product: product);
      _emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], clearError: true));
    }
  }

  void removeProductFromCart(String productId) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != productId)
        .toList();
    _emit(state.copyWith(cartItems: updatedList));
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProductFromCart(productId);
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: quantity);
      _emit(state.copyWith(cartItems: items));
    }
  }

  void clearCart() {
    _emit(const BillingState());
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required String footer,
  }) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          _emit(state.copyWith(error: 'Failed to auto-connect to printer!', clearError: false));
          _emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        _emit(state.copyWith(error: 'Printer not connected & no saved printer found!', clearError: false));
        _emit(state.copyWith(clearError: true));
        return;
      }
    }

    _emit(state.copyWith(isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: shopName,
          address1: address1,
          address2: address2,
          phone: phone,
          items: items,
          total: state.totalAmount,
          footer: footer);

      _emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      _emit(state.copyWith(isPrinting: false, error: 'Print failed: $e', clearError: false));
      _emit(state.copyWith(clearError: true));
    }
  }
}
