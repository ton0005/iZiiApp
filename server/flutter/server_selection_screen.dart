// lib/features/server_selection/screens/server_selection_screen.dart
//
// Màn hình "Chọn server để kết nối" — đúng theo mockup đã thiết kế trong
// tài liệu kiến trúc multi-server. Tự quét mDNS khi mở màn hình, hiển thị
// danh sách server tìm được, và luôn có fallback nhập IP:port thủ công
// (vì mDNS đôi khi bị chặn bởi router/firewall doanh nghiệp).
//
// Responsive: dùng LayoutBuilder để hiện dạng list đơn giản trên phone,
// và dạng card lưới trên tablet (iPad/Samsung tablet) — nhất quán với
// hướng responsive đã áp dụng cho Home screen module Mushrooms.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'server_config_service.dart';
import 'server_selection_bloc.dart';

class ServerSelectionScreen extends StatelessWidget {
  const ServerSelectionScreen({super.key, this.onConnected});

  /// Callback khi kết nối thành công — thường dùng để điều hướng sang màn
  /// hình Login/Home tiếp theo.
  final VoidCallback? onConnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServerSelectionBloc()..add(const ServerScanRequested()),
      child: _ServerSelectionView(onConnected: onConnected),
    );
  }
}

class _ServerSelectionView extends StatefulWidget {
  const _ServerSelectionView({this.onConnected});
  final VoidCallback? onConnected;

  @override
  State<_ServerSelectionView> createState() => _ServerSelectionViewState();
}

class _ServerSelectionViewState extends State<_ServerSelectionView> {
  bool _showManualEntry = false;
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8080');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn server để kết nối')),
      body: BlocConsumer<ServerSelectionBloc, ServerSelectionState>(
        listener: (context, state) {
          if (state.status == ServerSelectionStatus.connected) {
            widget.onConnected?.call();
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusBanner(state),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildBody(context, state, isTablet),
                      ),
                      const SizedBox(height: 8),
                      _buildFooterActions(context, state),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(ServerSelectionState state) {
    switch (state.status) {
      case ServerSelectionStatus.scanning:
        return const _InfoBanner(
          icon: Icons.wifi_find,
          color: Colors.blue,
          text: 'Đang quét mạng LAN để tìm server...',
          showProgress: true,
        );
      case ServerSelectionStatus.connecting:
        return _InfoBanner(
          icon: Icons.sync,
          color: Colors.blue,
          text: 'Đang kết nối tới ${state.selectedServer?.serverId ?? "server"}...',
          showProgress: true,
        );
      case ServerSelectionStatus.connectionFailed:
        return _InfoBanner(
          icon: Icons.error_outline,
          color: Colors.red,
          text: state.errorMessage ?? 'Kết nối thất bại.',
        );
      case ServerSelectionStatus.scanResultsEmpty:
        return const _InfoBanner(
          icon: Icons.info_outline,
          color: Colors.orange,
          text: 'Không tìm thấy server nào trong mạng. Kiểm tra Wi-Fi hoặc nhập IP thủ công bên dưới.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBody(BuildContext context, ServerSelectionState state, bool isTablet) {
    if (_showManualEntry) {
      return _buildManualEntryForm(context);
    }

    if (state.discoveredServers.isEmpty) {
      return const Center(child: Icon(Icons.dns, size: 48, color: Colors.grey));
    }

    if (isTablet) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: state.discoveredServers.length,
        itemBuilder: (context, i) => _ServerCard(
          server: state.discoveredServers[i],
          onTap: () => context.read<ServerSelectionBloc>().add(ServerSelected(state.discoveredServers[i])),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.discoveredServers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ServerCard(
        server: state.discoveredServers[i],
        onTap: () => context.read<ServerSelectionBloc>().add(ServerSelected(state.discoveredServers[i])),
      ),
    );
  }

  Widget _buildManualEntryForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Nhập địa chỉ server thủ công', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ IP',
            hintText: 'vd. 192.168.1.10',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: 'Cổng (port)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Kết nối'),
          onPressed: () {
            final host = _hostController.text.trim();
            final port = int.tryParse(_portController.text.trim()) ?? 8080;
            if (host.isEmpty) return;
            context.read<ServerSelectionBloc>().add(
                  ServerManualEntrySubmitted(host: host, port: port),
                );
          },
        ),
      ],
    );
  }

  Widget _buildFooterActions(BuildContext context, ServerSelectionState state) {
    final isScanning = state.status == ServerSelectionStatus.scanning;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Quét lại'),
            onPressed: isScanning
                ? null
                : () {
                    setState(() => _showManualEntry = false);
                    context.read<ServerSelectionBloc>().add(const ServerScanRequested());
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton.icon(
            icon: Icon(_showManualEntry ? Icons.list : Icons.edit),
            label: Text(_showManualEntry ? 'Xem danh sách' : 'Nhập IP thủ công'),
            onPressed: () => setState(() => _showManualEntry = !_showManualEntry),
          ),
        ),
      ],
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onTap});
  final ServerInfo server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dùng Cupertino icon trên iOS/iPad, Material icon trên Android/Samsung
    // — nhất quán với hướng platform-adaptive đã áp dụng cho Home screen.
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(isApple ? CupertinoIcons.antenna_radiowaves_left_right : Icons.dns_outlined),
        title: Text(server.serverId, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Zone ${server.zone} · ${server.host}:${server.port}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.showProgress = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (showProgress)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.9)))),
        ],
      ),
    );
  }
}
