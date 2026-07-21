import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/server_config_service.dart';
import '../../../core/services/server_discovery_service.dart';

part 'server_selection_event.dart';
part 'server_selection_state.dart';

class ServerSelectionBloc extends Bloc<ServerSelectionEvent, ServerSelectionState> {
  final ServerDiscoveryService discoveryService;
  final ServerConfigService configService;

  ServerSelectionBloc({
    ServerDiscoveryService? discoveryService,
    ServerConfigService? configService,
  })  : discoveryService = discoveryService ?? ServerDiscoveryService(),
        configService = configService ?? ServerConfigService.instance,
        super(const ServerSelectionState()) {
    on<ServerSelectionScanStarted>(_onScanStarted);
    on<ServerSelectionManualConnectRequested>(_onManualConnectRequested);
    on<ServerSelectionServerSelected>(_onServerSelected);
  }

  Future<void> _onScanStarted(
    ServerSelectionScanStarted event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.scanning));
    try {
      final servers = await discoveryService.scan();
      final active = configService.currentServer;
      emit(state.copyWith(
        status: ServerSelectionStatus.idle,
        servers: servers,
        activeServer: active,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ServerSelectionStatus.failure,
        errorMessage: 'Không thể quét mạng LAN: $e',
      ));
    }
  }

  Future<void> _onManualConnectRequested(
    ServerSelectionManualConnectRequested event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.connecting));

    final candidate = ServerInfo(
      serverId: '${event.host}:${event.port}',
      zone: 'unknown',
      host: event.host,
      port: event.port,
    );

    final reachable = await discoveryService.isServerReachable(candidate);
    if (!reachable) {
      emit(state.copyWith(
        status: ServerSelectionStatus.failure,
        errorMessage: 'Không thể kết nối tới ${event.host}:${event.port}. Kiểm tra lại địa chỉ IP/port hoặc firewall.',
      ));
      return;
    }

    await configService.setCurrentServer(candidate);
    emit(state.copyWith(
      status: ServerSelectionStatus.success,
      activeServer: candidate,
    ));
  }

  Future<void> _onServerSelected(
    ServerSelectionServerSelected event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.connecting));

    final reachable = await discoveryService.isServerReachable(event.server);
    if (!reachable) {
      emit(state.copyWith(
        status: ServerSelectionStatus.failure,
        errorMessage: 'Server ${event.server.serverId} (${event.server.host}:${event.server.port}) hiện không phản hồi.',
      ));
      return;
    }

    await configService.setCurrentServer(event.server);
    emit(state.copyWith(
      status: ServerSelectionStatus.success,
      activeServer: event.server,
    ));
  }
}
