import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/activity_log.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/activity_log_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class ActivityLogList extends StatefulWidget {
  final String tripId;
  final int maxItems;
  final bool showHeader;
  final VoidCallback? onViewAll;

  const ActivityLogList({
    super.key,
    required this.tripId,
    this.maxItems = 10,
    this.showHeader = true,
    this.onViewAll,
  });

  @override
  State<ActivityLogList> createState() => _ActivityLogListState();
}

class _ActivityLogListState extends State<ActivityLogList> {
  final _activityLogService = ActivityLogService();
  final _profileService = ProfileService();

  List<ActivityLog> _logs = [];
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoading = true;

  StreamSubscription<void>? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _activitySubscription = _activityLogService.subscribeToActivityLogChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadLogs();
      },
    );
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _activityLogService.unsubscribeFromActivityLogs(widget.tripId);
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _activityLogService.getTripActivityLogs(
        widget.tripId,
        limit: widget.maxItems,
      );

      if (!mounted) return;

      // Get unique user IDs and fetch profiles
      final userIds = logs.map((l) => l.userId).toSet().toList();
      final profiles = await _profileService.getProfilesByAuthIds(userIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      setState(() {
        _logs = logs;
        _userProfiles = profileMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  IconData _getActionIcon(ActivityAction action) {
    return switch (action) {
      ActivityAction.created => Icons.add_circle_outline,
      ActivityAction.updated => Icons.edit_outlined,
      ActivityAction.deleted => Icons.remove_circle_outline,
      ActivityAction.joined => Icons.person_add_outlined,
      ActivityAction.left => Icons.person_remove_outlined,
      ActivityAction.invited => Icons.send_outlined,
      ActivityAction.removed => Icons.person_off_outlined,
      ActivityAction.reordered => Icons.swap_vert,
      ActivityAction.settled => Icons.check_circle_outline,
      ActivityAction.other => Icons.info_outline,
    };
  }

  Color _getActionColor(ActivityAction action) {
    return switch (action) {
      ActivityAction.created => Colors.green,
      ActivityAction.updated => Colors.blue,
      ActivityAction.deleted => Colors.red,
      ActivityAction.joined => Colors.teal,
      ActivityAction.left => Colors.orange,
      ActivityAction.invited => Colors.purple,
      ActivityAction.removed => Colors.red,
      ActivityAction.reordered => Colors.indigo,
      ActivityAction.settled => Colors.green,
      ActivityAction.other => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: List.generate(3, (_) => const ActivityLogItemSkeleton()),
      );
    }

    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) _buildHeader(),
        ..._logs.map((log) => _ActivityLogItem(
          log: log,
          userProfile: _userProfiles[log.userId],
          formatTime: _formatTime,
          getActionIcon: _getActionIcon,
          getActionColor: _getActionColor,
        )),
        if (widget.onViewAll != null && _logs.length >= widget.maxItems)
          _buildViewAllButton(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 32, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No activity yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextButton(
        onPressed: widget.onViewAll,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('View all activity'),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ActivityLogItem extends StatelessWidget {
  final ActivityLog log;
  final UserProfile? userProfile;
  final String Function(DateTime) formatTime;
  final IconData Function(ActivityAction) getActionIcon;
  final Color Function(ActivityAction) getActionColor;

  const _ActivityLogItem({
    required this.log,
    this.userProfile,
    required this.formatTime,
    required this.getActionIcon,
    required this.getActionColor,
  });

  void _showDetailedChanges(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActivityDetailSheet(
        log: log,
        userProfile: userProfile,
        formatTime: formatTime,
        getActionIcon: getActionIcon,
        getActionColor: getActionColor,
      ),
    );
  }

  bool get _isTappable {
    // Allow tapping for update actions (they may have details)
    // Also allow tapping for expense splits to show split details
    if (log.entityType == ActivityEntityType.expenseSplit) {
      return true;
    }
    return log.action == ActivityAction.updated;
  }

  @override
  Widget build(BuildContext context) {
    final color = getActionColor(log.action);
    final actorName = userProfile?.displayName ?? 'Someone';

    return InkWell(
      onTap: _isTappable ? () => _showDetailedChanges(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundImage: userProfile?.avatarUrl != null
                  ? NetworkImage(userProfile!.avatarUrl!)
                  : null,
              backgroundColor: Colors.grey[200],
              child: userProfile?.avatarUrl == null
                  ? Text(
                      _getInitials(userProfile?.displayName),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${_getActionText()}'),
                      ],
                    ),
                  ),
                  if (_getDetailsText() != null || _isTappable) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _getDetailsText() ?? 'Tap to view details',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isTappable ? Theme.of(context).primaryColor : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        if (_isTappable) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    formatTime(log.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Action icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                getActionIcon(log.action),
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _getInviteText() {
    final name = log.targetUserName ?? 'a member';
    final role = log.details['role'] as String?;
    if (role != null && role != 'viewer') {
      final roleDisplay = role == 'editor' ? 'Editor' : role == 'owner' ? 'Owner' : role;
      return 'invited $name as $roleDisplay';
    }
    return 'invited $name';
  }

  String _getActionText() {
    final target = log.itemTitle ?? log.itemName;

    if (log.entityType == ActivityEntityType.expenseSplit) {
      final memberCount = log.details['member_count'] ?? 0;
      final fromName = log.details['from_user_name'] as String? ?? 'Someone';
      final toName = log.details['to_user_name'] as String? ?? 'someone';
      
      return switch (log.action) {
        ActivityAction.created => memberCount > 0 
            ? 'split "$target" among $memberCount members'
            : 'split "$target"',
        ActivityAction.updated => 'updated split for "$target"',
        ActivityAction.deleted => 'removed split for "$target"',
        ActivityAction.settled => 'settled debt: $fromName paid $toName',
        _ => 'modified split',
      };
    }

    return switch (log.action) {
      ActivityAction.created => target != null ? 'added "$target"' : 'added an item',
      ActivityAction.updated => target != null ? 'updated "$target"' : 'made changes',
      ActivityAction.deleted => target != null ? 'removed "$target"' : 'removed an item',
      ActivityAction.joined => 'joined the trip',
      ActivityAction.left => 'left the trip',
      ActivityAction.invited => _getInviteText(),
      ActivityAction.removed => 'removed ${log.targetUserName ?? "a member"}',
      ActivityAction.reordered => 'reordered Day ${log.details['day_number'] ?? ''} activities',
      ActivityAction.settled => target != null ? 'settled "$target"' : 'settled a debt',
      ActivityAction.other => 'made changes',
    };
  }

  String? _getDetailsText() {
    final changedFields = log.changedFields;
    
    if (log.action == ActivityAction.updated && changedFields != null && changedFields.isNotEmpty) {
      final formatted = changedFields.map(_formatFieldName).toList();
      if (formatted.length == 1) {
        return 'Changed: ${formatted.first}';
      } else if (formatted.length == 2) {
        return 'Changed: ${formatted[0]} and ${formatted[1]}';
      } else {
        return 'Changed: ${formatted.take(2).join(", ")} +${formatted.length - 2} more';
      }
    }
    
    // Show details for expense splits
    if (log.entityType == ActivityEntityType.expenseSplit) {
      final amount = log.details['expense_amount'];
      final currency = log.details['currency'] as String? ?? 'PHP';
      final splitType = log.details['split_type'] as String?;
      final memberCount = log.details['member_count'];
      final memberNames = log.details['member_names'] as List?;
      
      if (log.action == ActivityAction.settled) {
        return 'Debt marked as paid';
      }
      
      if (amount != null) {
        final symbol = _getCurrencySymbol(currency);
        final amountStr = '$symbol${(amount as num).toStringAsFixed(2)}';
        final splitTypeStr = splitType != null ? _formatFieldName(splitType) : 'Equal';
        
        if (memberNames != null && memberNames.isNotEmpty) {
          final names = memberNames.take(3).join(', ');
          final extra = memberNames.length > 3 ? ' +${memberNames.length - 3} more' : '';
          return '$amountStr • $splitTypeStr split • $names$extra';
        }
        
        if (memberCount != null && memberCount > 0) {
          return '$amountStr • $splitTypeStr split among $memberCount members';
        }
        
        return '$amountStr • $splitTypeStr split';
      }
    }
    
    // Show amount and category for created expenses
    if (log.action == ActivityAction.created && log.entityType == ActivityEntityType.expense) {
      final amount = log.details['amount'];
      final currency = log.details['currency'] as String? ?? 'PHP';
      final category = log.details['category'] as String?;
      
      if (amount != null) {
        final symbol = _getCurrencySymbol(currency);
        final amountStr = '$symbol${(amount as num).toStringAsFixed(2)}';
        if (category != null) {
          return '$amountStr • ${_formatFieldName(category)}';
        }
        return amountStr;
      }
    }
    
    // Show category for other created items
    if (log.action == ActivityAction.created && log.details['category'] != null) {
      return 'Category: ${_formatFieldName(log.details['category'] as String)}';
    }
    
    // Show day number for reordered
    if (log.action == ActivityAction.reordered && log.details['item_count'] != null) {
      return '${log.details['item_count']} items reordered';
    }
    
    return null;
  }

  String _getCurrencySymbol(String currency) {
    return switch (currency) {
      'PHP' => '₱',
      'USD' => '\$',
      'EUR' => '€',
      'JPY' => '¥',
      'SGD' => 'S\$',
      'THB' => '฿',
      'KRW' => '₩',
      _ => currency,
    };
  }

  String _formatFieldName(String field) {
    // Handle special field names
    if (field == 'paid_by_user_id') return 'Payer';
    if (field == 'expense_date') return 'Date';
    if (field == 'is_settled') return 'Settled';
    if (field == 'itinerary_item_id') return 'Linked Itinerary';
    
    // Convert snake_case to readable format
    return field
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'(^|\s)(\w)'),
          (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
        )
        .replaceAll('Estimated Cost', 'Cost')
        .replaceAll('Start Time', 'Time')
        .replaceAll('End Time', 'End time');
  }
}

/// Full screen activity log viewer
class ActivityLogScreen extends StatefulWidget {
  final String tripId;
  final String? tripTitle;

  const ActivityLogScreen({
    super.key,
    required this.tripId,
    this.tripTitle,
  });

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _activityLogService = ActivityLogService();
  final _profileService = ProfileService();
  final _scrollController = ScrollController();

  List<ActivityLog> _logs = [];
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 30;

  StreamSubscription<void>? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLogs();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _activitySubscription = _activityLogService.subscribeToActivityLogChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadLogs();
      },
    );
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _activityLogService.unsubscribeFromActivityLogs(widget.tripId);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _activityLogService.getTripActivityLogs(
        widget.tripId,
        limit: _pageSize,
      );

      if (!mounted) return;

      final userIds = logs.map((l) => l.userId).toSet().toList();
      final profiles = await _profileService.getProfilesByAuthIds(userIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      setState(() {
        _logs = logs;
        _userProfiles = profileMap;
        _isLoading = false;
        _hasMore = logs.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final logs = await _activityLogService.getTripActivityLogs(
        widget.tripId,
        limit: _pageSize,
        offset: _logs.length,
      );

      if (!mounted) return;

      final newUserIds = logs
          .map((l) => l.userId)
          .where((id) => !_userProfiles.containsKey(id))
          .toSet()
          .toList();

      if (newUserIds.isNotEmpty) {
        final profiles = await _profileService.getProfilesByAuthIds(newUserIds);
        for (var p in profiles) {
          _userProfiles[p.authId] = p;
        }
      }

      setState(() {
        _logs.addAll(logs);
        _isLoadingMore = false;
        _hasMore = logs.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
    }
  }

  IconData _getActionIcon(ActivityAction action) {
    return switch (action) {
      ActivityAction.created => Icons.add_circle_outline,
      ActivityAction.updated => Icons.edit_outlined,
      ActivityAction.deleted => Icons.remove_circle_outline,
      ActivityAction.joined => Icons.person_add_outlined,
      ActivityAction.left => Icons.person_remove_outlined,
      ActivityAction.invited => Icons.send_outlined,
      ActivityAction.removed => Icons.person_off_outlined,
      ActivityAction.reordered => Icons.swap_vert,
      ActivityAction.settled => Icons.check_circle_outline,
      ActivityAction.other => Icons.info_outline,
    };
  }

  Color _getActionColor(ActivityAction action) {
    return switch (action) {
      ActivityAction.created => Colors.green,
      ActivityAction.updated => Colors.blue,
      ActivityAction.deleted => Colors.red,
      ActivityAction.joined => Colors.teal,
      ActivityAction.left => Colors.orange,
      ActivityAction.invited => Colors.purple,
      ActivityAction.removed => Colors.red,
      ActivityAction.reordered => Colors.indigo,
      ActivityAction.settled => Colors.green,
      ActivityAction.other => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripTitle != null ? 'Activity • ${widget.tripTitle}' : 'Activity'),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 8,
              itemBuilder: (_, __) => const ActivityLogItemSkeleton(),
            )
          : _logs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _logs.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _logs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final log = _logs[index];
                      return _ActivityLogItem(
                        log: log,
                        userProfile: _userProfiles[log.userId],
                        formatTime: _formatTime,
                        getActionIcon: _getActionIcon,
                        getActionColor: _getActionColor,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Changes to this trip will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing detailed changes for an activity log
class _ActivityDetailSheet extends StatelessWidget {
  final ActivityLog log;
  final UserProfile? userProfile;
  final String Function(DateTime) formatTime;
  final IconData Function(ActivityAction) getActionIcon;
  final Color Function(ActivityAction) getActionColor;

  const _ActivityDetailSheet({
    required this.log,
    this.userProfile,
    required this.formatTime,
    required this.getActionIcon,
    required this.getActionColor,
  });

  Widget _buildNoDetailsView() {
    final changedFields = log.changedFields;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Detailed changes not available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (changedFields != null && changedFields.isNotEmpty) ...[
              Text(
                'Fields modified:',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: changedFields.map((field) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatFieldName(field),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  );
                }).toList(),
              ),
            ] else
              Text(
                'Changes were made to this item',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSplitDetails(ScrollController scrollController) {
    final details = log.details;
    final title = details['title'] as String? ?? 'Expense';
    final amount = details['expense_amount'] as num?;
    final currency = details['currency'] as String? ?? 'PHP';
    final splitType = details['split_type'] as String?;
    final memberCount = details['member_count'] as int?;
    final memberNames = details['member_names'] as List?;
    final fromName = details['from_user_name'] as String?;
    final toName = details['to_user_name'] as String?;

    String getCurrencySymbol(String curr) {
      return switch (curr) {
        'PHP' => '₱',
        'USD' => '\$',
        'EUR' => '€',
        'JPY' => '¥',
        'SGD' => 'S\$',
        'THB' => '฿',
        'KRW' => '₩',
        _ => curr,
      };
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Action type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                log.action == ActivityAction.settled
                    ? Icons.check_circle
                    : log.action == ActivityAction.created
                        ? Icons.call_split
                        : Icons.edit,
                size: 16,
                color: Colors.green[700],
              ),
              const SizedBox(width: 6),
              Text(
                log.action == ActivityAction.settled
                    ? 'Debt Settled'
                    : log.action == ActivityAction.created
                        ? 'Split Created'
                        : 'Split Updated',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Settlement details
        if (log.action == ActivityAction.settled) ...[
          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'Paid by',
            value: fromName ?? 'Unknown',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.person,
            label: 'Received by',
            value: toName ?? 'Unknown',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.receipt_outlined,
            label: 'Related to',
            value: title,
          ),
        ],

        // Split details (for non-settled actions)
        if (log.action != ActivityAction.settled) ...[
          _buildDetailRow(
            icon: Icons.receipt_outlined,
            label: 'Expense',
            value: title,
          ),
          const SizedBox(height: 12),
          if (amount != null)
            _buildDetailRow(
              icon: Icons.payments_outlined,
              label: 'Total Amount',
              value: '${getCurrencySymbol(currency)}${amount.toStringAsFixed(2)}',
            ),
          const SizedBox(height: 12),
          if (splitType != null)
            _buildDetailRow(
              icon: Icons.pie_chart_outline,
              label: 'Split Type',
              value: _formatFieldName(splitType),
            ),
          const SizedBox(height: 12),
          if (memberCount != null)
            _buildDetailRow(
              icon: Icons.group_outlined,
              label: 'Split Among',
              value: '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
            ),
          if (memberNames != null && memberNames.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Members',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: memberNames.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        name.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'(^|\s)(\w)'),
          (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final changes = log.changes ?? {};
    final color = getActionColor(log.action);
    final actorName = userProfile?.displayName ?? 'Someone';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(getActionIcon(log.action), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$actorName made changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatTime(log.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Changes list
              Expanded(
                child: log.entityType == ActivityEntityType.expenseSplit
                    ? _buildExpenseSplitDetails(scrollController)
                    : changes.isEmpty
                        ? _buildNoDetailsView()
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: changes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                            itemBuilder: (context, index) {
                              final field = changes.keys.elementAt(index);
                              final change = changes[field]!;
                              return _ChangeItem(
                                field: field,
                                fromValue: change['from'],
                                toValue: change['to'],
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChangeItem extends StatelessWidget {
  final String field;
  final dynamic fromValue;
  final dynamic toValue;

  const _ChangeItem({
    required this.field,
    required this.fromValue,
    required this.toValue,
  });

  String _formatFieldName(String field) {
    // Handle special field names
    if (field == 'cover_image_url') return 'Cover Photo';
    if (field == 'avatar_url') return 'Avatar';
    if (field == 'is_public') return 'Visibility';
    if (field == 'estimated_cost') return 'Estimated Cost';
    if (field == 'start_date') return 'Start Date';
    if (field == 'end_date') return 'End Date';
    if (field == 'start_time') return 'Start Time';
    if (field == 'end_time') return 'End Time';
    if (field == 'day_number') return 'Day';
    if (field == 'sort_order') return 'Order';
    if (field == 'expense_date') return 'Date';
    if (field == 'is_settled') return 'Settled';
    if (field == 'receipt_url') return 'Receipt';
    if (field == 'paid_by_user_id') return 'Paid By';
    if (field == 'itinerary_item_id') return 'Linked Itinerary';
    
    return field
        .replaceAll('_url', '')
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'(^|\s)(\w)'),
          (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
        );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'Not set';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) {
      // Format as currency if it looks like a budget or amount
      if (field.contains('budget') || field.contains('cost') || field == 'amount') {
        return '₱${value.toStringAsFixed(2)}';
      }
      if (value is double) return value.toStringAsFixed(2);
      return value.toString();
    }
    if (value is String && value.isEmpty) return 'Not set';
    
    // Handle UUID fields (user IDs) - show as "Changed" since we can't resolve names here
    if (value is String && RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(value)) {
      if (field.contains('user_id') || field.contains('owner_id')) {
        return 'Another member';
      }
      return value.substring(0, 8) + '...';
    }
    
    // Handle URL fields (cover photos, avatars, etc.) - don't show raw URLs
    if (value is String && (value.startsWith('http://') || value.startsWith('https://'))) {
      if (field.contains('cover') || field.contains('image')) {
        return 'Photo uploaded';
      }
      if (field.contains('avatar')) {
        return 'Avatar uploaded';
      }
      return 'Link added';
    }
    
    // Format time strings (HH:mm:ss)
    if (value is String && RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(value)) {
      final parts = value.split(':');
      final hour = int.parse(parts[0]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:${parts[1]} $period';
    }
    
    // Format date strings
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      try {
        final date = DateTime.parse(value);
        return DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }
    
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fromFormatted = _formatValue(fromValue);
    final toFormatted = _formatValue(toValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatFieldName(field),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // From value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_circle_outline, size: 12, color: Colors.red[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Before',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.red[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fromFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          decoration: fromValue != null ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.red[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
              ),
              // To value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 12, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            'After',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        toFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
