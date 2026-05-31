import '../models/chat_models.dart';

abstract class LLMProvider {
  String get name;
  String get id;
  bool get isOnDevice;
  bool get supportsToolCalling;

  Future<bool> isAvailable();

  Stream<ChatChunk> chatStream({
    required List<ChatMessage> messages,
    required List<AgentTool> tools,
    double temperature = 0.7,
  });

  CostEstimate? estimateCost(int inputTokens, int outputTokens) {
    return null; // Override in cloud providers
  }
}
