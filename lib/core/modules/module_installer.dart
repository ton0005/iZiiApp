import 'module_registry.dart';
import 'module_interface.dart';
import 'module_manifest.dart';

class ModuleInstaller {
  final ModuleRegistry _registry = ModuleRegistry();

  Future<IZiiModule?> installModuleById(String moduleId) async {
    return await _registry.installModule(moduleId);
  }

  void registerDefaultModuleFactories() {
    _registry.registerDefaultModuleFactories();
  }

  List<ModuleManifest> getAvailableModules() =>
      _registry.availableModuleManifests;
}
