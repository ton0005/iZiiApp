// lib/features/server_selection/screens/server_selection_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/server_config_service.dart';
import '../bloc/server_selection_bloc.dart';

class ServerSelectionScreen extends StatelessWidget {
  const ServerSelectionScreen({super.key, this.onConnected});

  final VoidCallback? onConnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServerSelectionBloc()..add(const ServerSelectionScanStarted()),
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
  final _hostController = TextEditingController(text: '192.168.1.');
  final _portController = TextEditingController(text: '8080');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn iZiiApp Server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Quét lại mạng LAN',
            onPressed: () => context
                .read<ServerSelectionBloc>()
                .add(const ServerSelectionScanStarted()),
          ),
        ],
      ),
      body: BlocConsumer<ServerSelectionBloc, ServerSelectionState>(
        listener: (context, state) {
          if (state.status == ServerSelectionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã kết nối tới server: ${state.activeServer?.serverId ?? state.activeServer?.baseUrl}',
                ),
                backgroundColor: Colors.green,
              ),
            );
            widget.onConnected?.call();
          } else if (state.status == ServerSelectionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Kết nối thất bại'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(theme),
                        const SizedBox(height: 16),

                        if (state.status == ServerSelectionStatus.scanning) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Đang quét mạng LAN tìm iZiiApp Server...'),
                                ],
                              ),
                            ),
                          ),
                        ] else if (state.servers.isEmpty) ...[
                          _buildEmptyScanState(theme),
                        ] else ...[
                          Text(
                            'Server tìm thấy trong mạng LAN (${state.servers.length}):',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (isWide)
                            _buildServerGrid(context, state)
                          else
                            _buildServerList(context, state),
                        ],

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildManualSection(context, state, theme),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.dns, size: 36, color: Colors.teal),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iZiiApp Multi-Server Engine',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ứng dụng tự động phát hiện server trong cùng mạng Wi-Fi/LAN qua mDNS. Chọn server thích hợp để đồng bộ dữ liệu.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanState(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.wifi_find, size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy server mDNS tự động',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kiểm tra lại thiết bị đã kết nối cùng mạng Wi-Fi với server, hoặc nhập IP server bên dưới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, ServerSelectionState state) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final server = state.servers[index];
        final isConnecting = state.status == ServerSelectionStatus.connecting;
        final isCurrent = state.activeServer?.serverId == server.serverId;

        return ListTile(
          tileColor: isCurrent ? Colors.teal.withValues(alpha: 0.1) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCurrent ? Colors.teal : Colors.grey.shade300,
              width: isCurrent ? 2 : 1,
            ),
          ),
          leading: Icon(
            Icons.dns_rounded,
            color: isCurrent ? Colors.teal : Colors.grey,
          ),
          title: Text(
            server.serverId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${server.host}:${server.port} · Zone: ${server.zone}'),
          trailing: ElevatedButton(
            onPressed: isConnecting
                ? null
                : () => context
                    .read<ServerSelectionBloc>()
                    .add(ServerSelectionServerSelected(server)),
            child: Text(isCurrent ? 'Đang dùng' : 'Kết nối'),
          ),
        );
      },
    );
  }

  Widget _buildServerGrid(BuildContext context, ServerSelectionState state) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.servers.length,
      itemBuilder: (context, index) {
        final server = state.servers[index];
        final isConnecting = state.status == ServerSelectionStatus.connecting;
        final isCurrent = state.activeServer?.serverId == server.serverId;

        return Card(
          elevation: isCurrent ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCurrent ? Colors.teal : Colors.grey.shade300,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_rounded, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        server.serverId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  'IP: ${server.host}:${server.port}\nZone: ${server.zone}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: isConnecting
                        ? null
                        : () => context
                            .read<ServerSelectionBloc>()
                            .add(ServerSelectionServerSelected(server)),
                    child: Text(isCurrent ? 'Đang dùng' : 'Kết nối'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualSection(
    BuildContext context,
    ServerSelectionState state,
    ThemeData theme,
  ) {
    final isConnecting = state.status == ServerSelectionStatus.connecting;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập IP:Port thủ công',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dùng khi router chặn mDNS multicast hoặc server nằm ở subnet khác.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ IP',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8080',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Kết nối'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: isConnecting
                      ? null
                      : () {
                          final host = _hostController.text.trim();
                          final port = int.tryParse(_portController.text.trim()) ?? 8080;
                          if (host.isNotEmpty) {
                            context.read<ServerSelectionBloc>().add(
                                  ServerSelectionManualConnectRequested(
                                    host: host,
                                    port: port,
                                  ),
                                );
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
