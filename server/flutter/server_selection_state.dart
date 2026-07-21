// lib/features/server_selection/bloc/server_selection_state.dart
part of 'server_selection_bloc.dart';

enum ServerSelectionStatus {
  initial,
  scanning,
  scanResultsFound,
  scanResultsEmpty,
  connecting,
  connected,
  connectionFailed,
}

class ServerSelectionState extends Equatable {
  final ServerSelectionStatus status;
  final List<ServerInfo> discoveredServers;
  final ServerInfo? selectedServer;
  final String? errorMessage;

  const ServerSelectionState({
    this.status = ServerSelectionStatus.initial,
    this.discoveredServers = const [],
    this.selectedServer,
    this.errorMessage,
  });

  ServerSelectionState copyWith({
    ServerSelectionStatus? status,
    List<ServerInfo>? discoveredServers,
    ServerInfo? selectedServer,
    String? errorMessage,
  }) {
    return ServerSelectionState(
      status: status ?? this.status,
      discoveredServers: discoveredServers ?? this.discoveredServers,
      selectedServer: selectedServer ?? this.selectedServer,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, discoveredServers, selectedServer, errorMessage];
}
