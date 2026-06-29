import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../repository.dart';

// === Events ===

abstract class ServicesEvent extends Equatable {
  const ServicesEvent();
  @override
  List<Object?> get props => [];
}

class LoadServicesEvent extends ServicesEvent {}

class LoadBookingsEvent extends ServicesEvent {}

// === State ===

class ServicesState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> bookings;
  final String? error;

  const ServicesState({
    this.isLoading = false,
    this.services = const [],
    this.bookings = const [],
    this.error,
  });

  ServicesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? bookings,
    String? error,
  }) {
    return ServicesState(
      isLoading: isLoading ?? this.isLoading,
      services: services ?? this.services,
      bookings: bookings ?? this.bookings,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, services, bookings, error];
}

// === Repository Wrapper ===

class ServiceModuleRepository {
  static final ServiceModuleRepository _instance = ServiceModuleRepository._internal();
  factory ServiceModuleRepository() => _instance;
  ServiceModuleRepository._internal();

  final _repo = ServicesRepository();

  Future<List<Map<String, dynamic>>> getServices() => _repo.getServiceItems();
  Future<List<Map<String, dynamic>>> getBookings() => _repo.getBookings();

  Future<void> addService(Map<String, dynamic> data) => _repo.addServiceItem(data);
  Future<void> updateService(Map<String, dynamic> data) => _repo.updateServiceItem(data);

  Future<void> addBooking(Map<String, dynamic> data) => _repo.addBooking(data);
  Future<void> updateBookingStatus(String id, String status, {double? actualHours}) =>
      _repo.updateBookingStatus(id, status, actualHours: actualHours);

  Future<String> getServiceInfo(String name) => _repo.getServiceInfo(name);
}

// === BLoC ===

class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  StreamSubscription? _shareSubscription;

  ServicesBloc() : super(const ServicesState()) {
    _shareSubscription = BleDeviceDiscoveryService().shareCompletedStream.listen((table) {
      if (table == 'service_items') {
        add(LoadServicesEvent());
      }
    });

    on<LoadServicesEvent>(_onLoadServices);
    on<LoadBookingsEvent>(_onLoadBookings);
  }

  @override
  Future<void> close() {
    _shareSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadServices(LoadServicesEvent event, Emitter<ServicesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final services = await ServiceModuleRepository().getServices();
      emit(state.copyWith(isLoading: false, services: services));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadBookings(LoadBookingsEvent event, Emitter<ServicesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final bookings = await ServiceModuleRepository().getBookings();
      emit(state.copyWith(isLoading: false, bookings: bookings));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
