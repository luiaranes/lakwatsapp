import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/user_notification.dart';
import 'package:larga/screens/packing_list_screen.dart';
import 'package:larga/screens/trip_detail_screen.dart';
import 'package:larga/services/notification_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  List<UserNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _notificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load notifications');
    }
  }

  Future<void> _openNotification(UserNotification notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map(
                (n) => n.id == notification.id
                    ? UserNotification(
                        id: n.id,
                        userId: n.userId,
                        tripId: n.tripId,
                        type: n.type,
                        title: n.title,
                        body: n.body,
                        data: n.data,
                        readAt: DateTime.now(),
                        createdAt: n.createdAt,
                      )
                    : n,
              )
              .toList();
        });
      }
    }

    if (!mounted || notification.tripId == null) return;

    switch (notification.type) {
      case UserNotificationType.packingAssigned:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PackingListScreen(tripId: notification.tripId!),
          ),
        );
      case UserNotificationType.other:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                TripDetailScreen(tripId: notification.tripId!),
          ),
        );
    }
  }

  IconData _iconFor(UserNotificationType type) {
    return switch (type) {
      UserNotificationType.packingAssigned => Icons.luggage_outlined,
      UserNotificationType.other => Icons.notifications_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                _load();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        color: notification.isRead
                            ? null
                            : Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.25),
                        child: ListTile(
                          leading: Icon(_iconFor(notification.type)),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (notification.body != null)
                                Text(notification.body!),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.yMMMd().add_jm().format(
                                      notification.createdAt.toLocal(),
                                    ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _openNotification(notification),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
