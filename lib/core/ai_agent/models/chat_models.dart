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
