import 'models/chat_models.dart';
import 'tools/agent_tool_registry.dart';
import 'llm_providers/gemini_provider.dart';
import '../settings/settings_service.dart';

class AiAgentService {
  final AgentToolRegistry toolRegistry;
  GeminiProvider? _geminiProvider;
  final SettingsService _settingsService = SettingsService();
  String? _lastApiKey;

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
      List<ToolCall> toolCalls = [];

      final responseText =
          await _geminiProvider!.sendMessage(text, (toolName, args) async {
        final tool = toolRegistry.getTool(toolName);
        if (tool != null) {
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

      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: MessageRole.assistant,
        content: responseText,
        timestamp: DateTime.now(),
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      ));
    } catch (e) {
      print('[AiAgentService] Error sending message: $e');
      _history.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        role: MessageRole.assistant,
        content: '❌ Lỗi kết nối AI:\n$e\n\nHãy kiểm tra API Key trong Settings.',
        timestamp: DateTime.now(),
      ));
    }
  }

  void clearHistory() {
    _history.clear();
  }
}
