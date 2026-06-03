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

class ConfirmToolCallEvent extends ChatEvent {}

class RejectToolCallEvent extends ChatEvent {}

// State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final PendingToolCall? pendingToolCall;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.pendingToolCall,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    PendingToolCall? pendingToolCall,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingToolCall: pendingToolCall ?? this.pendingToolCall,
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
        pendingToolCall: _agentService.pendingToolCall,
      ));
    });

    on<ConfirmToolCallEvent>((event, emit) async {
      final pending = _agentService.pendingToolCall;
      if (pending == null) return;

      emit(state.copyWith(isLoading: true));
      try {
        await _agentService.confirmPendingToolCall();
      } catch (e) {
        print('[ChatBloc] Confirm tool call error: $e');
      }
      emit(ChatState(
        isLoading: false,
        messages: _agentService.history,
      ));
    });

    on<RejectToolCallEvent>((event, emit) async {
      final pending = _agentService.pendingToolCall;
      if (pending == null) return;

      emit(state.copyWith(isLoading: true));
      try {
        await _agentService.rejectPendingToolCall();
      } catch (e) {
        print('[ChatBloc] Reject tool call error: $e');
      }
      emit(ChatState(
        isLoading: false,
        messages: _agentService.history,
      ));
    });
  }
}
