import '../models/chat_models.dart';

class AgentToolRegistry {
  static final AgentToolRegistry _instance = AgentToolRegistry._internal();
  factory AgentToolRegistry() => _instance;
  AgentToolRegistry._internal();

  final Map<String, AgentTool> _tools = {};

  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  void unregisterTool(String name) {
    _tools.remove(name);
  }

  AgentTool? getTool(String name) {
    return _tools[name];
  }

  List<AgentTool> getAllTools() {
    return _tools.values.toList();
  }
}
