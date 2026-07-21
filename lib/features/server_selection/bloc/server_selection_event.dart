part of 'server_selection_bloc.dart';

abstract class ServerSelectionEvent extends Equatable {
  const ServerSelectionEvent();

  @override
  List<Object?> get props => [];
}

class ServerSelectionScanStarted extends ServerSelectionEvent {
  const ServerSelectionScanStarted();
}

class ServerSelectionManualConnectRequested extends ServerSelectionEvent {
  final String host;
  final int port;

  const ServerSelectionManualConnectRequested({
    required this.host,
    required this.port,
  });

  @override
  List<Object?> get props => [host, port];
}

class ServerSelectionServerSelected extends ServerSelectionEvent {
  final ServerInfo server;

  const ServerSelectionServerSelected(this.server);

  @override
  List<Object?> get props => [server];
}
