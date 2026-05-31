import 'package:google_generative_ai/google_generative_ai.dart';
import '../tools/agent_tool_registry.dart';

class GeminiProvider {
  final String apiKey;
  final AgentToolRegistry toolRegistry;
  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  Schema _schemaFromToolParameter(dynamic parameter) {
    if (parameter is! Map) {
      return Schema.string();
    }

    final description = parameter['description']?.toString();
    final rawType = parameter['type'];
    final type = rawType is List && rawType.isNotEmpty
        ? rawType.first.toString()
        : rawType?.toString();

    switch (type) {
      case 'number':
        return Schema.number(description: description);
      case 'integer':
        return Schema.integer(description: description);
      case 'boolean':
        return Schema.boolean(description: description);
      case 'array':
        return Schema.array(
          description: description,
          items: _schemaFromToolParameter(parameter['items']),
        );
      case 'object':
        final rawProps = parameter['properties'];
        final properties = <String, Schema>{};
        if (rawProps is Map) {
          for (final entry in rawProps.entries) {
            properties[entry.key.toString()] =
                _schemaFromToolParameter(entry.value);
          }
        }
        return Schema.object(
          description: description,
          properties: properties,
        );
      case 'string':
      default:
        return Schema.string(description: description);
    }
  }

  GeminiProvider({required this.apiKey, required this.toolRegistry}) {
    // Chuyển đổi AgentTool sang FunctionDeclaration của Gemini
    final List<FunctionDeclaration> functionDeclarations = [];

    for (final tool in toolRegistry.getAllTools()) {
      final rawProps = tool.parameters['properties'];
      final rawRequired = tool.parameters['required'];

      // Build properties map thủ công (tránh lỗi DDC với Map.map)
      final Map<String, Schema> schemaProps = {};
      if (rawProps is Map) {
        for (final key in rawProps.keys) {
          final propValue = rawProps[key];
          schemaProps[key.toString()] = _schemaFromToolParameter(propValue);
        }
      }

      final List<String> required = [];
      if (rawRequired is List) {
        for (final r in rawRequired) {
          required.add(r.toString());
        }
      }

      functionDeclarations.add(FunctionDeclaration(
        tool.name,
        tool.description,
        Schema(
          SchemaType.object,
          properties: schemaProps,
          requiredProperties: required.isNotEmpty ? required : null,
        ),
      ));
    }

    print('[GeminiProvider] Registered ${functionDeclarations.length} tools');

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      tools: functionDeclarations.isNotEmpty
          ? [Tool(functionDeclarations: functionDeclarations)]
          : null,
      systemInstruction: Content.system(
          'Bạn là iZii Agent - Trợ lý thông minh cho ứng dụng iZiiApp. '
          'Nhiệm vụ của bạn là hỗ trợ người dùng thực hiện các thao tác quản lý dữ liệu (CRM, Kho) thông qua trò chuyện. '
          'Hãy gọi các Function/Tool khi người dùng có yêu cầu phù hợp. '
          'Hãy luôn trả lời ngắn gọn, thân thiện và chuyên nghiệp bằng Tiếng Việt.'),
    );

    _chatSession = _model.startChat();
    print('[GeminiProvider] Initialized successfully');
  }

  Future<String> sendMessage(
    String text,
    Future<String> Function(String, Map<String, dynamic>) onToolCall,
  ) async {
    try {
      print('[GeminiProvider] Sending: $text');
      final response = await _chatSession.sendMessage(Content.text(text));
      print('[GeminiProvider] Response received');

      // Kiểm tra function calls
      final calls = response.functionCalls.toList();
      if (calls.isNotEmpty) {
        for (final call in calls) {
          print('[GeminiProvider] Tool call: ${call.name}(${call.args})');

          // Thực thi tool
          final toolResult = await onToolCall(call.name, call.args);
          print('[GeminiProvider] Tool result: $toolResult');

          // Gửi kết quả tool về cho Gemini để tóm tắt
          final toolResponse = await _chatSession.sendMessage(
            Content.functionResponse(call.name, {'result': toolResult}),
          );
          return toolResponse.text ?? 'Đã hoàn thành thao tác.';
        }
      }

      return response.text ?? 'Xin lỗi, tôi không hiểu yêu cầu.';
    } catch (e, st) {
      print('[GeminiProvider] ERROR: $e');
      print(st);
      return '❌ Lỗi kết nối Gemini:\n${e.toString().length > 200 ? e.toString().substring(0, 200) : e}';
    }
  }
}
