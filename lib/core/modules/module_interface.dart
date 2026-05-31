import 'package:flutter/widgets.dart';
import 'module_manifest.dart';
import '../ai_agent/models/chat_models.dart';

abstract class IZiiModule {
  ModuleManifest get manifest;
  
  /// Tables to register with Drift database
  List<String> get tableNames => [];
  
  /// Tools to expose to the AI Agent
  List<AgentTool> get agentTools => [];
  
  /// Screens / Routes this module provides
  Map<String, WidgetBuilder> get routes => {};

  /// Dashboard widget to show on the home screen
  Widget? get dashboardWidget => null;

  /// Lifecycle: Initialize module
  Future<void> initialize();

  /// Lifecycle: Cleanup module resources
  Future<void> dispose();

  /// AI-driven customization handler
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}
