import 'package:flutter/material.dart';
import '../../../data/models/church.dart';

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
