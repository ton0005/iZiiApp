import '../../modules/sales_crm/sales_crm_module.dart';
import '../../modules/supply_chain/supply_chain_module.dart';
import '../../modules/services/services_module.dart';
import '../../modules/project/project_module.dart';
import '../../modules/purchase/purchase_module.dart';
import '../../modules/accountant/accountant_module.dart';
import 'module_interface.dart';
import 'module_manifest.dart';

class ModuleRegistry {
  static final ModuleRegistry _instance = ModuleRegistry._internal();
  factory ModuleRegistry() => _instance;
  ModuleRegistry._internal();

  final Map<String, IZiiModule> _installedModules = {};
  final Map<String, IZiiModule Function()> _moduleFactories = {};
  final Map<String, ModuleManifest> _availableModules = {};
  bool _defaultFactoriesRegistered = false;

  void _ensureDefaultFactoriesRegistered() {
    if (!_defaultFactoriesRegistered) {
      registerDefaultModuleFactories();
    }
  }

  void registerModule(IZiiModule module) {
    _ensureDefaultFactoriesRegistered();
    _installedModules[module.manifest.id] = module;
    _availableModules[module.manifest.id] = module.manifest;
  }

  void unregisterModule(String id) {
    _installedModules.remove(id);
  }

  void registerModuleFactory(IZiiModule Function() factory) {
    final module = factory();
    _moduleFactories[module.manifest.id] = factory;
    _availableModules[module.manifest.id] = module.manifest;
  }

  void registerDefaultModuleFactories() {
    if (_defaultFactoriesRegistered) return;
    registerModuleFactory(() => SalesCrmModule());
    registerModuleFactory(() => SupplyChainModule());
    registerModuleFactory(() => ServicesModule());
    registerModuleFactory(() => ProjectModule());
    registerModuleFactory(() => PurchaseModule());
    registerModuleFactory(() => AccountantModule());
    _defaultFactoriesRegistered = true;
  }

  Future<IZiiModule?> installModule(String id) async {
    _ensureDefaultFactoriesRegistered();
    if (_installedModules.containsKey(id)) {
      return _installedModules[id];
    }

    final factory = _moduleFactories[id];
    if (factory == null) {
      return null;
    }

    final module = factory();
    await module.initialize();
    _installedModules[id] = module;
    return module;
  }

  IZiiModule? getModule(String id) {
    _ensureDefaultFactoriesRegistered();
    return _installedModules[id];
  }

  List<IZiiModule> getInstalledModules() {
    _ensureDefaultFactoriesRegistered();
    return _installedModules.values.toList();
  }

  List<ModuleManifest> get availableModuleManifests {
    _ensureDefaultFactoriesRegistered();
    return _availableModules.values.toList();
  }

  bool isInstalled(String id) {
    _ensureDefaultFactoriesRegistered();
    return _installedModules.containsKey(id);
  }
}
