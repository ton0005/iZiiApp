import 'models/chat_models.dart';
import 'tools/agent_tool_registry.dart';
import 'llm_providers/gemini_provider.dart';
import '../settings/settings_service.dart';

class AiAgentService {
  final AgentToolRegistry toolRegistry;
  GeminiProvider? _geminiProvider;
  final SettingsService _settingsService = SettingsService();
  String? _lastApiKey;
  PendingToolCall? _pendingToolCall;

  final List<ChatMessage> _history = [];

  AiAgentService({
    required this.toolRegistry,
  }) {
    _history.add(ChatMessage(
      id: 'system-init',
      role: MessageRole.assistant,
      content:
          'Chào mừng bạn đến với iZii Agent! 🤖\nTôi được cấu hình với module Bán Hàng (CRM) và Quản lý Kho.\n\n'
          '➡️ Nhấn ⚙️ Settings để nhập Gemini API Key trước khi bắt đầu.',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _initProvider() async {
    try {
      final apiKey = await _settingsService.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _geminiProvider = null;
        _lastApiKey = null;
        return;
      }
      // Chỉ tạo lại provider nếu key thay đổi
      if (apiKey != _lastApiKey) {
        _lastApiKey = apiKey;
        _geminiProvider =
            GeminiProvider(apiKey: apiKey, toolRegistry: toolRegistry);
      }
    } catch (e) {
      print('[AiAgentService] Error initializing provider: $e');
      _geminiProvider = null;
    }
  }

  List<ChatMessage> get history => List<ChatMessage>.from(_history);

  PendingToolCall? get pendingToolCall => _pendingToolCall;

  Future<void> confirmPendingToolCall() async {
    final pending = _pendingToolCall;
    if (pending == null) return;

    try {
      final tool = toolRegistry.getTool(pending.name);
      if (tool == null) {
        _history.add(ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_err',
          role: MessageRole.assistant,
          content: 'Lỗi: Không tìm thấy tool ${pending.name}.',
          timestamp: DateTime.now(),
        ));
        _pendingToolCall = null;
        return;
      }

      final String result = await tool.execute(pending.arguments);
      final toolResponseText = await _geminiProvider?.sendFunctionResponse(
        pending.name,
        {'result': result},
      );

      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: MessageRole.assistant,
        content: toolResponseText ?? 'Đã hoàn thành thao tác.',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('[AiAgentService] Confirm pending tool error: $e');
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        role: MessageRole.assistant,
        content: '❌ Lỗi khi xác nhận thao tác: $e',
        timestamp: DateTime.now(),
      ));
    } finally {
      _pendingToolCall = null;
    }
  }

  Future<void> rejectPendingToolCall() async {
    final pending = _pendingToolCall;
    if (pending == null) return;

    try {
      final toolResponseText = await _geminiProvider?.sendFunctionResponse(
        pending.name,
        {'result': 'USER_REJECTED'},
      );
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: MessageRole.assistant,
        content: toolResponseText ?? 'Đã hủy yêu cầu.',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('[AiAgentService] Reject pending tool error: $e');
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        role: MessageRole.assistant,
        content: '❌ Lỗi khi hủy thao tác: $e',
        timestamp: DateTime.now(),
      ));
    } finally {
      _pendingToolCall = null;
    }
  }

  Future<void> addUserMessage(String text) async {
    _history.add(ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    ));

    // Luôn thử init lại provider (để lấy key mới nếu user vừa save)
    await _initProvider();

    if (_geminiProvider == null) {
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        role: MessageRole.assistant,
        content:
            '⚠️ Chưa có API Key!\n\nVui lòng nhấn ⚙️ (góc phải trên) → Nhập Gemini API Key → Lưu.\n'
            'Lấy key miễn phí tại: https://aistudio.google.com/app/apikey',
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final List<ToolCall> toolCalls = [];

      final responseText =
          await _geminiProvider!.sendMessage(text, (toolName, args) async {
        final tool = toolRegistry.getTool(toolName);
        if (tool != null) {
          if (tool.requiresConfirmation) {
            _pendingToolCall = PendingToolCall(
              name: toolName,
              description: tool.description,
              arguments: args,
            );
            return 'PENDING_CONFIRMATION';
          }
          final result = await tool.execute(args);
          toolCalls.add(ToolCall(
            id: 'call_${DateTime.now().millisecondsSinceEpoch}',
            name: toolName,
            arguments: args,
            result: result,
          ));
          return result;
        }
        return 'Lỗi: Không tìm thấy tool $toolName';
      });

      final responseTextWithConfirmation = _pendingToolCall != null
          ? _buildPendingConfirmationText(_pendingToolCall!)
          : responseText;

      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: MessageRole.assistant,
        content: responseTextWithConfirmation,
        timestamp: DateTime.now(),
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      ));
    } catch (e) {
      print('[AiAgentService] Error sending message: $e');
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        role: MessageRole.assistant,
        content:
            '❌ Lỗi kết nối AI:\n$e\n\nHãy kiểm tra API Key trong Settings.',
        timestamp: DateTime.now(),
      ));
    }
  }

  String _buildPendingConfirmationText(PendingToolCall pending) {
    final summaryText =
        pending.summary.isNotEmpty ? pending.summary : pending.description;

    return '''Tin nhắn yêu cầu xác nhận:
$summaryText

Nếu bạn đồng ý, hãy bấm "Xác nhận" để tiếp tục tạo booking. Nếu không, bấm "Từ chối" để hủy.''';
  }

  void clearHistory() {
    _history.clear();
  }
}
