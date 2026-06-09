import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repository.dart';

// === Events ===

abstract class PurchaseEvent extends Equatable {
  const PurchaseEvent();
  @override
  List<Object?> get props => [];
}

class LoadPurchaseOrdersEvent extends PurchaseEvent {}

class AddPurchaseOrderEvent extends PurchaseEvent {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> lines;
  const AddPurchaseOrderEvent(this.order, this.lines);
  @override
  List<Object?> get props => [order, lines];
}

class UpdatePurchaseOrderStatusEvent extends PurchaseEvent {
  final String orderId;
  final String status;
  const UpdatePurchaseOrderStatusEvent(this.orderId, this.status);
  @override
  List<Object?> get props => [orderId, status];
}

// === State ===

class PurchaseState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> purchaseOrders;
  final String? error;

  const PurchaseState({
    this.isLoading = false,
    this.purchaseOrders = const [],
    this.error,
  });

  PurchaseState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? purchaseOrders,
    String? error,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, purchaseOrders, error];
}

// === Repository Wrapper ===

class PurchaseModuleRepository {
  static final PurchaseModuleRepository _instance = PurchaseModuleRepository._internal();
  factory PurchaseModuleRepository() => _instance;
  PurchaseModuleRepository._internal();

  final _repo = PurchaseRepository();

  Future<List<Map<String, dynamic>>> getPurchaseOrders() => _repo.getPurchaseOrders();
  Future<void> addPurchaseOrder(Map<String, dynamic> order, List<Map<String, dynamic>> lines) =>
      _repo.addPurchaseOrder(order, lines);
  Future<void> updatePurchaseOrderStatus(String orderId, String status) =>
      _repo.updatePurchaseOrderStatus(orderId, status);
}

// === BLoC ===

class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  PurchaseBloc() : super(const PurchaseState()) {
    on<LoadPurchaseOrdersEvent>(_onLoadPurchaseOrders);
    on<AddPurchaseOrderEvent>(_onAddPurchaseOrder);
    on<UpdatePurchaseOrderStatusEvent>(_onUpdatePurchaseOrderStatus);
  }

  Future<void> _onLoadPurchaseOrders(LoadPurchaseOrdersEvent event, Emitter<PurchaseState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final orders = await PurchaseModuleRepository().getPurchaseOrders();
      emit(state.copyWith(isLoading: false, purchaseOrders: orders));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddPurchaseOrder(AddPurchaseOrderEvent event, Emitter<PurchaseState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await PurchaseModuleRepository().addPurchaseOrder(event.order, event.lines);
      final orders = await PurchaseModuleRepository().getPurchaseOrders();
      emit(state.copyWith(isLoading: false, purchaseOrders: orders));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdatePurchaseOrderStatus(UpdatePurchaseOrderStatusEvent event, Emitter<PurchaseState> emit) async {
    // Optimistic update
    final updatedOrders = state.purchaseOrders.map((o) {
      if (o['id'] == event.orderId) {
        return {...o, 'status': event.status};
      }
      return o;
    }).toList();
    emit(state.copyWith(purchaseOrders: updatedOrders));

    try {
      await PurchaseModuleRepository().updatePurchaseOrderStatus(event.orderId, event.status);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
