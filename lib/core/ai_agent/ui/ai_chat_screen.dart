import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_models.dart';
import 'ai_message_bubble.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  Timer? _speechSendTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initSpeech();
    // Load tin nhắn chào mừng từ AiAgentService
    Future.microtask(() {
      if (mounted) {
        context.read<ChatBloc>().add(LoadHistoryEvent());
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              _pulseController.stop();
              // Auto-send after a short pause so voice transcription can complete.
              if (_controller.text.trim().isNotEmpty) {
                _scheduleSpeechSend();
              }
            }
          }
        },
        onError: (error) {
          print('[Voice] Error: ${error.errorMsg}');
          if (mounted) {
            setState(() => _isListening = false);
            _pulseController.stop();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      print('[Voice] Init error: $e');
      _speechAvailable = false;
    }
  }

  void _toggleListening() async {
    // Ensure microphone permission
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final req = await Permission.microphone.request();
      if (!req.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Vui lòng cấp quyền Micro để sử dụng tính năng ghi âm.'),
            backgroundColor: const Color(0xFFF43F5E),
            action: SnackBarAction(
              label: 'Cài đặt',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone không khả dụng. Vui lòng thử lại sau.'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _pulseController.stop();
    } else {
      _speechSendTimer?.cancel();
      setState(() {
        _isListening = true;
        _lastWords = '';
      });
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _controller.text = _lastWords;
            // Move cursor to end
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'vi_VN', // Vietnamese
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  @override
  void dispose() {
    _speechSendTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
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

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _speechSendTimer?.cancel();

    // Stop listening if active
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      _pulseController.stop();
    }

    context.read<ChatBloc>().add(SendMessageEvent(text));
    _controller.clear();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scheduleSpeechSend() {
    _speechSendTimer?.cancel();
    _speechSendTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final text = _controller.text.trim();
      if (text.isEmpty) return;
      context.read<ChatBloc>().add(SendMessageEvent(text));
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('iZii AI Agent',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Sẵn sàng hỗ trợ',
                    style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Voice listening banner
            if (_isListening) _buildListeningBanner(),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state.pendingToolCall != null) {
                  return _buildPendingToolCard(state.pendingToolCall!, context);
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (!state.isLoading) {
                    Future.delayed(
                        const Duration(milliseconds: 100), _scrollToBottom);
                  }
                },
                builder: (context, state) {
                  if (state.messages.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    itemCount:
                        state.messages.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return _buildTypingIndicator();
                      }
                      return AiMessageBubble(message: state.messages[index]);
                    },
                  );
                },
              ),
            ),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                final hasPendingTool = state.pendingToolCall != null;
                return _buildInputArea(context, hasPendingTool);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningBanner() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF43F5E)
                    .withValues(alpha: 0.1 + _pulseController.value * 0.1),
                const Color(0xFF6366F1)
                    .withValues(alpha: 0.1 + _pulseController.value * 0.1),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(
                          alpha: 0.5 + _pulseController.value * 0.5),
                      blurRadius: 8 + _pulseController.value * 8,
                      spreadRadius: _pulseController.value * 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '🎤 Đang nghe...',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFFF43F5E)),
              ),
              const Spacer(),
              if (_lastWords.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: Text(
                    _lastWords,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              TextButton(
                onPressed: _toggleListening,
                child: const Text('Dừng',
                    style: TextStyle(
                        color: Color(0xFFF43F5E), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingToolCard(PendingToolCall pending, BuildContext context) {
    final serviceName = pending.arguments['service_name']?.toString() ?? '';
    final customerName = pending.arguments['customer_name']?.toString() ?? '';
    final customerPhone = pending.arguments['customer_phone']?.toString() ?? '';
    final scheduledDate = pending.arguments['scheduled_date']?.toString() ?? '';
    final customerAddress =
        pending.arguments['customer_address']?.toString() ?? '';
    final notes = pending.arguments['notes']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xác nhận tạo đơn dịch vụ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (serviceName.isNotEmpty || customerName.isNotEmpty) ...[
                _buildPendingInfoRow('Dịch vụ', serviceName),
                if (customerName.isNotEmpty)
                  _buildPendingInfoRow('Khách hàng', customerName),
                if (customerPhone.isNotEmpty)
                  _buildPendingInfoRow('SĐT', customerPhone),
                const SizedBox(height: 12),
              ],
              if (scheduledDate.isNotEmpty || customerAddress.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scheduledDate.isNotEmpty)
                        _buildPendingInfoRow('Hẹn', scheduledDate,
                            valueStyle: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      if (customerAddress.isNotEmpty)
                        _buildPendingInfoRow('Địa chỉ', customerAddress,
                            valueStyle: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (notes.isNotEmpty)
                _buildPendingInfoRow('Ghi chú', notes,
                    valueStyle:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              if (notes.isNotEmpty) const SizedBox(height: 12),
              const Text(
                'Vui lòng kiểm tra kỹ thời gian và địa chỉ trước khi xác nhận.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                      onPressed: () {
                        context.read<ChatBloc>().add(ConfirmToolCallEvent());
                      },
                      child: const Text('✅ Xác nhận'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () {
                        context.read<ChatBloc>().add(RejectToolCallEvent());
                      },
                      child: const Text('❌ Từ chối'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingInfoRow(String label, String value,
      {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined,
                  size: 64, color: Color(0xFF6366F1))
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms, color: const Color(0xFF06B6D4)),
          const SizedBox(height: 24),
          const Text(
            'Tôi có thể giúp gì cho bạn?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập văn bản hoặc bấm 🎤 để nói chuyện.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Lên đơn hàng mới'),
              _buildSuggestionChip('Kiểm tra tồn kho'),
              _buildSuggestionChip('Cài đặt CRM'),
            ],
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: const BorderSide(color: Color(0xFF6366F1), width: 1),
      onPressed: () {
        _controller.text = label;
        _sendMessage();
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 24),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF6366F1),
            child: Icon(Icons.more_horiz, color: Colors.white, size: 20),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 500.ms),
          const SizedBox(width: 12),
          const Text('AI đang suy nghĩ...',
              style:
                  TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool hasPendingTool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 16,
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPendingTool)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: const Text(
                  'Xác nhận trước khi gửi yêu cầu tạo đơn dịch vụ.',
                  style: TextStyle(
                    color: Color(0xFF8A6E22),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              children: [
                // Mic button
                _buildMicButton(hasPendingTool),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.5)
                            : hasPendingTool
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                        width: _isListening ? 2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      enabled: !hasPendingTool,
                      decoration: InputDecoration(
                        hintText: hasPendingTool
                            ? 'Chờ xác nhận thao tác...'
                            : _isListening
                                ? 'Đang nghe giọng nói...'
                                : 'Nhập tin nhắn...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted:
                          hasPendingTool ? null : (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasPendingTool
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : const [Color(0xFF6366F1), Color(0xFF06B6D4)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: hasPendingTool ? null : _sendMessage,
                  ),
                ).animate().scale(duration: 200.ms),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton(bool hasPendingTool) {
    if (_isListening) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF43F5E)
                      .withValues(alpha: 0.3 + _pulseController.value * 0.4),
                  blurRadius: 8 + _pulseController.value * 12,
                  spreadRadius: _pulseController.value * 4,
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFF43F5E),
              radius: 22,
              child: Icon(
                Icons.mic,
                color: Colors.white,
                size: 22 + _pulseController.value * 4,
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: hasPendingTool ? null : _toggleListening,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF43F5E)
                  .withValues(alpha: hasPendingTool ? 0.05 : 0.1),
              const Color(0xFF6366F1)
                  .withValues(alpha: hasPendingTool ? 0.05 : 0.1),
            ],
          ),
          border: Border.all(
            color: hasPendingTool
                ? Colors.grey.withValues(alpha: 0.3)
                : const Color(0xFFF43F5E).withValues(alpha: 0.3),
          ),
        ),
        child: const Icon(Icons.mic, color: Color(0xFFF43F5E), size: 22),
      ),
    );
  }
}
