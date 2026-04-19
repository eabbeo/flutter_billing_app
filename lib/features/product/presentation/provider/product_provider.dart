import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/product_usecases.dart';
import '../../../../core/usecase/usecase.dart';

enum ProductStatus { initial, loading, loaded, error }

class ProductState extends Equatable {
  final ProductStatus status;
  final List<Product> products;
  final String? message;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.message,
  });

  ProductState copyWith({
    ProductStatus? status,
    List<Product>? products,
    String? message,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, products, message];
}

class ProductProvider extends ChangeNotifier {
  final GetProductsUseCase getProductsUseCase;
  final AddProductUseCase addProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;

  ProductState _state = const ProductState();
  ProductState get state => _state;

  ProductProvider({
    required this.getProductsUseCase,
    required this.addProductUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
  });

  void _emit(ProductState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _emit(state.copyWith(status: ProductStatus.loading));
    final result = await getProductsUseCase(NoParams());
    result.fold(
      (failure) => _emit(state.copyWith(status: ProductStatus.error, message: failure.message)),
      (products) => _emit(state.copyWith(status: ProductStatus.loaded, products: products, message: null)),
    );
  }

  Future<bool> addProduct(Product product) async {
    _emit(state.copyWith(status: ProductStatus.loading));
    final result = await addProductUseCase(product);
    return result.fold(
      (failure) {
        _emit(state.copyWith(status: ProductStatus.error, message: failure.message));
        return false;
      },
      (_) {
        loadProducts();
        return true;
      },
    );
  }

  Future<bool> updateProduct(Product product) async {
    _emit(state.copyWith(status: ProductStatus.loading));
    final result = await updateProductUseCase(product);
    return result.fold(
      (failure) {
        _emit(state.copyWith(status: ProductStatus.error, message: failure.message));
        return false;
      },
      (_) {
        loadProducts();
        return true;
      },
    );
  }

  Future<bool> deleteProduct(String id) async {
    _emit(state.copyWith(status: ProductStatus.loading));
    final result = await deleteProductUseCase(id);
    return result.fold(
      (failure) {
        _emit(state.copyWith(status: ProductStatus.error, message: failure.message));
        return false;
      },
      (_) {
        loadProducts();
        return true;
      },
    );
  }
}
