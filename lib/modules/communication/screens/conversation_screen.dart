import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/message_extras.dart';
import '../widgets/coach_marks.dart';
import '../widgets/group_info_sheet.dart';
import '../widgets/readers_bottom_sheet.dart';
import '../widgets/voice_record_bar.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/poll_message_widget.dart';
import 'media_gallery_screen.dart';
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
  // maxScrollExtent lúc bắt đầu nạp tin cũ — để giữ nguyên chỗ đang đọc khi
  // trang cũ được chèn lên đầu danh sách.
  double? _extentBeforeOlder;
  String? _lastMessageId;
  final FocusNode _inputFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showScrollToBottom = false;
  bool _showQuickReplyTray = false;
  bool _isRecordingVoice = false;
  bool _isSearching = false;
  final TextEditingController _inConvoSearchController = TextEditingController();
  String _inConvoSearchQuery = '';

  // Phase 1: trả lời / sửa / chọn nhiều tin / nháp
  ChatMessage? _replyingTo;
  ChatMessage? _editing;
  String? _stashedDraft; // nháp đang soạn dở khi bấm "sửa tin"
  final Set<String> _selected = {};
  final Map<String, GlobalKey> _msgKeys = {};

  /// Sửa/thu hồi với mọi người, cảm xúc, ghim đi bằng sự kiện E2EE nên chỉ có
  /// ở hội thoại 1-1. Trả lời, sao chép, chuyển tiếp, xoá ở máy tôi dùng được
  /// ở mọi hội thoại.
  bool get _isDirect =>
      widget.conversationId.startsWith('direct_') ||
      widget.conversationId.startsWith('group_');
  bool get _isGroup => widget.conversationId.startsWith('group_');
  bool get _selecting => _selected.isNotEmpty;
  String get _draftKey => 'chat_draft::${widget.conversationId}';

  // Accessibility Font size options state
  ChatFontSizeOption _fontSizeOption = ChatFontSizeOption.medium;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(OpenConversationEvent(widget.conversationId));
    _scrollController.addListener(_scrollListener);
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft != null &&
        draft.isNotEmpty &&
        mounted &&
        _messageController.text.isEmpty) {
      _messageController.text = draft;
      _messageController.selection =
          TextSelection.collapsed(offset: draft.length);
    }
  }

  /// Lưu nháp của hội thoại này. Đang sửa tin thì không lưu — nội dung ô soạn
  /// lúc đó là tin cũ, không phải nháp.
  void _saveDraft() {
    if (_editing != null) return;
    final key = _draftKey;
    final text = _messageController.text;
    SharedPreferences.getInstance().then((prefs) {
      if (text.trim().isEmpty) {
        prefs.remove(key);
      } else {
        prefs.setString(key, text);
      }
    });
  }

  @override
  void dispose() {
    _saveDraft();
    _messageController.dispose();
    _inConvoSearchController.dispose();
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

    // Người dùng tự cuộn lên gần đầu danh sách → nạp trang tin cũ hơn. Chỉ
    // tính cuộn do người dùng: lúc mở hội thoại, animateTo xuống cuối cũng đi
    // ngang đầu danh sách và sẽ nạp nhầm.
    if (_scrollController.position.userScrollDirection ==
            ScrollDirection.forward &&
        currentScroll <= _scrollController.position.minScrollExtent + 120 &&
        _extentBeforeOlder == null) {
      final state = context.read<ChatBloc>().state;
      if (state.hasMoreHistory && !state.isLoadingOlder) {
        _extentBeforeOlder = maxScroll;
        context
            .read<ChatBloc>()
            .add(LoadOlderMessagesEvent(widget.conversationId));
      }
    }

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

    final bloc = context.read<ChatBloc>();
    final editing = _editing;
    if (editing != null && quickReply == null) {
      bloc.add(EditMessageEvent(widget.conversationId, editing.id, text));
      _finishEdit();
    } else {
      bloc.add(SendMessageEvent(
        conversationId: widget.conversationId,
        text: text,
        replyToId: _replyingTo?.id,
      ));
      if (_replyingTo != null) setState(() => _replyingTo = null);
      if (quickReply == null) {
        _messageController.clear();
        _onTextChanged('');
        _saveDraft(); // ô soạn trống → xoá nháp đã lưu
      }
    }
    Timer(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _startEdit(ChatMessage message) {
    _stashedDraft ??= _messageController.text;
    final text = messageText(message);
    setState(() {
      _editing = message;
      _replyingTo = null;
    });
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
    _inputFocusNode.requestFocus();
  }

  void _finishEdit() {
    final draft = _stashedDraft ?? '';
    _stashedDraft = null;
    setState(() => _editing = null);
    _messageController.text = draft;
    _messageController.selection = TextSelection.collapsed(offset: draft.length);
    _onTextChanged(draft);
  }

  void _onSendVoiceMessage(VoiceRecordingResult res) {
    setState(() => _isRecordingVoice = false);
    context.read<ChatBloc>().add(SendMessageEvent(
          conversationId: widget.conversationId,
          text: '🎤 Voice message (${res.durationSeconds}s)',
          type: ChatMessageType.audio,
          extraContent: {
            'duration_sec': res.durationSeconds,
            'waveform': res.waveform,
            'audio_path': res.audioPath,
          },
        ));
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
          const SnackBar(content: Text('Cannot call yourself.')),
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
            title: const Text('Microphone Permission Required'),
            content: const Text(
                'Microphone permission is required to make calls. Please tap "Open Settings" to grant access.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    const currentUserName = 'Me';
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
      final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      
      // On Windows/Desktop: camera might not be supported via image_picker
      if (isDesktop && source == ImageSource.camera) {
        _showErrorSnackBar('Camera is not supported directly on desktop. Please select an image from Gallery or Files.');
        return;
      }

      if (!isDesktop) {
        final permission = source == ImageSource.camera ? Permission.camera : Permission.photos;
        final granted = await permission.request().isGranted;
        if (!granted && source == ImageSource.camera) {
          _showPermissionWarning('Camera access was denied.');
          return;
        }
      }
      
      String? pickedPath;
      String? pickedName;

      if (isDesktop) {
        // Use FilePicker for native desktop file selection without mobile permission issues
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) return;
        pickedPath = result.files.first.path;
        pickedName = result.files.first.name;
      } else {
        final XFile? image = await _picker.pickImage(source: source);
        if (image == null) return;
        pickedPath = image.path;
        pickedName = image.name;
      }

      if (pickedPath == null) return;
      
      // Check size limit: 20MB
      final File file = File(pickedPath);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
        _showErrorSnackBar('File size exceeds the 20MB limit.');
        return;
      }
      
      // Save permanently to local app storage
      final savedFile = await _saveFileToLocalChatDir(file, pickedName ?? 'image.jpg');
      
      final att = AttachmentFile(
        id: 'file_${DateTime.now().millisecondsSinceEpoch}_${(pickedName ?? 'img').hashCode % 10000}',
        name: pickedName ?? 'image.jpg',
        mimeType: _getMimeType(pickedPath),
        fileSize: size,
        localUri: savedFile.path,
        uploadStatus: 'pending',
      );
      
      if (!mounted) return;
      context.read<ChatBloc>().add(PickAttachmentsEvent([att]));
    } catch (e) {
      _showErrorSnackBar('Failed to select image: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final List<AttachmentFile> pickedFiles = [];
      for (var f in result.files) {
        if (f.path == null) continue;
        
        final file = File(f.path!);
        final size = f.size;
        if (size > 20 * 1024 * 1024) {
          _showErrorSnackBar('File ${f.name} exceeds the 20MB limit.');
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
      _showErrorSnackBar('Failed to select document: $e');
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
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Settings'),
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
        appBar: _selecting
            ? _buildSelectionAppBar(context, isDark)
            : AppBar(
          automaticallyImplyLeading: !widget.embedded,
          backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
          elevation: 1,
          titleSpacing: widget.embedded ? 16 : 0,
          title: _isGroup
              ? FutureBuilder<GroupDetails?>(
                  future: chatBloc.chatRepository
                      .getGroupDetails(widget.conversationId),
                  builder: (context, groupSnapshot) {
                    final group = groupSnapshot.data;
                    final title = group?.title ?? 'Group';
                    final memberCount = group?.members.length ?? 0;
                    final isBroadcast = group?.isBroadcast ?? false;
                    return InkWell(
                      onTap: () => GroupInfoSheet.show(
                          context, widget.conversationId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: ChatTheme.getAccent(isDark)
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                isBroadcast
                                    ? Icons.campaign_rounded
                                    : Icons.groups_rounded,
                                color: ChatTheme.getAccent(isDark),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: ChatTheme.getTextPrimary(
                                                isDark),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 15,
                                        color: Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBroadcast
                                        ? '$memberCount subscribers • Broadcast channel'
                                        : '$memberCount members',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ChatTheme.getTextMuted(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : FutureBuilder<User?>(
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
                      onlineDevices.any((d) => d.userId == companion.id || d.deviceId == companion.id);
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
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded,
                  color: ChatTheme.getAccent(isDark)),
              tooltip: 'Search messages',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _inConvoSearchController.clear();
                    _inConvoSearchQuery = '';
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.perm_media_outlined,
                  color: ChatTheme.getAccent(isDark)),
              tooltip: 'Media & Files',
              onPressed: () => MediaGalleryScreen.show(
                  context, widget.conversationId, chatBloc.chatRepository),
            ),
            if (_isGroup)
              IconButton(
                icon: Icon(Icons.info_outline_rounded,
                    color: ChatTheme.getAccent(isDark)),
                tooltip: 'Group info',
                onPressed: () =>
                    GroupInfoSheet.show(context, widget.conversationId),
              )
            else
              FutureBuilder<User?>(
                future: chatBloc.chatRepository
                    .getCompanion(widget.conversationId, currentUserId),
                builder: (context, snapshot) {
                  final companion = snapshot.data;
                  if (companion == null) return const SizedBox();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: ChatTheme.getAccent(isDark).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.phone_rounded, color: ChatTheme.getAccent(isDark), size: 19),
                          tooltip: 'Voice Call',
                          padding: EdgeInsets.zero,
                          onPressed: () => _startCall(context, 'audio', companion),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.videocam_rounded, color: Color(0xFF06B6D4), size: 20),
                          tooltip: 'Video Call',
                          padding: EdgeInsets.zero,
                          onPressed: () => _startCall(context, 'video', companion),
                        ),
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
                _buildPinnedBar(isDark),
                // Messages Feed
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      if (state.isLoadingOlder) return;

                      // Vừa chèn trang cũ lên đầu: dời vị trí cuộn đúng bằng
                      // phần nội dung được thêm để màn hình đứng yên.
                      final extentBefore = _extentBeforeOlder;
                      if (extentBefore != null) {
                        _extentBeforeOlder = null;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_scrollController.hasClients) return;
                          final pos = _scrollController.position;
                          final delta = pos.maxScrollExtent - extentBefore;
                          if (delta > 0) _scrollController.jumpTo(pos.pixels + delta);
                        });
                        return;
                      }

                      // Chỉ kéo xuống cuối khi có tin MỚI ở cuối — trước đây
                      // mọi thay đổi state (đang gõ, online) đều kéo xuống,
                      // người đang đọc tin cũ bị giật về cuối.
                      final lastId = state.activeMessages.isEmpty
                          ? null
                          : state.activeMessages.last.id;
                      if (lastId != _lastMessageId) {
                        _lastMessageId = lastId;
                        Timer(const Duration(milliseconds: 100), _scrollToBottom);
                      }
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

                      final list = ListView.builder(
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
                              KeyedSubtree(
                                key: _msgKeys.putIfAbsent(
                                    message.id, () => GlobalKey()),
                                child: _buildMessageBubble(
                                    context, message, isMe, isDark),
                              ),
                            ],
                          );
                        },
                      );
                      if (!state.isLoadingOlder) return list;
                      return Stack(
                        children: [
                          list,
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        ],
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
    final bloc = context.read<ChatBloc>();
    final state = bloc.state;
    final myId = bloc.currentUserId ?? '';
    final accent = ChatTheme.getAccent(isDark);
    final selected = _selected.contains(message.id);

    Widget framed(Widget child) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _selecting ? () => _toggleSelect(message.id) : null,
        onLongPress:
            _selecting ? null : () => _openMessageActions(context, message, isMe),
        child: Container(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          child: Row(
            children: [
              if (_selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected ? accent : ChatTheme.getTextMuted(isDark),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tin đã xoá / thu hồi: chỉ còn dấu vết, không còn nội dung.
    if (message.isDeleted) {
      return framed(Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded,
                size: 14, color: ChatTheme.getTextMuted(isDark)),
            const SizedBox(width: 6),
            Text(
              context.tr('chat_msg_deleted'),
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: ChatTheme.getTextMuted(isDark),
              ),
            ),
          ],
        ),
      ));
    }

    final content = decodeMessageContent(message.content);
    final text = (content['text'] as String?) ?? '';
    final sentTime = DateFormat('h:mm a').format(message.sentAt.toLocal());
    final fontSize = ChatTheme.getFontSize(_fontSizeOption);
    final textColor = isMe ? Colors.white : ChatTheme.getTextPrimary(isDark);
    final mutedColor = isMe
        ? Colors.white.withValues(alpha: 0.75)
        : ChatTheme.getTextMuted(isDark);

    List<AttachmentFile> bubbleAttachments = [];
    try {
      if (content['attachments'] != null) {
        bubbleAttachments = (content['attachments'] as List)
            .map((x) =>
                AttachmentFile.fromMap(Map<String, dynamic>.from(x as Map)))
            .toList();
      }
    } catch (_) {}

    final isForwarded =
        message.forwardedFromId != null || content['forwarded_from'] != null;
    final forwardedName = content['forwarded_from']?.toString() ?? '';
    final reactions = state.reactionsMap[message.id] ?? const [];
    final pending = isMe && state.pendingSendIds.contains(message.id);

    return framed(Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMe && _isGroup)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              message.senderId,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        Container(
          margin: EdgeInsets.only(top: 6, bottom: reactions.isEmpty ? 6 : 2),
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
              if (isForwarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_rounded, size: 13, color: mutedColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          context
                              .tr('chat_forwarded_from')
                              .replaceAll('{name}', forwardedName)
                              .trim(),
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.replyToId != null)
                ReplyQuote(
                  replyToId: message.replyToId!,
                  onMineBubble: isMe,
                  isDark: isDark,
                  myId: myId,
                  onTap: () => _scrollToMessage(message.replyToId!),
                ),
              if (message.type == 'audio' || content['duration_sec'] != null)
                VoiceMessageBubble(
                  durationSeconds: (content['duration_sec'] as num?)?.toInt() ?? 5,
                  waveform: (content['waveform'] as List?)
                          ?.map((e) => (e as num).toDouble())
                          .toList() ??
                      const [],
                  isMe: isMe,
                  isDark: isDark,
                )
              else if (message.type == 'poll' || content['poll_question'] != null)
                PollMessageWidget(
                  question: content['poll_question']?.toString() ?? 'Poll',
                  options: (content['poll_options'] as List?)
                          ?.map((e) => PollOption.fromMap(Map<String, dynamic>.from(e as Map)))
                          .toList() ??
                      const [],
                  allowMultiple: content['poll_allow_multiple'] == true,
                  currentUserId: myId,
                  isDark: isDark,
                  isMe: isMe,
                  onVote: (optId) {
                    // Cập nhật vote
                  },
                )
              else if (text.isNotEmpty) ...[
                Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    height: 1.5,
                  ),
                ),
                for (final u in LinkPreviewCard.extractUrls(text))
                  LinkPreviewCard(url: u, isDark: isDark, isMe: isMe),
              ],
              if (bubbleAttachments.isNotEmpty)
                _buildBubbleAttachments(
                    message, bubbleAttachments, isMe, isDark),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.pinnedAt != null) ...[
                      Icon(Icons.push_pin_rounded, size: 11, color: mutedColor),
                      const SizedBox(width: 4),
                    ],
                    if (message.editedAt != null) ...[
                      Text(
                        context.tr('chat_edited'),
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: mutedColor),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      sentTime,
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      if (_isGroup)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              ReadersBottomSheet.show(
                            context,
                            conversationId: widget.conversationId,
                            messageId: message.id,
                            repository: bloc.chatRepository,
                          ),
                          child: _buildStatusTick(message, pending: pending),
                        )
                      else
                        _buildStatusTick(message, pending: pending),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ReactionsRow(
              reactions: reactions,
              myId: myId,
              isDark: isDark,
              onTap: (emoji) => bloc.add(
                  ToggleReactionEvent(widget.conversationId, message.id, emoji)),
            ),
          ),
      ],
    ));
  }

  Widget _buildStatusTick(ChatMessage message, {bool pending = false}) {
    if (pending) {
      // Còn nằm trong hàng đợi E2EE, chưa tới server.
      return const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70);
    }
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
    if (_isGroup) {
      final bloc = context.read<ChatBloc>();
      final me = bloc.currentUserId ?? '';
      return FutureBuilder<bool>(
        future: bloc.chatRepository.canUserPost(widget.conversationId, me),
        builder: (context, snapshot) {
          final canPost = snapshot.data ?? true;
          if (!canPost) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_rounded,
                        size: 20, color: ChatTheme.getTextMuted(isDark)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Only administrators can send messages in this channel',
                        style: TextStyle(
                          fontSize: 13,
                          color: ChatTheme.getTextMuted(isDark),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildInputBarContent(context, isDark);
        },
      );
    }
    return _buildInputBarContent(context, isDark);
  }

  Widget _buildInputBarContent(BuildContext context, bool isDark) {
    if (_isRecordingVoice) {
      return VoiceRecordBar(
        isDark: isDark,
        onSend: _onSendVoiceMessage,
        onCancel: () => setState(() => _isRecordingVoice = false),
      );
    }
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
                // Đang trả lời / đang sửa một tin
                _buildComposerContextBar(context, isDark),

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
                                    setState(() => _isRecordingVoice = true);
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

  Future<void> _openMessageActions(
      BuildContext context, ChatMessage message, bool isMe) async {
    final bloc = context.read<ChatBloc>();
    final me = bloc.currentUserId ?? '';
    final isGroupAdmin = _isGroup &&
        await bloc.chatRepository.isUserAdmin(widget.conversationId, me);
    if (!context.mounted) return;
    showMessageActionsSheet(
      context: context,
      message: message,
      isMe: isMe,
      isDirect: _isDirect,
      canDeleteEveryone: isGroupAdmin,
      onAction: (action) => _handleMessageAction(action, message),
      onReact: (emoji) => bloc.add(
          ToggleReactionEvent(widget.conversationId, message.id, emoji)),
    );
  }

  Future<void> _handleMessageAction(
      MessageAction action, ChatMessage message) async {
    final bloc = context.read<ChatBloc>();
    switch (action) {
      case MessageAction.reply:
        setState(() {
          _replyingTo = message;
          _editing = null;
        });
        _inputFocusNode.requestFocus();
        break;
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: messageText(message)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('chat_copied')),
            duration: const Duration(seconds: 1),
          ));
        }
        break;
      case MessageAction.edit:
        _startEdit(message);
        break;
      case MessageAction.forward:
        await _forward([message]);
        break;
      case MessageAction.pin:
        bloc.add(TogglePinEvent(widget.conversationId, message.id));
        break;
      case MessageAction.select:
        setState(() => _selected.add(message.id));
        break;
      case MessageAction.deleteForMe:
        bloc.add(RevokeMessageEvent(widget.conversationId, message.id));
        break;
      case MessageAction.deleteForEveryone:
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('chat_action_delete_everyone')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('chat_cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('chat_action_delete_everyone')),
              ),
            ],
          ),
        );
        if (ok == true) {
          bloc.add(RevokeMessageEvent(widget.conversationId, message.id,
              forEveryone: true));
        }
        break;
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  List<ChatMessage> _selectedMessages() => context
      .read<ChatBloc>()
      .state
      .activeMessages
      .where((m) => _selected.contains(m.id))
      .toList();

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context, bool isDark) {
    final bloc = context.read<ChatBloc>();
    return AppBar(
      backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length} ${context.tr('chat_selected_count')}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            final text = _selectedMessages()
                .where((m) => !m.isDeleted)
                .map(messageText)
                .where((t) => t.isNotEmpty)
                .join('\n');
            await Clipboard.setData(ClipboardData(text: text));
            if (!mounted) return;
            setState(_selected.clear);
            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
              content: Text(this.context.tr('chat_copied')),
              duration: const Duration(seconds: 1),
            ));
          },
        ),
        IconButton(
          icon: const Icon(Icons.forward_rounded),
          onPressed: () => _forward(_selectedMessages()),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: ChatTheme.getDanger(isDark)),
          onPressed: () {
            for (final m in _selectedMessages()) {
              bloc.add(RevokeMessageEvent(widget.conversationId, m.id));
            }
            setState(_selected.clear);
          },
        ),
      ],
    );
  }

  /// Chuyển tiếp sang hội thoại 1-1 với từng người được chọn.
  Future<void> _forward(List<ChatMessage> messages) async {
    final bloc = context.read<ChatBloc>();
    final myId = bloc.currentUserId ?? '';
    final targets = await pickForwardTargets(context, myId);
    if (targets == null || targets.isEmpty || !mounted) return;

    final convoIds = <String>[];
    for (final u in targets) {
      final convo =
          await bloc.chatRepository.getOrCreateDirectConversation(myId, u.id);
      convoIds.add(convo.id);
    }
    bloc.add(ForwardMessagesEvent(messages, convoIds));
    if (mounted) setState(_selected.clear);
  }

  Widget _buildPinnedBar(bool isDark) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (a, b) => a.pinnedMessages != b.pinnedMessages,
      builder: (context, state) => PinnedMessagesBar(
        pinned: state.pinnedMessages,
        isDark: isDark,
        onTap: (m) => _scrollToMessage(m.id),
        onUnpin: (m) => context
            .read<ChatBloc>()
            .add(TogglePinEvent(widget.conversationId, m.id)),
      ),
    );
  }

  Widget _buildComposerContextBar(BuildContext context, bool isDark) {
    final myId = context.read<ChatBloc>().currentUserId ?? '';
    final editing = _editing;
    if (editing != null) {
      return ComposerContextBar(
        icon: Icons.edit_rounded,
        title: context.tr('chat_editing'),
        subtitle: messagePreview(context, editing),
        isDark: isDark,
        onCancel: _finishEdit,
      );
    }
    final replying = _replyingTo;
    if (replying != null) {
      return ComposerContextBar(
        icon: Icons.reply_rounded,
        title: context.tr('chat_replying_to').replaceAll(
            '{name}', senderLabel(context, replying.senderId, myId)),
        subtitle: messagePreview(context, replying),
        isDark: isDark,
        onCancel: () => setState(() => _replyingTo = null),
      );
    }
    return const SizedBox.shrink();
  }

  /// Cuộn tới một tin. Tin chưa được dựng (ở xa) thì nhảy gần đúng rồi thử lại;
  /// tin thuộc trang cũ chưa nạp thì bỏ qua.
  Future<void> _scrollToMessage(String id) async {
    var ctx = _msgKeys[id]?.currentContext;
    if (ctx == null) {
      final msgs = context.read<ChatBloc>().state.activeMessages;
      final idx = msgs.indexWhere((m) => m.id == id);
      if (idx < 0 || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final denom = msgs.length > 1 ? msgs.length - 1 : 1;
      _scrollController.jumpTo(
          (pos.maxScrollExtent * idx / denom)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      ctx = _msgKeys[id]?.currentContext;
    }
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
          curve: Curves.easeOut);
    }
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
                title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                title: const Text('Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_rounded, color: Colors.green),
                title: const Text('Documents & Files', style: TextStyle(fontWeight: FontWeight.bold)),
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
    ChatMessage message,
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
              final progressKey = '${message.id}_${file.id}';
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
                              'Uploading: ${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),

                    if (file.uploadStatus == 'failed')
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 14),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Upload failed. Will retry when online.',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 10),
                              ),
                            ),
                            if (isMe)
                              InkWell(
                                onTap: () {
                                  context
                                      .read<ChatBloc>()
                                      .add(RetryUploadAttachmentEvent(message));
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh,
                                          color: Colors.cyanAccent, size: 14),
                                      SizedBox(width: 2),
                                      Text(
                                        'Retry',
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
        const SnackBar(content: Text('File has not been uploaded to server.')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading: ${file.name}...')),
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
          content: Text('Downloaded successfully: ${file.name}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open folder',
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
        SnackBar(content: Text('Download failed: $e')),
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
