import 'package:flutter/material.dart';

import '../../data/models/responsorial_psalm_edition.dart';
import '../../data/services/responsorial_psalm_edition_registry.dart';
import '../../data/services/responsorial_psalm_preference.dart';

class ResponsorialPsalmEditionSelector extends StatefulWidget {
  final Future<void> Function()? onEditionChanged;
  final bool compact;

  const ResponsorialPsalmEditionSelector({
    super.key,
    this.onEditionChanged,
    this.compact = false,
  });

  @override
  State<ResponsorialPsalmEditionSelector> createState() =>
      _ResponsorialPsalmEditionSelectorState();
}

class _ResponsorialPsalmEditionSelectorState
    extends State<ResponsorialPsalmEditionSelector> {
  ResponsorialPsalmEditionRegistry? _registry;
  ResponsorialPsalmPreference? _preference;
  String _selectedId = ResponsorialPsalmPreference.defaultEditionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>(<Future<Object>>[
      ResponsorialPsalmEditionRegistry.load(),
      ResponsorialPsalmPreference.getInstance(),
    ]);
    if (!mounted) return;
    _preference?.removeListener(_onPreferenceChanged);
    _registry = values[0] as ResponsorialPsalmEditionRegistry;
    _preference = values[1] as ResponsorialPsalmPreference;
    _preference!.addListener(_onPreferenceChanged);
    setState(() => _selectedId = _preference!.currentEditionId);
  }

  void _onPreferenceChanged() {
    if (!mounted || _preference == null) return;
    setState(() => _selectedId = _preference!.currentEditionId);
  }

  Future<void> _showSelector() async {
    final registry = _registry;
    if (registry == null) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responsorial Psalm text'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: registry.all
                .map((edition) {
                  final selected = edition.id == _selectedId;
                  final status = edition.isInstalled
                      ? '${edition.abbreviation} · ${edition.selectionCount == 0 ? edition.coverageStatus : '${edition.selectionCount} selections'}'
                      : edition.isDownloadable
                      ? 'Download required'
                      : 'Not installed';
                  return ListTile(
                    enabled: edition.isInstalled,
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                    ),
                    title: Text(edition.displayName),
                    subtitle: Text(status),
                    selected: selected,
                    onTap: edition.isInstalled
                        ? () => Navigator.of(context).pop(edition.id)
                        : null,
                  );
                })
                .toList(growable: false),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || selected == _selectedId) return;
    await _preference?.setEditionId(selected);
    await widget.onEditionChanged?.call();
  }

  @override
  void dispose() {
    _preference?.removeListener(_onPreferenceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edition = _registry?.byId(_selectedId);
    final subtitle = edition?.displayName ?? 'Loading…';
    if (!widget.compact) {
      return ListTile(
        leading: Icon(
          Icons.library_music_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Responsorial Psalm text'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showSelector,
      );
    }
    return InkWell(
      onTap: _showSelector,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            const Icon(Icons.library_music_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(subtitle, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
