import 'package:flutter/material.dart';
import '../../domain/entities/shop.dart';
import '../../domain/usecases/shop_usecases.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';

abstract class ShopState extends Equatable {
  const ShopState();
  @override
  List<Object> get props => [];
}

class ShopInitial extends ShopState {}
class ShopLoading extends ShopState {}
class ShopLoaded extends ShopState {
  final Shop shop;
  const ShopLoaded(this.shop);
  @override
  List<Object> get props => [shop];
}
class ShopError extends ShopState {
  final String message;
  const ShopError(this.message);
  @override
  List<Object> get props => [message];
}

class ShopProvider extends ChangeNotifier {
  final GetShopUseCase getShopUseCase;
  final UpdateShopUseCase updateShopUseCase;

  ShopState _state = ShopInitial();
  ShopState get state => _state;

  ShopProvider({
    required this.getShopUseCase,
    required this.updateShopUseCase,
  });

  void _emit(ShopState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> loadShop() async {
    _emit(ShopLoading());
    final result = await getShopUseCase(NoParams());
    result.fold(
      (failure) => _emit(ShopError(failure.message)),
      (shop) => _emit(ShopLoaded(shop)),
    );
  }

  Future<bool> updateShop(Shop shop) async {
    _emit(ShopLoading());
    final result = await updateShopUseCase(shop);
    return result.fold(
      (failure) {
        _emit(ShopError(failure.message));
        return false;
      },
      (_) {
        loadShop();
        return true;
      },
    );
  }
}
