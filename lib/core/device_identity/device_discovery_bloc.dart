// =============================================================================
// Device Discovery BLoC — Track 3: Device Identity & E2EE Messaging
// =============================================================================
// Self-contained BLoC for device discovery and device management screens.
// Uses flutter_bloc with equatable for proper state comparison.
// =============================================================================

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'device_identity_models.dart';
import 'device_identity_service.dart';
import 'device_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Events
// ─────────────────────────────────────────────────────────────────────────────

abstract class DeviceDiscoveryEvent extends Equatable {
  const DeviceDiscoveryEvent();

  @override
  List<Object?> get props => [];
}

/// Load the current user's registered devices (for My Devices screen).
class LoadMyDevicesEvent extends DeviceDiscoveryEvent {}

/// Discover all online devices across the network (for Online Devices screen).
class DiscoverOnlineDevicesEvent extends DeviceDiscoveryEvent {}

/// Refresh the device list (pull-to-refresh).
class RefreshDevicesEvent extends DeviceDiscoveryEvent {}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum DeviceDiscoveryStatus { initial, loading, loaded, error }

class DeviceDiscoveryState extends Equatable {
  final DeviceDiscoveryStatus status;
  final List<RemoteDevice> myDevices;
  final List<RemoteDevice> onlineDevices;
  final String? currentDeviceId;
  final String? errorMessage;

  const DeviceDiscoveryState({
    this.status = DeviceDiscoveryStatus.initial,
    this.myDevices = const [],
    this.onlineDevices = const [],
    this.currentDeviceId,
    this.errorMessage,
  });

  DeviceDiscoveryState copyWith({
    DeviceDiscoveryStatus? status,
    List<RemoteDevice>? myDevices,
    List<RemoteDevice>? onlineDevices,
    String? currentDeviceId,
    String? errorMessage,
  }) {
    return DeviceDiscoveryState(
      status: status ?? this.status,
      myDevices: myDevices ?? this.myDevices,
      onlineDevices: onlineDevices ?? this.onlineDevices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, myDevices, onlineDevices, currentDeviceId, errorMessage];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLoC
// ─────────────────────────────────────────────────────────────────────────────

class DeviceDiscoveryBloc
    extends Bloc<DeviceDiscoveryEvent, DeviceDiscoveryState> {
  final DeviceIdentityService _identityService;
  final DeviceDiscoveryService _discoveryService;

  DeviceDiscoveryBloc({
    DeviceIdentityService? identityService,
    DeviceDiscoveryService? discoveryService,
  })  : _identityService = identityService ?? DeviceIdentityService(),
        _discoveryService = discoveryService ?? DeviceDiscoveryService(),
        super(const DeviceDiscoveryState()) {
    on<LoadMyDevicesEvent>(_onLoadMyDevices);
    on<DiscoverOnlineDevicesEvent>(_onDiscoverOnlineDevices);
    on<RefreshDevicesEvent>(_onRefreshDevices);
  }

  Future<void> _onLoadMyDevices(
    LoadMyDevicesEvent event,
    Emitter<DeviceDiscoveryState> emit,
  ) async {
    emit(state.copyWith(status: DeviceDiscoveryStatus.loading));
    try {
      await _discoveryService.registerDevice();
      _discoveryService.startHeartbeat();

      final identity = await _identityService.getOrCreateIdentity();
      final devices = await _identityService.getMyDevices();
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.loaded,
        myDevices: devices,
        currentDeviceId: identity.deviceId,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDiscoverOnlineDevices(
    DiscoverOnlineDevicesEvent event,
    Emitter<DeviceDiscoveryState> emit,
  ) async {
    emit(state.copyWith(status: DeviceDiscoveryStatus.loading));
    try {
      await _discoveryService.registerDevice();
      _discoveryService.startHeartbeat();

      final devices = await _discoveryService.getOnlineDevices();
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.loaded,
        onlineDevices: devices,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshDevices(
    RefreshDevicesEvent event,
    Emitter<DeviceDiscoveryState> emit,
  ) async {
    try {
      await _discoveryService.registerDevice();

      final identity = await _identityService.getOrCreateIdentity();
      final myDevices = await _identityService.getMyDevices();
      final onlineDevices = await _discoveryService.getOnlineDevices();
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.loaded,
        myDevices: myDevices,
        onlineDevices: onlineDevices,
        currentDeviceId: identity.deviceId,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DeviceDiscoveryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Convenience getter for the discovery service (used by screens for
  /// user display name resolution).
  DeviceDiscoveryService get discoveryService => _discoveryService;
}
