import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/church.dart';
import '../../data/services/church_locator_service.dart';
import '../../data/services/location_service.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final churches = await _churchService.findNearbyChurches();
      setState(() {
        _churches = churches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
    showDialog(
      context: context,
      builder: (context) => AddChurchDialog(
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
    showDialog(
      context: context,
      builder: (context) => AddChurchDialog(
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
              setState(() {
                _churches.removeWhere((c) => c.id == church.id);
              });
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

class ChurchCard extends StatelessWidget {
  final Church church;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChurchCard({
    super.key,
    required this.church,
    this.onCall,
    this.onWebsite,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.church,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        church.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (church.distance != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          church.distanceDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (church.isUserAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Added',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    church.shortAddress,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            if (church.phoneNumber != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    church.phoneNumber!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
            if (church.massTimes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      church.massTimes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCall != null)
                  TextButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call'),
                  ),
                if (onWebsite != null) ...[
                  if (onCall != null) const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onWebsite,
                    icon: const Icon(Icons.language, size: 16),
                    label: const Text('Website'),
                  ),
                ],
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddChurchDialog extends StatefulWidget {
  final Church? church;
  final Function(Church) onChurchAdded;

  const AddChurchDialog({
    super.key,
    this.church,
    required this.onChurchAdded,
  });

  @override
  State<AddChurchDialog> createState() => _AddChurchDialogState();
}

class _AddChurchDialogState extends State<AddChurchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _massTimesController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.church != null) {
      _nameController.text = widget.church!.name;
      _addressController.text = widget.church!.address;
      _phoneController.text = widget.church!.phoneNumber ?? '';
      _websiteController.text = widget.church!.website ?? '';
      _massTimesController.text = widget.church!.massTimes ?? '';
      _notesController.text = widget.church!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _massTimesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChurch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final churchService = ChurchLocatorService();
      
      if (widget.church != null) {
        // Update existing church
        final updatedChurch = widget.church!.copyWith(
          name: _nameController.text,
          address: _addressController.text,
          phoneNumber: _phoneController.text.isEmpty ? null : _phoneController.text,
          website: _websiteController.text.isEmpty ? null : _websiteController.text,
          massTimes: _massTimesController.text.isEmpty ? null : _massTimesController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        
        await churchService.updateChurch(updatedChurch);
        widget.onChurchAdded(updatedChurch);
      } else {
        // Add new church
        final church = await churchService.addCustomChurch(
          name: _nameController.text,
          address: _addressController.text,
          phoneNumber: _phoneController.text.isEmpty ? null : _phoneController.text,
          website: _websiteController.text.isEmpty ? null : _websiteController.text,
          latitude: 0.0, // Would need geocoding for real implementation
          longitude: 0.0,
          massTimes: _massTimesController.text.isEmpty ? null : _massTimesController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        widget.onChurchAdded(church);
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.church != null ? 'Edit Church' : 'Add Church',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Church Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter church name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _websiteController,
                          decoration: const InputDecoration(
                            labelText: 'Website',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _massTimesController,
                          decoration: const InputDecoration(
                            labelText: 'Mass Times',
                            border: OutlineInputBorder(),
                            helperText: 'e.g., Sat 5:00 PM, Sun 8:00 AM, 10:00 AM',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
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
                  FilledButton(
                    onPressed: _isLoading ? null : _saveChurch,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.church != null ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
