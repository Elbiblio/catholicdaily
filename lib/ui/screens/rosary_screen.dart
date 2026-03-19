import 'package:flutter/material.dart';
import '../../data/models/prayer.dart';
import '../../data/services/prayer_service.dart';
import 'prayer_detail_screen.dart';
import 'prayers_screen.dart';

class RosaryScreen extends StatelessWidget {
  const RosaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayerService = PrayerService();
    final allPrayers = prayerService.allPrayers;
    
    // Group Rosary mysteries
    final joyfulMysteries = _getMysteries(allPrayers, 'joyful');
    final sorrowfulMysteries = _getMysteries(allPrayers, 'sorrowful');
    final gloriousMysteries = _getMysteries(allPrayers, 'glorious');
    final luminousMysteries = _getMysteries(allPrayers, 'light');
    
    // Get essential Rosary prayers
    final openingPrayers = [
      prayerService.findPrayerBySlug('sign_of_the_cross'),
      prayerService.findPrayerBySlug('apostles_creed'),
      prayerService.findPrayerBySlug('pater_noster'),
      prayerService.findPrayerBySlug('hail_mary'),
      prayerService.findPrayerBySlug('glory_be'),
      prayerService.findPrayerBySlug('oh_my_jesus'),
    ].where((p) => p != null).cast<Prayer>().toList();
    
    final closingPrayers = [
      prayerService.findPrayerBySlug('salve_regina'),
      prayerService.findPrayerBySlug('memorare_st_joseph'),
    ].where((p) => p != null).cast<Prayer>().toList();
    
    final specialRosaries = [
      prayerService.findPrayerBySlug('rosary_for_the_dead'),
    ].where((p) => p != null).cast<Prayer>().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rosary'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            'How to Pray the Rosary',
            'Essential prayers and structure',
            openingPrayers,
            isSpecial: true,
          ),
          const SizedBox(height: 16),
          _buildMysterySection(
            context,
            'Joyful Mysteries',
            'Monday & Saturday (and Sundays during Advent)',
            joyfulMysteries,
            Icons.sentiment_very_satisfied,
          ),
          const SizedBox(height: 16),
          _buildMysterySection(
            context,
            'Sorrowful Mysteries',
            'Tuesday & Friday (and Sundays during Lent)',
            sorrowfulMysteries,
            Icons.sentiment_very_dissatisfied,
          ),
          const SizedBox(height: 16),
          _buildMysterySection(
            context,
            'Glorious Mysteries',
            'Wednesday & Sunday (outside Advent/Lent)',
            gloriousMysteries,
            Icons.auto_awesome,
          ),
          const SizedBox(height: 16),
          _buildMysterySection(
            context,
            'Luminous Mysteries',
            'Thursday',
            luminousMysteries,
            Icons.lightbulb,
          ),
          if (closingPrayers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection(
              context,
              'Closing Prayers',
              'Prayers to conclude the Rosary',
              closingPrayers,
            ),
          ],
          if (specialRosaries.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection(
              context,
              'Special Rosaries',
              'Devotional variations',
              specialRosaries,
            ),
          ],
        ],
      ),
    );
  }

  List<Prayer> _getMysteries(List<Prayer> allPrayers, String mysteryType) {
    return allPrayers
        .where((p) => p.slug.toLowerCase().startsWith(mysteryType))
        .toList()
      ..sort((a, b) {
        final aNum = _extractMysteryNumber(a.slug);
        final bNum = _extractMysteryNumber(b.slug);
        return aNum.compareTo(bNum);
      });
  }

  int _extractMysteryNumber(String slug) {
    final match = RegExp(r'(\d+)').firstMatch(slug);
    return match != null ? int.parse(match.group(1)!) : 999;
  }

  Widget _buildMysterySection(
    BuildContext context,
    String title,
    String subtitle,
    List<Prayer> mysteries,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Each mystery consists of:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Announce the mystery'),
                const Text('• Our Father'),
                const Text('• Ten Hail Marys (while meditating)'),
                const Text('• Glory Be'),
                const Text('• O my Jesus (Fatima prayer)'),
                const SizedBox(height: 16),
                const Text(
                  'Mysteries:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...mysteries.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final prayer = entry.value;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(prayer.title),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrayerDetailScreen(prayer: prayer),
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String subtitle,
    List<Prayer> prayers, {
    bool isSpecial = false,
  }) {
    return Card(
      elevation: isSpecial ? 4 : 2,
      color: isSpecial ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSpecial 
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            isSpecial ? Icons.menu_book : Icons.book,
            color: isSpecial 
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.white,
          ),
        ),
        title: Text(
          title,
          style: isSpecial 
              ? TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPrayersScreen(
                category: title,
                prayers: prayers,
              ),
            ),
          );
        },
      ),
    );
  }
}
