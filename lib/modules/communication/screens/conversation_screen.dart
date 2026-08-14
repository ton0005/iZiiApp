import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/device_identity/device_discovery_service.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../../../core/device_identity/device_identity_models.dart';
import '../call/call_bloc.dart';
import '../call/call_screen.dart';
import '../call/incoming_call_service.dart';
import '../../../core/settings/settings_service.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_models.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/quick_reply_tray.dart';
import '../widgets/coach_marks.dart';
import '../theme/chat_theme.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final bool
      embedded; // Hides AppBar back navigation when embedded in Split View

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showScrollToBottom = false;
  bool _showQuickReplyTray = false;

  // Accessibility Font size options state
  ChatFontSizeOption _fontSizeOption = ChatFontSizeOption.medium;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(OpenConversationEvent(widget.conversationId));
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _typingTimer?.cancel();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Show scroll to bottom button if scrolled up by more than 200px
    if (maxScroll - currentScroll > 200.0) {
      if (!_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = true;
        });
      }
    } else {
      if (_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String text) {
    setState(() {}); // Rebuild to update textInputAction and send/mic button dynamically
    
    if (text.isEmpty && _isTyping) {
      _isTyping = false;
      context
          .read<ChatBloc>()
          .add(SendTypingStateEvent(widget.conversationId, false));
    } else if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      context
          .read<ChatBloc>()
          .add(SendTypingStateEvent(widget.conversationId, true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        context
            .read<ChatBloc>()
            .add(SendTypingStateEvent(widget.conversationId, false));
      }
    });
  }

  void _sendMessage({String? quickReply}) {
    final text = quickReply ?? _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatBloc>().add(SendMessageEvent(
          conversationId: widget.conversationId,
          text: text,
        ));

    if (quickReply == null) {
      _messageController.clear();
      _onTextChanged('');
    }
    Timer(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _submitMessageFlow() {
    final text = _messageController.text.trim();
    final draftAttachments = context.read<ChatBloc>().state.draftAttachments;
    
    if (text.isEmpty && draftAttachments.isEmpty) return;
    
    if (draftAttachments.isNotEmpty) {
      context.read<ChatBloc>().add(SendMessageWithAttachmentsEvent(
            conversationId: widget.conversationId,
            text: text,
          ));
      _messageController.clear();
      _onTextChanged('');
    } else {
      _sendMessage();
    }
  }

  Future<void> _startCall(BuildContext context, String callType, User companion) async {
    final chatBloc = context.read<ChatBloc>();
    final currentUserId = chatBloc.currentUserId ?? 'user_1';

    if (companion.id == currentUserId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tự gọi cho chính mình.')),
        );
      }
      return;
    }

    // Yêu cầu hệ thống kích hoạt hộp thoại xin quyền Micro & Camera
    final micStatus = await Permission.microphone.request();
    if (callType == 'video') {
      await Permission.camera.request();
    }

    if (micStatus.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cần cấp quyền Micro'),
            content: const Text(
                'Ứng dụng cần quyền Micro để thực hiện cuộc gọi. Bạn hãy bấm "Mở Cài đặt" để cho phép iZiiApp sử dụng Micro.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Mở Cài đặt'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final currentUserName = 'Me';
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';

    // Dùng LẠI bloc toàn cục thay vì tạo CallBloc mới mỗi lần bấm gọi.
    // Hai bloc = hai kết nối /call/ws cùng một client_id, server chỉ giữ cái
    // sau nên cái trước thành mồ côi và tín hiệu gửi vào đó rơi mất.
    final callService = IncomingCallService();
    await callService.ensureConnected(currentUserId);
    final callBloc = callService.bloc;
    callBloc.add(StartCallEvent(
      callId: callId,
      callerId: currentUserId,
      callerName: currentUserName,
      calleeId: companion.id,
      calleeName: companion.name,
      callType: callType,
    ));

    if (!context.mounted) return;

    // Báo cho service biết màn hình gọi đã mở, để nó không đẩy thêm một màn
    // hình nữa khi bloc chuyển sang trạng thái đổ chuông.
    callService.markScreenOpen();
    Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => BlocProvider.value(
              value: callBloc,
              child: const CallScreen(),
            ),
          ),
        )
        .whenComplete(callService.markScreenClosed);
  }

  TextInputAction _getTextInputAction() {
    final hasText = _messageController.text.trim().isNotEmpty;
    return hasText ? TextInputAction.send : TextInputAction.newline;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final permission = source == ImageSource.camera ? Permission.camera : Permission.photos;
      final granted = await permission.request().isGranted;
      if (!granted && source == ImageSource.camera) {
        _showPermissionWarning('Quyền truy cập Máy ảnh bị từ chối.');
        return;
      }
      
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;
      
      // Check size limit: 20MB
      final File file = File(image.path);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
        _showErrorSnackBar('Dung lượng tệp vượt quá giới hạn 20MB.');
        return;
      }
      
      // Save permanently to local app storage
      final savedFile = await _saveFileToLocalChatDir(file, image.name);
      
      final att = AttachmentFile(
        id: 'file_${DateTime.now().millisecondsSinceEpoch}_${image.name.hashCode % 10000}',
        name: image.name,
        mimeType: _getMimeType(image.path),
        fileSize: size,
        localUri: savedFile.path,
        uploadStatus: 'pending',
      );
      
      if (!mounted) return;
      context.read<ChatBloc>().add(PickAttachmentsEvent([att]));
    } catch (e) {
      _showErrorSnackBar('Lỗi chọn ảnh: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final List<AttachmentFile> pickedFiles = [];
      for (var f in result.files) {
        if (f.path == null) continue;
        
        final file = File(f.path!);
        final size = f.size;
        if (size > 20 * 1024 * 1024) {
          _showErrorSnackBar('Tệp ${f.name} vượt quá giới hạn 20MB.');
          continue;
        }
        
        final savedFile = await _saveFileToLocalChatDir(file, f.name);
        
        pickedFiles.add(AttachmentFile(
          id: 'file_${DateTime.now().millisecondsSinceEpoch}_${f.name.hashCode % 10000}',
          name: f.name,
          mimeType: _getMimeType(f.path!),
          fileSize: size,
          localUri: savedFile.path,
          uploadStatus: 'pending',
        ));
      }
      
      if (pickedFiles.isNotEmpty) {
        if (!mounted) return;
        context.read<ChatBloc>().add(PickAttachmentsEvent(pickedFiles));
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi chọn tài liệu: $e');
    }
  }

  Future<File> _saveFileToLocalChatDir(File file, String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatFilesDir = Directory('${appDir.path}/chat_files');
    if (!await chatFilesDir.exists()) {
      await chatFilesDir.create(recursive: true);
    }
    
    // Prevent name collision
    final String cleanName = '${DateTime.now().millisecondsSinceEpoch}_$name';
    final savedPath = '${chatFilesDir.path}/$cleanName';
    return file.copy(savedPath);
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp' || ext == 'heic') {
      return 'image/$ext';
    }
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'xls' || ext == 'xlsx') return 'application/vnd.ms-excel';
    if (ext == 'doc' || ext == 'docx') return 'application/msword';
    if (ext == 'zip') return 'application/zip';
    return 'application/octet-stream';
  }

  void _showPermissionWarning(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu quyền truy cập'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Đóng'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Cài đặt'),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBloc = context.read<ChatBloc>();
    final currentUserId = chatBloc.currentUserId ?? '';

    return CoachMarks(
      featureKey: 'chat_interface',
      child: Scaffold(
        backgroundColor: ChatTheme.getBgPrimary(isDark),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
          elevation: 1,
          titleSpacing: widget.embedded ? 16 : 0,
          title: FutureBuilder<User?>(
            future: chatBloc.chatRepository
                .getCompanion(widget.conversationId, currentUserId),
            builder: (context, companionSnapshot) {
              if (!companionSnapshot.hasData) {
                return const SizedBox();
              }
              final companion = companionSnapshot.data!;

              return FutureBuilder<List<RemoteDevice>>(
                future: DeviceDiscoveryService().getOnlineDevices(),
                builder: (context, onlineSnapshot) {
                  final onlineDevices = onlineSnapshot.data ?? [];
                  final isServerOnline =
                      onlineDevices.any((d) => d.userId == companion.id);
                  final isE2ee = isServerOnline;

                  return BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      final isBleConnected = BleDeviceDiscoveryService().isUserConnectedBle(companion.id);
                      final presence = (isBleConnected || isServerOnline)
                          ? ChatPresenceState.onlineSynced 
                          : (state.userPresenceMap[companion.id] ?? ChatPresenceState.offline);
                      final isTyping = state
                              .typingUsersMap[widget.conversationId]
                              ?.contains(companion.id) ??
                          false;

                      return Row(
                        children: [
                          PresenceAvatar(
                            name: companion.name,
                            presence: presence,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      companion.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: ChatTheme.getTextPrimary(isDark),
                                      ),
                                    ),
                                    if (isE2ee) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: context.tr('chat_tooltip_e2ee'),
                                        child: const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 15,
                                          color: Color(
                                              0xFF10B981), // Emerald green
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTyping
                                      ? context.tr('chat_is_typing')
                                      : _getPresenceText(context, presence),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isTyping
                                        ? ChatTheme.getOnline(isDark)
                                        : ChatTheme.getTextMuted(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          actions: [
            FutureBuilder<User?>(
              future: chatBloc.chatRepository
                  .getCompanion(widget.conversationId, currentUserId),
              builder: (context, snapshot) {
                final companion = snapshot.data;
                if (companion == null) return const SizedBox();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.phone_rounded, color: ChatTheme.getAccent(isDark)),
                      tooltip: 'Voice Call',
                      onPressed: () => _startCall(context, 'audio', companion),
                    ),
                    IconButton(
                      icon: Icon(Icons.videocam_rounded, color: ChatTheme.getAccent(isDark)),
                      tooltip: 'Video Call',
                      onPressed: () => _startCall(context, 'video', companion),
                    ),
                  ],
                );
              },
            ),
            // Font Size Selection Menu
            PopupMenuButton<ChatFontSizeOption>(
              icon: Icon(Icons.text_fields_rounded,
                  color: ChatTheme.getAccent(isDark)),
              onSelected: (option) {
                setState(() {
                  _fontSizeOption = option;
                });
              },
              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: ChatFontSizeOption.small,
                                  child: Text(context.tr('chat_font_size_small'),
                                      style: TextStyle(
                                          fontSize:
                                              ChatTheme.getFontSize(ChatFontSizeOption.small))),
                                ),
                                PopupMenuItem(
                                  value: ChatFontSizeOption.medium,
                                  child: Text(context.tr('chat_font_size_normal'),
                                      style: TextStyle(
                                          fontSize: ChatTheme.getFontSize(
                                              ChatFontSizeOption.medium))),
                                ),
                                PopupMenuItem(
                                  value: ChatFontSizeOption.large,
                                  child: Text(context.tr('chat_font_size_large'),
                                      style: TextStyle(
                                          fontSize:
                                              ChatTheme.getFontSize(ChatFontSizeOption.large))),
                                ),
                                PopupMenuItem(
                                  value: ChatFontSizeOption.extraLarge,
                                  child: Text(context.tr('chat_font_size_extra_large'),
                                      style: TextStyle(
                                          fontSize: ChatTheme.getFontSize(
                                              ChatFontSizeOption.extraLarge))),
                                ),
                              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Messages Feed
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      Timer(const Duration(milliseconds: 100), _scrollToBottom);
                    },
                    builder: (context, state) {
                      if (state.isLoading && state.activeMessages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state.activeMessages.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('chat_no_messages_yet'),
                            style: TextStyle(
                                color: ChatTheme.getTextMuted(isDark),
                                fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: state.activeMessages.length,
                        itemBuilder: (context, index) {
                          final message = state.activeMessages[index];
                          final isMe = message.senderId == currentUserId;

                          // Group messages by day
                          bool showDateSeparator = false;
                          if (index == 0) {
                            showDateSeparator = true;
                          } else {
                            final prevMessage = state.activeMessages[index - 1];
                            final diff = message.sentAt
                                .difference(prevMessage.sentAt)
                                .inDays;
                            if (diff.abs() > 0) {
                              showDateSeparator = true;
                            }
                          }

                          return Column(
                            children: [
                              if (showDateSeparator)
                                _buildDateSeparator(message.sentAt, isDark),
                              _buildMessageBubble(
                                  context, message, isMe, isDark),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // Typing indicator row
                _buildTypingIndicator(isDark),

                // Quick Reply tray if active
                if (_showQuickReplyTray)
                  QuickReplyTray(
                    onReplySelected: (reply) {
                      _sendMessage(quickReply: reply);
                      setState(() {
                        _showQuickReplyTray = false;
                      });
                    },
                  ),

                // Message input bar
                _buildInputBar(context, isDark),
              ],
            ),

            // Scroll to bottom FAB
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 80,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: ChatTheme.getAccent(isDark),
                  child: const Icon(Icons.arrow_downward_rounded,
                      color: Colors.white),
                  onPressed: () {
                    _scrollToBottom();
                    setState(() {
                      _showScrollToBottom = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    String dateStr = '';
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate).inDays;

    if (difference == 0) {
      dateStr = context.tr('chat_time_today_separator');
    } else if (difference == 1) {
      dateStr = context.tr('chat_time_yesterday_separator');
    } else {
      dateStr = DateFormat('EEEE, d MMM').format(localDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          dateStr,
          style: TextStyle(
            color: ChatTheme.getTextMuted(isDark),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, ChatMessage message, bool isMe, bool isDark) {
    String messageText = '';
    try {
      final contentMap =
          Map<String, dynamic>.from(jsonDecode(message.content) as Map);
      messageText = contentMap['text'] as String? ?? '';
    } catch (_) {
      messageText = message.content;
    }

    final sentTime = DateFormat('h:mm a').format(message.sentAt.toLocal());
    final fontSize = ChatTheme.getFontSize(_fontSizeOption);

    List<AttachmentFile> bubbleAttachments = [];
    try {
      final contentMap =
          Map<String, dynamic>.from(jsonDecode(message.content) as Map);
      if (contentMap['attachments'] != null) {
        bubbleAttachments = (contentMap['attachments'] as List)
            .map((x) =>
                AttachmentFile.fromMap(Map<String, dynamic>.from(x as Map)))
            .toList();
      }
    } catch (_) {}

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () =>
            _showMessageActionSheet(context, messageText, message.id, isMe),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? ChatTheme.getBgBubbleMine(isDark)
                : ChatTheme.getBgBubbleTheirs(isDark),
            border: Border.all(
              color: isMe
                  ? Colors.transparent
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (messageText.isNotEmpty)
                Text(
                  messageText,
                  style: TextStyle(
                    color:
                        isMe ? Colors.white : ChatTheme.getTextPrimary(isDark),
                    fontSize: fontSize,
                    height: 1.5,
                  ),
                ),
              if (bubbleAttachments.isNotEmpty)
                _buildBubbleAttachments(
                    message.id, bubbleAttachments, isMe, isDark),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sentTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.75)
                            : ChatTheme.getTextMuted(isDark),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusTick(message),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTick(ChatMessage message) {
    if (message.readAt != null) {
      return const Icon(Icons.done_all_rounded,
          size: 14, color: Colors.cyanAccent);
    } else if (message.deliveredAt != null) {
      return const Icon(Icons.done_all_rounded,
          size: 14, color: Colors.white70);
    } else {
      return const Icon(Icons.done_rounded, size: 14, color: Colors.white70);
    }
  }

  Widget _buildTypingIndicator(bool isDark) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final typingUsers = state.typingUsersMap[widget.conversationId];
        if (typingUsers == null || typingUsers.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                context.tr('chat_typing_indicator'),
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: ChatTheme.getOnline(isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Horizontal list of selected draft attachment previews
                _buildDraftPreviewsBar(context, state),
                
                Row(
                  children: [
                    // Quick reply toggle button (⚡)
                    IconButton(
                      icon: Icon(
                        _showQuickReplyTray
                            ? Icons.bolt_rounded
                            : Icons.offline_bolt_outlined,
                        color: ChatTheme.getAccent(isDark),
                      ),
                      onPressed: () {
                        setState(() {
                          _showQuickReplyTray = !_showQuickReplyTray;
                        });
                      },
                    ),

                    // Attachment Button (📎)
                    IconButton(
                      icon: Icon(Icons.attach_file_rounded,
                          color: ChatTheme.getTextMuted(isDark)),
                      onPressed: () {
                        _showAttachmentMenu();
                      },
                    ),

                    // Text Message input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? ChatTheme.bgPrimaryDark
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.enter) {
                                    final isShiftPressed =
                                        HardwareKeyboard.instance.isShiftPressed;
                                    if (isShiftPressed) {
                                      return KeyEventResult.ignored;
                                    } else {
                                      _submitMessageFlow();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  focusNode: _inputFocusNode,
                                  controller: _messageController,
                                  onChanged: _onTextChanged,
                                  maxLines: 3,
                                  minLines: 1,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: _getTextInputAction(),
                                  onSubmitted: (_) {
                                    _submitMessageFlow();
                                  },
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: ChatTheme.getTextPrimary(isDark)),
                                  decoration: InputDecoration(
                                    hintText: context.tr('chat_type_message'),
                                    hintStyle: TextStyle(
                                        color: ChatTheme.getTextMuted(isDark)),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            // Emoji Button (😊)
                            IconButton(
                              icon: Icon(Icons.sentiment_satisfied_alt_rounded,
                                  color: ChatTheme.getTextMuted(isDark)),
                              onPressed: () {
                                // Emoji tray action
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send or Voice Action Button
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        final hasAttachments = state.draftAttachments.isNotEmpty;
                        final showSend = hasText || hasAttachments;
                        
                        return CircleAvatar(
                          backgroundColor: ChatTheme.getAccent(isDark),
                          radius: 22,
                          child: IconButton(
                            icon: Icon(
                              showSend ? Icons.send_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: showSend
                                ? _submitMessageFlow
                                : () {
                                    // Voice message recorder trigger placeholder
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            context.tr('chat_voice_recording_snack')),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageActionSheet(
      BuildContext context, String text, String messageId, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ChatTheme.bgPrimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy_rounded,
                    color: ChatTheme.getAccent(isDark)),
                title: Text(context.tr('chat_action_copy'),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: ChatTheme.getDanger(isDark)),
                  title: Text(context.tr('chat_action_delete_msg'),
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () {
                    // Soft delete logic
                    context
                        .read<ChatBloc>()
                        .chatRepository
                        .deleteMessage(messageId);
                    context
                        .read<ChatBloc>()
                        .add(OpenConversationEvent(widget.conversationId));
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: Icon(Icons.reply_rounded,
                    color: ChatTheme.getAccent(isDark)),
                title: Text(context.tr('chat_action_reply'),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPresenceText(BuildContext context, ChatPresenceState state) {
    switch (state) {
      case ChatPresenceState.onlineSynced:
        return context.tr('chat_presence_online');
      case ChatPresenceState.syncPaused:
        return context.tr('chat_presence_paused');
      case ChatPresenceState.private:
        return context.tr('chat_presence_private');
      case ChatPresenceState.offline:
        return context.tr('chat_presence_offline');
    }
  }

  Future<void> _showAttachmentMenu() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ChatTheme.bgPrimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                title: const Text('Máy ảnh (Camera)', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                title: const Text('Thư viện ảnh (Gallery)', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_rounded, color: Colors.green),
                title: const Text('Tài liệu & Tệp (Files)', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraftPreviewsBar(BuildContext context, ChatState state) {
    if (state.draftAttachments.isEmpty) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.draftAttachments.length,
        itemBuilder: (context, index) {
          final file = state.draftAttachments[index];
          final isImage = file.mimeType.startsWith('image/');

          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 70,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 60,
                    height: 60,
                    child: isImage && file.localUri != null
                        ? Image.file(
                            File(file.localUri!),
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                file.mimeType == 'application/pdf'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.insert_drive_file_rounded,
                                color: file.mimeType == 'application/pdf'
                                    ? Colors.redAccent
                                    : Colors.blueAccent,
                                size: 28,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      context
                          .read<ChatBloc>()
                          .add(RemoveAttachmentEvent(file.id));
                    },
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      child: const Icon(Icons.close_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubbleAttachments(
    String messageId,
    List<AttachmentFile> attachments,
    bool isMe,
    bool isDark,
  ) {
    if (attachments.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: attachments.map((file) {
          final isImage = file.mimeType.startsWith('image/');

          return BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final progressKey = '${messageId}_${file.id}';
              final progress = state.uploadProgressMap[progressKey];
              final isUploading = file.uploadStatus == 'uploading' ||
                  (progress != null &&
                      progress < 1.0 &&
                      file.uploadStatus == 'pending');

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage)
                      GestureDetector(
                        onTap: () {
                          _viewImage(file);
                        },
                        child: file.remoteUrl != null
                            ? _buildImageWidget(file.remoteUrl!, file.localUri)
                            : (file.localUri != null
                                ? Image.file(
                                    File(file.localUri!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 180,
                                  )
                                : const SizedBox(
                                    height: 180,
                                    child: Center(
                                        child: Icon(
                                            Icons.image_not_supported_rounded)),
                                  )),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              file.mimeType == 'application/pdf'
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.insert_drive_file_rounded,
                              color: file.mimeType == 'application/pdf'
                                  ? Colors.redAccent
                                  : (isMe ? Colors.white : Colors.blueAccent),
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : ChatTheme.getTextPrimary(isDark),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(file.fileSize / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : ChatTheme.getTextMuted(isDark),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (file.remoteUrl != null)
                              IconButton(
                                icon: Icon(
                                  Icons.download_rounded,
                                  color: isMe
                                      ? Colors.white70
                                      : ChatTheme.getTextMuted(isDark),
                                ),
                                onPressed: () {
                                  _downloadFile(file);
                                },
                              ),
                          ],
                        ),
                      ),

                    // Upload progress indicator
                    if (isUploading && progress != null)
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.cyanAccent),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Text(
                              'Đang tải lên: ${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),

                    if (file.uploadStatus == 'failed')
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Tải lên thất bại. Sẽ thử lại khi trực tuyến.',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageWidget(String remoteUrl, String? localUri) {
    if (localUri != null && File(localUri).existsSync()) {
      return Image.file(
        File(localUri),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 180,
      );
    }

    return FutureBuilder<String>(
      future: SettingsService().getSyncServerUrl(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final serverUrl = snapshot.data!;
        final fullUrl = remoteUrl.startsWith('http')
            ? remoteUrl
            : '$serverUrl$remoteUrl';
        return CachedNetworkImage(
          imageUrl: fullUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 180,
          placeholder: (context, url) => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const SizedBox(
            height: 180,
            child: Center(child: Icon(Icons.broken_image_rounded)),
          ),
        );
      },
    );
  }

  Future<void> _downloadFile(AttachmentFile file) async {
    if (file.remoteUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tệp chưa được tải lên máy chủ.')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đang tải xuống: ${file.name}...')),
      );

      final serverUrl = await SettingsService().getSyncServerUrl();
      final fullUrl = file.remoteUrl!.startsWith('http')
          ? file.remoteUrl!
          : '$serverUrl${file.remoteUrl}';

      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final savePath = p.join(dir.path, file.name);

      final dio = Dio();
      await dio.download(fullUrl, savePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tải xuống thành công: ${file.name}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Mở thư mục',
            onPressed: () async {
              final folderPath = dir.path;
              if (Platform.isWindows) {
                await Process.run('explorer.exe', [folderPath]);
              } else {
                final uri = Uri.parse('file://$folderPath');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              }
            },
          ),
        ),
      );
    } catch (e) {
      print('[DownloadError] $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tải xuống thất bại: $e')),
      );
    }
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
            actions: [
              if (file.remoteUrl != null)
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _downloadFile(file);
                  },
                ),
            ],
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
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final serverUrl = snapshot.data!;
                        final fullUrl = file.remoteUrl!.startsWith('http')
                            ? file.remoteUrl!
                            : '$serverUrl${file.remoteUrl}';
                        return CachedNetworkImage(
                          imageUrl: fullUrl,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
