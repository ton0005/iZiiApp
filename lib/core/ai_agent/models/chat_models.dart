class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<ToolCall>? toolCalls;
  final List<String>? attachmentPaths;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.attachmentPaths,
  });
}

enum MessageRole { user, assistant, system, tool }

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? result;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.result,
  });
}

class PendingToolCall {
  final String name;
  final String description;
  final Map<String, dynamic> arguments;

  PendingToolCall({
    required this.name,
    required this.description,
    required this.arguments,
  });

  String get summary {
    final parts = <String>[];
    final serviceName = arguments['service_name']?.toString();
    final customerName = arguments['customer_name']?.toString();
    final customerPhone = arguments['customer_phone']?.toString();
    final scheduledDate = arguments['scheduled_date']?.toString();
    final customerAddress = arguments['customer_address']?.toString();
    final notes = arguments['notes']?.toString();

    if (serviceName != null && serviceName.isNotEmpty) {
      parts.add('Dịch vụ: $serviceName');
    }
    if (customerName != null && customerName.isNotEmpty) {
      parts.add('Khách hàng: $customerName');
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      parts.add('SĐT: $customerPhone');
    }
    if (scheduledDate != null && scheduledDate.isNotEmpty) {
      parts.add('Hẹn: $scheduledDate');
    }
    if (customerAddress != null && customerAddress.isNotEmpty) {
      parts.add('Địa chỉ: $customerAddress');
    }
    if (notes != null && notes.isNotEmpty) {
      parts.add('Ghi chú: $notes');
    }
    return parts.join(' • ');
  }
}

class ChatChunk {
  final String delta;
  final bool isComplete;
  final ToolCall? toolCall;

  ChatChunk({
    this.delta = '',
    this.isComplete = false,
    this.toolCall,
  });
}

class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final bool requiresConfirmation;
  final Future<String> Function(Map<String, dynamic> args) execute;

  AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    this.requiresConfirmation = false,
    required this.execute,
  });
}

class CostEstimate {
  final int inputTokens;
  final int outputTokens;
  final double estimatedCostUsd;

  CostEstimate({
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedCostUsd,
  });
}
