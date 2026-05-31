import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_models.dart';
import '../ai_agent_service.dart';

// Events
abstract class ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String text;
  SendMessageEvent(this.text);
}

class LoadHistoryEvent extends ChatEvent {}

// State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Bloc
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AiAgentService _agentService;

  ChatBloc(this._agentService) : super(const ChatState()) {
    on<LoadHistoryEvent>((event, emit) {
      emit(ChatState(messages: _agentService.history));
    });

    on<SendMessageEvent>((event, emit) async {
      // 1. Hiển thị tin nhắn user ngay lập tức + bật loading
      final currentMessages = _agentService.history;
      emit(ChatState(
        isLoading: true,
        messages: [
          ...currentMessages,
          ChatMessage(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            role: MessageRole.user,
            content: event.text,
            timestamp: DateTime.now(),
          ),
        ],
      ));

      // 2. Gọi AI Agent (bao gồm cả Gemini API call)
      try {
        await _agentService.addUserMessage(event.text);
      } catch (e) {
        print('[ChatBloc] Unhandled error: $e');
      }

      // 3. Luôn emit state mới từ history (bao gồm cả error messages)
      emit(ChatState(
        isLoading: false,
        messages: _agentService.history,
      ));
    });
  }
}
