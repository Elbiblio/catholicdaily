import 'package:flutter/material.dart';
import '../../data/services/bible_version_preference.dart';

class BibleVersionSwitcher extends StatefulWidget {
  final VoidCallback? onVersionChanged;

  const BibleVersionSwitcher({
    super.key,
    this.onVersionChanged,
  });

  @override
  State<BibleVersionSwitcher> createState() => _BibleVersionSwitcherState();
}

class _BibleVersionSwitcherState extends State<BibleVersionSwitcher> {
  BibleVersionPreference? _preference;
  BibleVersionType _currentVersion = BibleVersionType.rsvce;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final pref = await BibleVersionPreference.getInstance();
    if (mounted) {
      setState(() {
        _preference = pref;
        _currentVersion = pref.currentVersion;
        _isLoading = false;
      });
    }
  }

  Future<void> _showVersionPicker() async {
    final theme = Theme.of(context);
    
    final selected = await showDialog<BibleVersionType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Bible Version'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BibleVersionType.values.map((version) {
            final isSelected = version == _currentVersion;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(
                version.fullName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(version.abbreviation),
              selected: isSelected,
              onTap: () => Navigator.of(context).pop(version),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _currentVersion) {
      await _preference?.setVersion(selected);
      if (mounted) {
        setState(() {
          _currentVersion = selected;
        });
        widget.onVersionChanged?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Loading...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _showVersionPicker,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentVersion.fullName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
