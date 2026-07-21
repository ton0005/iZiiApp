// lib/features/server_selection/bloc/server_selection_event.dart
part of 'server_selection_bloc.dart';

abstract class ServerSelectionEvent extends Equatable {
  const ServerSelectionEvent();

  @override
  List<Object?> get props => [];
}

/// Bắt đầu quét mDNS để tìm server trong mạng LAN.
class ServerScanRequested extends ServerSelectionEvent {
  const ServerScanRequested();
}

/// Người dùng chọn 1 server từ danh sách quét được.
class ServerSelected extends ServerSelectionEvent {
  final ServerInfo server;
  const ServerSelected(this.server);

  @override
  List<Object?> get props => [server];
}

/// Người dùng nhập IP:port thủ công (fallback khi mDNS bị chặn/không tìm thấy).
class ServerManualEntrySubmitted extends ServerSelectionEvent {
  final String host;
  final int port;
  const ServerManualEntrySubmitted({required this.host, required this.port});

  @override
  List<Object?> get props => [host, port];
}

/// Kiểm tra lại server đã lưu trước đó (khi mở app hoặc khi mất kết nối,
/// dùng cho luồng failover).
class ServerConnectivityCheckRequested extends ServerSelectionEvent {
  const ServerConnectivityCheckRequested();
}
