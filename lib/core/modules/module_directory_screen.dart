import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'module_manifest.dart';
import 'module_registry.dart';

class ModuleDirectoryScreen extends StatefulWidget {
  const ModuleDirectoryScreen({super.key});

  @override
  State<ModuleDirectoryScreen> createState() => _ModuleDirectoryScreenState();
}

class _ModuleDirectoryScreenState extends State<ModuleDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = ModuleRegistry().availableModuleManifests;
    final searchTerms = _searchTerm
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    final filteredModules =
        modules.where((module) => _matchesSearch(module, searchTerms)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám phá Module'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm module theo tên, mô tả, hoặc thẻ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredModules.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _searchTerm.isEmpty
                            ? 'Chưa có module nào để hiển thị.'
                            : 'Không tìm thấy module phù hợp với "$_searchTerm".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final module = filteredModules[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        tileColor: Theme.of(context).colorScheme.surface,
                        leading: Icon(
                          _iconForModule(module.id),
                          color: const Color(0xFF4F46E5).withValues(alpha: 1.0),
                          size: 32,
                        ),
                        title: _buildHighlightedText(
                          context,
                          module.name,
                          searchTerms,
                          const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: _buildHighlightedText(
                          context,
                          module.description,
                          searchTerms,
                          const TextStyle(fontSize: 13, color: Colors.black54),
                          maxLines: 2,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(_routeForModule(module.id)),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemCount: filteredModules.length,
                  ),
          ),
        ],
      ),
    );
  }

  String _routeForModule(String moduleId) {
    if (moduleId == 'izii.sales_crm') return '/sales';
    if (moduleId == 'izii.supply_chain') return '/inventory';
    if (moduleId == 'izii.services') return '/services/list';
    return '/';
  }

  bool _matchesSearch(ModuleManifest module, List<String> searchTerms) {
    if (searchTerms.isEmpty) return true;
    final haystack =
        '${module.name} ${module.description} ${module.tags.join(' ')}'
            .toLowerCase();
    return searchTerms.every((term) => haystack.contains(term));
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    List<String> searchTerms,
    TextStyle style, {
    int maxLines = 1,
  }) {
    if (searchTerms.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    var current = 0;

    while (current < text.length) {
      int matchIndex = text.length;
      String? matchTerm;

      for (final term in searchTerms) {
        final index = lowerText.indexOf(term, current);
        if (index >= 0 && index < matchIndex) {
          matchIndex = index;
          matchTerm = term;
        }
      }

      if (matchTerm == null) {
        spans.add(TextSpan(text: text.substring(current), style: style));
        break;
      }

      if (matchIndex > current) {
        spans.add(
            TextSpan(text: text.substring(current, matchIndex), style: style));
      }

      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + matchTerm.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.35),
          fontWeight: FontWeight.w700,
        ),
      ));

      current = matchIndex + matchTerm.length;
    }

    return RichText(
      text: TextSpan(
          style: style.copyWith(
              color:
                  style.color ?? Theme.of(context).textTheme.bodyLarge?.color),
          children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  IconData _iconForModule(String moduleId) {
    switch (moduleId) {
      case 'izii.sales_crm':
        return Icons.people_alt_rounded;
      case 'izii.supply_chain':
        return Icons.inventory_2_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}
