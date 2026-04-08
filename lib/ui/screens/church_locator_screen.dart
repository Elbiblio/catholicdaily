import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/church.dart';
import '../../data/services/church_locator_service.dart';
import '../../data/services/location_service.dart';
import '../widgets/church_locator/church_card.dart';
import '../widgets/church_locator/size_chip.dart';

class ChurchLocatorScreen extends StatefulWidget {
  const ChurchLocatorScreen({super.key});

  @override
  State<ChurchLocatorScreen> createState() => _ChurchLocatorScreenState();
}

class _ChurchLocatorScreenState extends State<ChurchLocatorScreen> {
  final ChurchLocatorService _churchService = ChurchLocatorService();
  List<Church> _churches = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyChurches();
  }

  Future<void> _loadNearbyChurches() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final churches = await _churchService.findNearbyChurches();
      if (mounted) {
        setState(() {
          _churches = churches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load nearby churches right now.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final hasPermission = await LocationService.openAppSettings();
    if (hasPermission) {
      _loadNearbyChurches();
    }
  }

  Future<void> _callChurch(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openWebsite(String? website) async {
    if (website == null || website.isEmpty) return;
    
    final Uri websiteUri = Uri.parse(website.startsWith('http') ? website : 'https://$website');
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri);
    }
  }

  void _showAddChurchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddChurchSheet(
        onChurchAdded: (church) {
          setState(() {
            _churches.insert(0, church);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Locator'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddChurchDialog,
            tooltip: 'Add Church',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyChurches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Finding nearby churches...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Location Error',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _requestLocationPermission,
                icon: const Icon(Icons.settings),
                label: const Text('Enable Location'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _showAddChurchDialog,
                child: const Text('Add Church Manually'),
              ),
            ],
          ),
        ),
      );
    }

    if (_churches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.church_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Churches Found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try enabling location services or add churches manually',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showAddChurchDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Church'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyChurches,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _churches.length,
        itemBuilder: (context, index) {
          final church = _churches[index];
          return ChurchCard(
            church: church,
            onCall: () => _callChurch(church.phoneNumber),
            onWebsite: () => _openWebsite(church.website),
            onEdit: church.isUserAdded
                ? () => _showEditChurchDialog(church)
                : null,
            onDelete: church.isUserAdded
                ? () => _showDeleteChurchDialog(church)
                : null,
          );
        },
      ),
    );
  }

  void _showEditChurchDialog(Church church) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddChurchSheet(
        church: church,
        onChurchAdded: (updatedChurch) {
          setState(() {
            final index = _churches.indexWhere((c) => c.id == church.id);
            if (index != -1) {
              _churches[index] = updatedChurch;
            }
          });
        },
      ),
    );
  }

  void _showDeleteChurchDialog(Church church) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Church'),
        content: Text('Are you sure you want to delete ${church.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _churchService.deleteCustomChurch(church.id);
              if (mounted) {
                setState(() {
                  _churches.removeWhere((c) => c.id == church.id);
                });
              }
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddChurchSheet extends StatefulWidget {
  final Church? church;
  final Function(Church) onChurchAdded;

  const AddChurchSheet({
    super.key,
    this.church,
    required this.onChurchAdded,
  });

  @override
  State<AddChurchSheet> createState() => _AddChurchSheetState();
}

class _AddChurchSheetState extends State<AddChurchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();
  List<String> _massTimes = [];
  String? _selectedSize;
  bool _isLoading = false;

  // Common mass time presets grouped by day
  static const _presets = {
    'Saturday': ['4:00 PM', '5:00 PM', '5:30 PM', '7:00 PM'],
    'Sunday': [
      '7:00 AM', '7:30 AM', '8:00 AM', '8:30 AM', '9:00 AM', '9:30 AM',
      '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
      '1:00 PM', '5:00 PM', '7:00 PM',
    ],
    'Weekdays': ['6:00 AM', '6:30 AM', '7:00 AM', '7:30 AM', '8:00 AM', '12:00 PM', '5:30 PM', '7:00 PM'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.church != null) {
      _nameController.text = widget.church!.name;
      _addressController.text = widget.church!.address;
      _phoneController.text = widget.church!.phoneNumber ?? '';
      _websiteController.text = widget.church!.website ?? '';
      // Parse existing mass times into chips
      final raw = widget.church!.massTimes ?? '';
      if (raw.isNotEmpty) {
        _massTimes = raw.split(RegExp(r'[,·|]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      final notes = widget.church!.notes ?? '';
      final sizeMatch = RegExp(r'^\[Size: (Small|Medium|Large)\]\s*').firstMatch(notes);
      if (sizeMatch != null) {
        _selectedSize = sizeMatch.group(1)!.toLowerCase();
        _notesController.text = notes.replaceFirst(sizeMatch.group(0)!, '').trim();
      } else {
        _notesController.text = notes;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openMassTimesPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MassTimesPickerSheet(
        selected: List.from(_massTimes),
        presets: _presets,
        onSave: (updated) => setState(() => _massTimes = updated),
      ),
    );
  }

  Future<void> _saveChurch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final massTimesStr = _massTimes.isEmpty ? null : _massTimes.join(' · ');
    String? notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    if (_selectedSize != null) {
      final sizeLabel = '${_selectedSize![0].toUpperCase()}${_selectedSize!.substring(1)}';
      final annotation = '[Size: $sizeLabel]';
      notes = notes != null ? '$annotation $notes' : annotation;
    }

    try {
      final churchService = ChurchLocatorService();
      if (widget.church != null) {
        final updatedChurch = widget.church!.copyWith(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          massTimes: massTimesStr,
          notes: notes,
        );
        await churchService.updateChurch(updatedChurch);
        widget.onChurchAdded(updatedChurch);
      } else {
        final church = await churchService.addCustomChurch(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          latitude: 0.0,
          longitude: 0.0,
          massTimes: massTimesStr,
          notes: notes,
        );
        widget.onChurchAdded(church);
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save church details right now.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.church != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEditing ? 'Edit Church' : 'Add Church',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help others find Mass. Fields marked * are required.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Church Name *',
                        hintText: "e.g., St. Mary's Catholic Church",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.church_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter church name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        hintText: 'e.g., 123 Main St, City, State',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter address' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+1 (555) 000-0000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        hintText: 'https://',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    _MassTimesTagField(
                      times: _massTimes,
                      theme: theme,
                      onTap: _openMassTimesPicker,
                      onRemove: (t) => setState(() => _massTimes.remove(t)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Congregation Size',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizeChip(
                          label: 'Small',
                          icon: Icons.group_outlined,
                          selected: _selectedSize == 'small',
                          onTap: () => setState(() =>
                              _selectedSize = _selectedSize == 'small' ? null : 'small'),
                        ),
                        const SizedBox(width: 8),
                        SizeChip(
                          label: 'Medium',
                          icon: Icons.groups_outlined,
                          selected: _selectedSize == 'medium',
                          onTap: () => setState(() =>
                              _selectedSize = _selectedSize == 'medium' ? null : 'medium'),
                        ),
                        const SizedBox(width: 8),
                        SizeChip(
                          label: 'Large',
                          icon: Icons.groups_2_outlined,
                          selected: _selectedSize == 'large',
                          onTap: () => setState(() =>
                              _selectedSize = _selectedSize == 'large' ? null : 'large'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Parking info, accessibility, language of Mass...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _saveChurch,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(isEditing ? Icons.check : Icons.add),
                          label: Text(isEditing ? 'Update' : 'Add Church'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mass Times tag field (tap → opens picker sheet)
// ---------------------------------------------------------------------------
class _MassTimesTagField extends StatelessWidget {
  final List<String> times;
  final ThemeData theme;
  final VoidCallback onTap;
  final void Function(String) onRemove;

  const _MassTimesTagField({
    required this.times,
    required this.theme,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                const SizedBox(width: 8),
                Text(
                  'Mass Times',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                Icon(Icons.add_circle_outline,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 2),
                Text(
                  'Add',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (times.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: times
                    .map((t) => Chip(
                          label: Text(t),
                          labelStyle: theme.textTheme.labelSmall,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => onRemove(t),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Tap to add — e.g. Sat 5:00 PM, Sun 10:00 AM',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mass Times picker sheet
// ---------------------------------------------------------------------------
class _MassTimesPickerSheet extends StatefulWidget {
  final List<String> selected;
  final Map<String, List<String>> presets;
  final void Function(List<String>) onSave;

  const _MassTimesPickerSheet({
    required this.selected,
    required this.presets,
    required this.onSave,
  });

  @override
  State<_MassTimesPickerSheet> createState() => _MassTimesPickerSheetState();
}

class _MassTimesPickerSheetState extends State<_MassTimesPickerSheet>
    with SingleTickerProviderStateMixin {
  late List<String> _selected;
  late TabController _tabs;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _tabs = TabController(length: widget.presets.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String day, String time) {
    final tag = '$day $time';
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
  }

  void _addCustom() {
    final val = _customController.text.trim();
    if (val.isEmpty) return;
    if (!_selected.contains(val)) {
      setState(() => _selected.add(val));
    }
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = widget.presets.keys.toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined),
                  const SizedBox(width: 8),
                  Text('Mass Times',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      widget.onSave(_selected);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            // Selected chips preview
            if (_selected.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selected
                      .map((t) => Chip(
                            label: Text(t),
                            labelStyle: theme.textTheme.labelSmall,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _selected.remove(t)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          ))
                      .toList(),
                ),
              ),
            const Divider(height: 1),
            TabBar(
              controller: _tabs,
              tabs: days.map((d) => Tab(text: d)).toList(),
              labelStyle: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: days.map((day) {
                  final times = widget.presets[day]!;
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: times.map((time) {
                            final tag = '$day $time';
                            final isSelected = _selected.contains(tag);
                            return FilterChip(
                              label: Text(time),
                              selected: isSelected,
                              onSelected: (_) => _toggle(day, time),
                              selectedColor: theme.colorScheme.primaryContainer,
                              checkmarkColor: theme.colorScheme.primary,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        // Custom entry row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customController,
                                decoration: InputDecoration(
                                  labelText: 'Custom time',
                                  hintText: 'e.g., $day 9:15 AM',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addCustom(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addCustom,
                              icon: const Icon(Icons.add),
                              tooltip: 'Add custom time',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
