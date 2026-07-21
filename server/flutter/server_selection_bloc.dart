// lib/features/server_selection/bloc/server_selection_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'server_config_service.dart';
import 'server_discovery_service.dart';

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
    on<ServerScanRequested>(_onScanRequested);
    on<ServerSelected>(_onServerSelected);
    on<ServerManualEntrySubmitted>(_onManualEntrySubmitted);
    on<ServerConnectivityCheckRequested>(_onConnectivityCheckRequested);
  }

  Future<void> _onScanRequested(
    ServerScanRequested event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.scanning, errorMessage: null));
    try {
      final servers = await discoveryService.scan();
      if (servers.isEmpty) {
        emit(state.copyWith(
          status: ServerSelectionStatus.scanResultsEmpty,
          discoveredServers: const [],
        ));
      } else {
        emit(state.copyWith(
          status: ServerSelectionStatus.scanResultsFound,
          discoveredServers: servers,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ServerSelectionStatus.connectionFailed,
        errorMessage: 'Không thể quét mạng: $e',
      ));
    }
  }

  Future<void> _onServerSelected(
    ServerSelected event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.connecting, selectedServer: event.server));

    final reachable = await discoveryService.isServerReachable(event.server);
    if (!reachable) {
      emit(state.copyWith(
        status: ServerSelectionStatus.connectionFailed,
        errorMessage: 'Không kết nối được tới ${event.server.serverId} '
            '(${event.server.host}:${event.server.port}). Kiểm tra lại mạng hoặc chọn server khác.',
      ));
      return;
    }

    await configService.setCurrentServer(event.server);
    emit(state.copyWith(status: ServerSelectionStatus.connected));
  }

  Future<void> _onManualEntrySubmitted(
    ServerManualEntrySubmitted event,
    Emitter<ServerSelectionState> emit,
  ) async {
    emit(state.copyWith(status: ServerSelectionStatus.connecting));

    // Server nhập tay chưa có server_id/zone từ TXT record — tạm dùng
    // host:port làm serverId, sau khi /health trả về sẽ cập nhật lại
    // đúng server_id thật của nó.
    final candidate = ServerInfo(
      serverId: '${event.host}:${event.port}',
      zone: 'unknown',
      host: event.host,
      port: event.port,
    );

    final reachable = await discoveryService.isServerReachable(candidate);
    if (!reachable) {
      emit(state.copyWith(
        status: ServerSelectionStatus.connectionFailed,
        errorMessage: 'Không kết nối được tới ${event.host}:${event.port}. '
            'Kiểm tra lại địa chỉ IP và cổng (port).',
      ));
      return;
    }

    await configService.setCurrentServer(candidate);
    emit(state.copyWith(status: ServerSelectionStatus.connected, selectedServer: candidate));
  }

  Future<void> _onConnectivityCheckRequested(
    ServerConnectivityCheckRequested event,
    Emitter<ServerSelectionState> emit,
  ) async {
    final current = configService.currentServer;
    if (current == null) {
      emit(state.copyWith(status: ServerSelectionStatus.initial));
      return;
    }

    emit(state.copyWith(status: ServerSelectionStatus.connecting, selectedServer: current));
    final reachable = await discoveryService.isServerReachable(current);
    if (reachable) {
      emit(state.copyWith(status: ServerSelectionStatus.connected));
    } else {
      // Server mặc định không phản hồi -> gợi ý quét lại để tìm server khác
      // (đúng luồng failover đã thiết kế trong tài liệu multi-server).
      emit(state.copyWith(
        status: ServerSelectionStatus.connectionFailed,
        errorMessage: 'Server ${current.serverId} không phản hồi. Đang tìm server khác...',
      ));
      add(const ServerScanRequested());
    }
  }
}
