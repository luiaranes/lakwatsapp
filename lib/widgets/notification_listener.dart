import 'dart:async';
import 'package:flutter/material.dart';
import 'package:larga/models/user_notification.dart';
import 'package:larga/services/notification_service.dart';
import 'package:larga/screens/packing_list_screen.dart';
import 'package:larga/screens/trip_detail_screen.dart';

class NotificationListenerScope extends StatefulWidget {
  final Widget child;

  const NotificationListenerScope({super.key, required this.child});

  @override
  State<NotificationListenerScope> createState() =>
      _NotificationListenerScopeState();
}

class _NotificationListenerScopeState extends State<NotificationListenerScope> {
  final _notificationService = NotificationService();
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _notificationService.subscribeToNotifications(
      onNotification: _handleNotification,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _notificationService.unsubscribeFromNotifications();
    super.dispose();
  }

  void _handleNotification(UserNotification notification) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(notification.body ?? notification.title),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openNotification(notification),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _openNotification(UserNotification notification) {
    final tripId = notification.tripId;
    if (tripId == null) return;

    switch (notification.type) {
      case UserNotificationType.packingAssigned:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PackingListScreen(tripId: tripId),
          ),
        );
      case UserNotificationType.other:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(tripId: tripId),
          ),
        );
    }

    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
