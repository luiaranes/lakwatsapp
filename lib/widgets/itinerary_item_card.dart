import 'package:flutter/material.dart';
import 'package:larga/models/itinerary_item.dart';

class ItineraryItemCard extends StatelessWidget {
  final ItineraryItem item;
  final int index;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ItineraryItemCard({
    super.key,
    required this.item,
    required this.index,
    this.canEdit = false,
    this.onTap,
    this.onDelete,
  });

  Color _getCategoryColor() {
    return switch (item.category) {
      ItineraryCategory.transport => Colors.blue,
      ItineraryCategory.accommodation => Colors.purple,
      ItineraryCategory.food => Colors.orange,
      ItineraryCategory.activity => Colors.green,
      ItineraryCategory.sightseeing => Colors.pink,
      ItineraryCategory.shopping => Colors.teal,
      ItineraryCategory.rest => Colors.indigo,
      ItineraryCategory.other => Colors.grey,
    };
  }

  IconData _getCategoryIcon() {
    return switch (item.category) {
      ItineraryCategory.transport => Icons.directions_car_outlined,
      ItineraryCategory.accommodation => Icons.hotel_outlined,
      ItineraryCategory.food => Icons.restaurant_outlined,
      ItineraryCategory.activity => Icons.hiking,
      ItineraryCategory.sightseeing => Icons.photo_camera_outlined,
      ItineraryCategory.shopping => Icons.shopping_bag_outlined,
      ItineraryCategory.rest => Icons.bed_outlined,
      ItineraryCategory.other => Icons.place_outlined,
    };
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    
    // Parse HH:mm:ss or HH:mm format
    final parts = time.split(':');
    if (parts.length < 2) return time;
    
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getTimeRange() {
    if (item.startTime == null && item.endTime == null) return '';
    
    final start = _formatTime(item.startTime);
    final end = _formatTime(item.endTime);
    
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    return start.isNotEmpty ? start : end;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();
    final timeRange = _getTimeRange();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Category indicator bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                // Drag handle (when editable)
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.grey[400],
                      size: 18,
                    ),
                  ),
                // Category icon
                Container(
                  margin: EdgeInsets.only(left: canEdit ? 0 : 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.estimatedCost != null)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.currency ?? '₱'}${item.estimatedCost!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Time and location row
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (timeRange.isNotEmpty)
                              _InfoChip(
                                icon: Icons.access_time,
                                text: timeRange,
                              ),
                            if (item.location != null && item.location!.isNotEmpty)
                              _InfoChip(
                                icon: Icons.place_outlined,
                                text: item.location!,
                              ),
                          ],
                        ),
                        if (item.description != null && item.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.description!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Actions
                if (canEdit)
                  SizedBox(
                    width: 36,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete?.call();
                        } else if (value == 'edit') {
                          onTap?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
