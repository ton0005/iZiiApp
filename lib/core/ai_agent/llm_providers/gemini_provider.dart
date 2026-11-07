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
          'You are iZii Agent - Smart assistant for the iZiiApp application. '
          'Your mission is to help users manage data (CRM, Inventory, Services) via conversation. '
          'When users ask about customers/leads, use the search_leads or list_all_leads tool. '
          'When users ask about products, use search_products, list_all_products, or check_stock. '
          'When you need to create a service booking, specify the following fields: service_name, scheduled_date, customer_phone, customer_address, notes. '
          'If there is enough information to create a booking, call create_service_booking. '
          'If a tool requires confirmation, first provide a concise summary with all relevant details and ask the user to confirm. '
          'Always respond concisely, friendly, and professionally in English.'),
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

          if (toolResult == 'PENDING_CONFIRMATION') {
            return _buildPendingConfirmationText(call.name, call.args);
          }

          // Gửi kết quả tool về cho Gemini để tóm tắt
          final toolResponse = await _chatSession.sendMessage(
            Content.functionResponse(call.name, {'result': toolResult}),
          );
          return toolResponse.text ?? 'Operation completed.';
        }
      }

      return response.text ?? 'Sorry, I did not understand the request.';
    } catch (e, st) {
      print('[GeminiProvider] ERROR: $e');
      print(st);
      return '❌ Gemini connection error:\n${e.toString().length > 200 ? e.toString().substring(0, 200) : e}';
    }
  }

  Future<String> sendFunctionResponse(
    String functionName,
    Map<String, dynamic> result,
  ) async {
    try {
      final response = await _chatSession.sendMessage(
        Content.functionResponse(functionName, result),
      );
      return response.text ?? 'Operation completed.';
    } catch (e, st) {
      print('[GeminiProvider] Function response error: $e');
      print(st);
      return '❌ Error sending function response: ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}';
    }
  }

  String _buildPendingConfirmationText(
    String toolName,
    Map<String, dynamic> args,
  ) {
    if (toolName != 'create_service_booking') {
      return 'AI requires confirmation to proceed with this operation.';
    }

    final serviceName = args['service_name']?.toString() ?? 'Unknown';
    final scheduledDate = args['scheduled_date']?.toString() ?? 'None';
    final customerPhone = args['customer_phone']?.toString() ?? 'None';
    final customerAddress = args['customer_address']?.toString() ?? 'None';
    final notes = args['notes']?.toString() ?? 'None';

    return '''AI wants to create a service booking with the following information:

• service_name: $serviceName
• scheduled_date: $scheduledDate
• customer_phone: $customerPhone
• customer_address: $customerAddress
• notes: $notes

If you agree, please confirm to proceed with booking. Otherwise, please cancel this operation.''';
  }
}
