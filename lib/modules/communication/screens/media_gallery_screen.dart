import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_service.dart';
import '../models/chat_models.dart';
import '../repository/chat_repository.dart';
import '../theme/chat_theme.dart';
import '../widgets/link_preview_card.dart';

/// Màn hình quản lý và duyệt toàn bộ Phương tiện, Tệp tin và Liên kết trong cuộc hội thoại.
class MediaGalleryScreen extends StatefulWidget {
  final String conversationId;
  final ChatRepository repository;

  const MediaGalleryScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  static Future<void> show(BuildContext context, String conversationId, ChatRepository repository) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaGalleryScreen(
          conversationId: conversationId,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  final List<AttachmentFile> _mediaItems = [];
  final List<AttachmentFile> _fileItems = [];
  final List<LinkItem> _linkItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    // Nạp lịch sử tin nhắn của cuộc hội thoại
    final messages = await widget.repository.getMessages(widget.conversationId, limit: 500);

    _mediaItems.clear();
    _fileItems.clear();
    _linkItems.clear();

    for (final m in messages) {
      if (m.isDeleted) continue;

      // Trích xuất đính kèm
      try {
        final contentMap = jsonDecode(m.content) as Map<String, dynamic>;
        final rawAtts = contentMap['attachments'];
        if (rawAtts is List) {
          for (final a in rawAtts) {
            if (a is Map<String, dynamic>) {
              final file = AttachmentFile.fromMap(a);
              if (file.mimeType.startsWith('image/') || file.mimeType.startsWith('video/')) {
                _mediaItems.add(file);
              } else {
                _fileItems.add(file);
              }
            }
          }
        }

        // Trích xuất liên kết từ văn bản
        final text = contentMap['text']?.toString() ?? '';
        final urls = LinkPreviewCard.extractUrls(text);
        for (final u in urls) {
          _linkItems.add(LinkItem(url: u, senderId: m.senderId, sentAt: m.sentAt, contextText: text));
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ChatTheme.getAccent(isDark);

    return Scaffold(
      backgroundColor: ChatTheme.getBgPrimary(isDark),
      appBar: AppBar(
        title: const Text('Media, Files & Links'),
        backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: accent,
          unselectedLabelColor: ChatTheme.getTextMuted(isDark),
          indicatorColor: accent,
          tabs: [
            Tab(text: 'Media (${_mediaItems.length})'),
            Tab(text: 'Files (${_fileItems.length})'),
            Tab(text: 'Links (${_linkItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaTab(isDark),
                _buildFilesTab(isDark),
                _buildLinksTab(isDark),
              ],
            ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
    if (_mediaItems.isEmpty) {
      return Center(
        child: Text('No photos or videos yet', style: TextStyle(color: ChatTheme.getTextMuted(isDark))),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final item = _mediaItems[index];
        return GestureDetector(
          onTap: () => _viewImage(item),
          child: Container(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            child: item.localUri != null && File(item.localUri!).existsSync()
                ? Image.file(File(item.localUri!), fit: BoxFit.cover)
                : (item.remoteUrl != null
                    ? FutureBuilder<String>(
                        future: SettingsService().getSyncServerUrl(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final fullUrl = item.remoteUrl!.startsWith('http') ? item.remoteUrl! : '${snapshot.data}${item.remoteUrl}';
                          return CachedNetworkImage(
                            imageUrl: fullUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                          );
                        },
                      )
                    : const Icon(Icons.image_not_supported_rounded)),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(bool isDark) {
    if (_fileItems.isEmpty) {
      return Center(
        child: Text('No document files yet', style: TextStyle(color: ChatTheme.getTextMuted(isDark))),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _fileItems.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      itemBuilder: (context, index) {
        final file = _fileItems[index];
        final isPdf = file.mimeType == 'application/pdf';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isPdf ? Colors.redAccent.withValues(alpha: 0.15) : Colors.blueAccent.withValues(alpha: 0.15),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              color: isPdf ? Colors.redAccent : Colors.blueAccent,
            ),
          ),
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${(file.fileSize / 1024).toStringAsFixed(1)} KB'),
          trailing: const Icon(Icons.download_rounded),
          onTap: () {
            // Tải xuống hoặc mở file
          },
        );
      },
    );
  }

  Widget _buildLinksTab(bool isDark) {
    if (_linkItems.isEmpty) {
      return Center(
        child: Text('No links shared yet', style: TextStyle(color: ChatTheme.getTextMuted(isDark))),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _linkItems.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(item.sentAt);

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF10B981),
            child: Icon(Icons.link_rounded, color: Colors.white),
          ),
          title: Text(item.url, style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${item.senderId} • $timeStr'),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () async {
            final uri = Uri.parse(item.url.startsWith('http') ? item.url : 'https://${item.url}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }

  void _viewImage(AttachmentFile file) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: file.localUri != null && File(file.localUri!).existsSync()
                  ? Image.file(File(file.localUri!))
                  : FutureBuilder<String>(
                      future: SettingsService().getSyncServerUrl(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final fullUrl = file.remoteUrl!.startsWith('http') ? file.remoteUrl! : '${snapshot.data}${file.remoteUrl}';
                        return CachedNetworkImage(imageUrl: fullUrl);
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class LinkItem {
  final String url;
  final String senderId;
  final DateTime sentAt;
  final String contextText;

  const LinkItem({
    required this.url,
    required this.senderId,
    required this.sentAt,
    required this.contextText,
  });
}
