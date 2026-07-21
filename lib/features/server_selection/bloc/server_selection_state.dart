part of 'server_selection_bloc.dart';

enum ServerSelectionStatus {
  initial,
  scanning,
  idle,
  connecting,
  success,
  failure,
}

class ServerSelectionState extends Equatable {
  final ServerSelectionStatus status;
  final List<ServerInfo> servers;
  final ServerInfo? activeServer;
  final String? errorMessage;

  const ServerSelectionState({
    this.status = ServerSelectionStatus.initial,
    this.servers = const [],
    this.activeServer,
    this.errorMessage,
  });

  ServerSelectionState copyWith({
    ServerSelectionStatus? status,
    List<ServerInfo>? servers,
    ServerInfo? activeServer,
    String? errorMessage,
  }) {
    return ServerSelectionState(
      status: status ?? this.status,
      servers: servers ?? this.servers,
      activeServer: activeServer ?? this.activeServer,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, servers, activeServer, errorMessage];
}
