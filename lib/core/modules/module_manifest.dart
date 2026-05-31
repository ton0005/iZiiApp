class ModuleManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final List<String> dependencies;
  final List<String> tags;
  final String category;
  final bool autoInstall;

  const ModuleManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    this.dependencies = const [],
    this.tags = const [],
    required this.category,
    this.autoInstall = false,
  });
}
