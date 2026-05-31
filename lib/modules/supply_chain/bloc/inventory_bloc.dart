import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../repository.dart';

// Events
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadProductsEvent extends InventoryEvent {}

// State
class InventoryState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> products;
  final String? error;

  const InventoryState({
    this.isLoading = false,
    this.products = const [],
    this.error,
  });

  InventoryState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? products,
    String? error,
  }) {
    return InventoryState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, products, error];
}

class InventoryRepository {
  static final InventoryRepository _instance = InventoryRepository._internal();
  factory InventoryRepository() => _instance;
  InventoryRepository._internal();

  final _repo = SupplyChainRepository();

  Future<List<Map<String, dynamic>>> getProducts() async {
    return await _repo.getProductsWithStock();
  }

  Future<void> addProduct(Map<String, dynamic> productMap) async {
    final productId = productMap['id'] ?? const Uuid().v4();
    final sku =
        productMap['sku'] ?? 'SKU-${productId.toString().substring(0, 6)}';
    await _repo.addProductWithStock(
      id: productId,
      sku: sku,
      name: productMap['name'],
      price: (productMap['price'] as num).toDouble(),
      cost: 0.0,
      stock: productMap['stock'] != null
          ? (productMap['stock'] as num).toDouble()
          : 0.0,
      customFields: productMap['custom_fields'],
    );
  }

  Future<void> updateProduct(Map<String, dynamic> productMap) async {
    await _repo.updateProductWithStock(
      id: productMap['id'],
      name: productMap['name'],
      price: (productMap['price'] as num).toDouble(),
      cost: 0.0,
      stock: productMap['stock'] != null
          ? (productMap['stock'] as num).toDouble()
          : null,
      customFields: productMap['custom_fields'],
    );
  }

  Future<int> checkStock(String productNameQuery) async {
    return await _repo.checkStock(productNameQuery);
  }
}

// Bloc
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc() : super(const InventoryState()) {
    on<LoadProductsEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final products = await InventoryRepository().getProducts();
        emit(state.copyWith(
          isLoading: false,
          products: products,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });
  }
}
