import 'package:flutter/material.dart';
import '../../data/models/bible_version.dart';
import '../../data/services/theme_preferences.dart';
import '../../data/services/offline_bible_service.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final List<BibleVersion> versions;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;

  const SettingsScreen({
    super.key,
    required this.versions,
    required this.themeMode,
    required this.themeStyle,
    required this.onThemeModeChanged,
    required this.onThemeStyleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTheme = 'system';
  String _selectedThemeStyle = 'standard';
  String _appVersion = '1.0.0';
  final _bibleService = OfflineBibleService();
  List<BibleVersion> _availableVersions = [];
  bool _isLoadingVersions = true;
  static const _androidPackageName = 'com.elbiblio.catholicdaily';
  static const _iosAppStoreId = '';
  static const _iosSearchTerm = 'Catholic Daily Missal';

  @override
  void initState() {
    super.initState();
    _selectedTheme = _themeModeToValue(widget.themeMode);
    _selectedThemeStyle = _themeStyleToValue(widget.themeStyle);
    _loadAppInfo();
    _loadBibleVersions();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _selectedTheme = _themeModeToValue(widget.themeMode);
    }
    if (oldWidget.themeStyle != widget.themeStyle) {
      _selectedThemeStyle = _themeStyleToValue(widget.themeStyle);
    }
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _loadBibleVersions() async {
    setState(() => _isLoadingVersions = true);
    final versions = await _bibleService.fetchAvailableVersions();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableVersions = versions;
      _isLoadingVersions = false;
    });
  }

  Future<void> _requestReview() async {
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    } else {
      if (Platform.isIOS && _iosAppStoreId.isNotEmpty) {
        await inAppReview.openStoreListing(appStoreId: _iosAppStoreId);
        return;
      }

      await _openStoreFallback();
    }
  }

  Future<void> _openStoreFallback() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/us/search?term=${Uri.encodeComponent(_iosSearchTerm)}')
        : Uri.parse('https://play.google.com/store/apps/details?id=$_androidPackageName');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the store listing right now.')),
      );
    }
  }

  String _themeModeToValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  String _themeStyleToValue(AppThemeStyle style) {
    return style == AppThemeStyle.parchment ? 'parchment' : 'standard';
  }

  String _themeModeLabel() {
    return switch (widget.themeMode) {
      ThemeMode.light => 'Light mode',
      ThemeMode.dark => 'Dark mode',
      ThemeMode.system => 'Follow system',
    };
  }

  String _themeStyleLabel() {
    return widget.themeStyle == AppThemeStyle.parchment
        ? 'Classic parchment'
        : 'Standard missal';
  }

  Future<void> _applyThemeMode(String value) async {
    final mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    setState(() {
      _selectedTheme = value;
    });
    widget.onThemeModeChanged(mode);
  }

  Future<void> _applyThemeStyle(String value) async {
    final style = value == 'parchment'
        ? AppThemeStyle.parchment
        : AppThemeStyle.standard;
    setState(() {
      _selectedThemeStyle = value;
    });
    widget.onThemeStyleChanged(style);
  }

  void _showBibleVersionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Bible Translations'),
            content: SizedBox(
              width: double.maxFinite,
              child: _isLoadingVersions
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableVersions.length,
                      itemBuilder: (context, index) {
                        final version = _availableVersions[index];
                        return ListTile(
                          title: Text(version.abbreviation),
                          subtitle: Text(version.name),
                          trailing: version.isDownloaded
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () async {
                                    // Handle download
                                    try {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Downloading ${version.abbreviation}...')),
                                      );
                                      await _bibleService.downloadVersion(version, (progress) {
                                        // Could show progress here
                                      });
                                      await _loadBibleVersions();
                                      setState(() {});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Downloaded ${version.abbreviation} successfully')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to download: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final textController = TextEditingController();
    final emailController = TextEditingController();
    String feedbackType = 'general';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: feedbackType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General Feedback')),
                    DropdownMenuItem(value: 'feature', child: Text('Feature Request')),
                    DropdownMenuItem(value: 'bug', child: Text('Report a Bug')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => feedbackType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (textController.text.trim().isEmpty) return;
                      
                      setState(() => isSubmitting = true);
                      try {
                        final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');
                        final response = await http.post(
                          Uri.parse('https://api.elbiblio.com/api/feedback'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'message': textController.text.trim(),
                            'email': emailController.text.trim(),
                            'type': feedbackType,
                            'app_version': _appVersion,
                            'platform': platform,
                          }),
                        );

                        if (response.statusCode < 200 || response.statusCode >= 300) {
                          throw Exception('service_error_${response.statusCode}');
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thank you for your feedback!')),
                          );
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to send feedback. Please try again.')),
                          );
                        }
                      }
                    },
              child: isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Bible'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.menu_book,
                  title: 'Current Translation',
                  subtitle: widget.versions.isNotEmpty
                      ? widget.versions.first.name
                      : 'RSVCE',
                  onTap: () => _showBibleVersionsDialog(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About RSVCE',
                  subtitle: 'Revised Standard Version Catholic Edition',
                  onTap: () => _showRsvceInfo(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Display'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.text_fields,
                  title: 'Reading Text Size',
                  subtitle: 'Adjust in reading view',
                  onTap: null,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.brightness_6,
                  title: 'Theme',
                  subtitle: _themeModeLabel(),
                  onTap: () => _showThemeDialog(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Theme Style',
                  subtitle: _themeStyleLabel(),
                  onTap: () => _showThemeStyleDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Feedback & Support'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'Report bugs or request features',
                  onTap: () => _showFeedbackDialog(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.star_rate_rounded,
                  title: 'Rate Catholic Daily',
                  subtitle: 'If you enjoy the app, please let us know',
                  onTap: _requestReview,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Legal'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Usage terms and conditions',
                  onTap: () => _openLegalUrl('https://elbiblio.com/catholic-daily/terms'),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _openLegalUrl('https://elbiblio.com/cdr-policy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.church,
                  title: 'Catholic Daily',
                  subtitle: 'Version $_appVersion',
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.storage,
                  title: 'Data',
                  subtitle: 'Offline Bible included',
                  onTap: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Made for Catholics',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the page right now.')),
      );
    }
  }

  void _showRsvceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revised Standard Version Catholic Edition'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The RSVCE is a modern English translation of the Bible that includes the deuterocanonical books accepted by the Catholic Church.',
              ),
              SizedBox(height: 16),
              Text(
                'This app includes the complete Bible with 73 books:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('- 46 books of the Old Testament'),
              Text('- 27 books of the New Testament'),
              SizedBox(height: 16),
              Text(
                'The text is used with permission and is available offline.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSelectionTile(
              context,
              title: 'System',
              subtitle: 'Match your device appearance',
              selected: _selectedTheme == 'system',
              onTap: () {
                _applyThemeMode('system');
                Navigator.pop(context);
              },
            ),
            _buildSelectionTile(
              context,
              title: 'Light',
              subtitle: 'Bright high-contrast reading surface',
              selected: _selectedTheme == 'light',
              onTap: () {
                _applyThemeMode('light');
                Navigator.pop(context);
              },
            ),
            _buildSelectionTile(
              context,
              title: 'Dark',
              subtitle: 'Dimmer reading surface for low light',
              selected: _selectedTheme == 'dark',
              onTap: () {
                _applyThemeMode('dark');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeStyleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Style'),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSelectionTile(
              context,
              title: 'Standard Missal',
              subtitle: 'Balanced liturgical colors with a clean reference-first look.',
              selected: _selectedThemeStyle == 'standard',
              onTap: () {
                _applyThemeStyle('standard');
                Navigator.pop(context);
              },
            ),
            _buildSelectionTile(
              context,
              title: 'Classic Parchment',
              subtitle: 'Uses the logo palette more often and softens seasonal color intensity.',
              selected: _selectedThemeStyle == 'parchment',
              onTap: () {
                _applyThemeStyle('parchment');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selectedBackground = isLight
        ? colorScheme.primary.withValues(alpha: 0.10)
        : colorScheme.primaryContainer.withValues(alpha: 0.5);
    final unselectedBackground = isLight
        ? colorScheme.surface
        : colorScheme.surfaceContainer;
    final selectedBorder = isLight
        ? colorScheme.primary.withValues(alpha: 0.55)
        : colorScheme.primary.withValues(alpha: 0.35);
    final titleColor = selected ? colorScheme.onSurface : colorScheme.onSurface;
    final subtitleColor = selected
        ? colorScheme.onSurface.withValues(alpha: 0.82)
        : colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? selectedBackground
            : unselectedBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? selectedBorder
              : colorScheme.outline.withValues(alpha: isLight ? 0.18 : 0.14),
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            height: 1.35,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : Icon(Icons.circle_outlined, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showAboutDialog(
      context: context,
      applicationName: 'Catholic Daily',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.church, color: colorScheme.onPrimary, size: 28),
      ),
      children: const [
        Text(
          'Your daily companion for Catholic liturgical readings. Includes the complete RSV Catholic Edition Bible and daily Mass readings.',
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant)
          : null,
      onTap: onTap,
    );
  }
}

