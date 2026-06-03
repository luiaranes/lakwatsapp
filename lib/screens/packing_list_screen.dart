import 'dart:async';
import 'package:flutter/material.dart';
import 'package:larga/models/destination.dart';
import 'package:larga/models/packing_item.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/trip_member.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/services/packing_list_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/services/trip_destination_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/widgets/skeleton_widgets.dart';

class _MemberOption {
  final String userId;
  final String displayName;

  _MemberOption({required this.userId, required this.displayName});
}

class PackingListScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const PackingListScreen({super.key, required this.tripId, this.trip});

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen>
    with SingleTickerProviderStateMixin {
  final _packingListService = PackingListService();
  final _tripService = TripService();
  final _profileService = ProfileService();
  final _tripDestinationService = TripDestinationService();
  final _itineraryService = ItineraryService();

  late TabController _tabController;

  // Owned by the screen (not the modal sheet) so it outlives the sheet's
  // close + keyboard-dismiss animation, which can still rebuild the TextField.
  // Disposing it with the sheet caused "TextEditingController used after
  // disposed" and a cascading framework assertion.
  final TextEditingController _itemNameController = TextEditingController();

  Trip? _trip;
  List<PackingItem> _myItems = [];
  List<PackingItem> _assignedByMe = [];
  List<_MemberOption> _members = [];
  Map<String, String> _memberNames = {};
  bool _isLoading = true;
  bool _canEdit = false;
  bool _isGenerating = false;
  String? _currentUserId;

  StreamSubscription<void>? _packingSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _trip = widget.trip;
    _currentUserId = _tripService.currentUserId;
    _loadData();
    _packingSubscription = _packingListService.subscribeToPackingItemsChanges(
      tripId: widget.tripId,
      onUpdate: () {
        if (mounted) _loadData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemNameController.dispose();
    _packingSubscription?.cancel();
    _packingListService.unsubscribeFromPackingItems(widget.tripId);
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _tripService.getTripById(widget.tripId),
        _tripService.canEdit(widget.tripId),
        _packingListService.getPackingItems(
          widget.tripId,
          view: PackingListView.myItems,
        ),
        _packingListService.getPackingItems(
          widget.tripId,
          view: PackingListView.assignedByMe,
        ),
        _tripService.getTripMembers(widget.tripId),
      ]);

      if (!mounted) return;

      final members = results[4] as List<TripMember>;
      final authIds = members.map((m) => m.userId).toList();
      final profiles = await _profileService.getProfilesByAuthIds(authIds);
      final profileMap = {for (final p in profiles) p.authId: p};

      final memberOptions = members.map((m) {
        final profile = profileMap[m.userId];
        return _MemberOption(
          userId: m.userId,
          displayName: profile?.displayName ?? 'Member',
        );
      }).toList()
        ..sort((a, b) {
          if (a.userId == _currentUserId) return -1;
          if (b.userId == _currentUserId) return 1;
          return a.displayName.compareTo(b.displayName);
        });

      setState(() {
        _trip = results[0] as Trip?;
        _canEdit = results[1] as bool;
        _myItems = results[2] as List<PackingItem>;
        _assignedByMe = results[3] as List<PackingItem>;
        _members = memberOptions;
        _memberNames = {
          for (final m in memberOptions) m.userId: m.displayName,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load packing list');
    }
  }

  int get _checkedCount => _myItems.where((i) => i.isChecked).length;

  Map<PackingCategory, List<PackingItem>> _grouped(List<PackingItem> items) {
    final map = <PackingCategory, List<PackingItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  String _assigneeLabel(PackingItem item) {
    if (item.isAssignedTo(_currentUserId ?? '')) {
      if (item.isCreatedBy(_currentUserId ?? '')) return 'Your item';
      final assigner = _memberNames[item.assignedByUserId ?? item.createdByUserId];
      return assigner != null ? 'Assigned by $assigner' : 'Assigned to you';
    }
    final name = _memberNames[item.assignedToUserId];
    return name != null ? 'Assigned to $name' : 'Assigned';
  }

  Future<void> _toggleItem(PackingItem item) async {
    try {
      final updated = await _packingListService.toggleChecked(item);
      if (!mounted) return;
      setState(() {
        _myItems = _myItems.map((i) => i.id == updated.id ? updated : i).toList();
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        e.toString().contains('assignee') ? e.toString() : 'Failed to update item',
      );
    }
  }

  Future<bool> _confirmDeleteItem(PackingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from the packing list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteItem(item);
      return true;
    }
    return false;
  }

  Future<void> _deleteItem(PackingItem item) async {
    try {
      await _packingListService.deleteItem(item.id, widget.tripId);
      if (!mounted) return;
      setState(() {
        _myItems.removeWhere((i) => i.id == item.id);
        _assignedByMe.removeWhere((i) => i.id == item.id);
      });
      SnackBarUtils.showSuccess(context, 'Item deleted');
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to delete item');
    }
  }

  Future<String?> _pickMember({
    required String title,
    String? initialUserId,
  }) async {
    if (_members.isEmpty) return _currentUserId;

    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ..._members.map(
              (member) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(member.displayName),
                trailing: member.userId == initialUserId
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, member.userId),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddItemSheet() => _showItemFormSheet();

  Future<void> _showEditItemSheet(PackingItem item) =>
      _showItemFormSheet(item: item);

  Future<void> _showItemFormSheet({PackingItem? item}) async {
    if (_members.isEmpty) {
      SnackBarUtils.showError(context, 'No trip members to assign');
      return;
    }

    final isEdit = item != null;
    final nameController = _itemNameController;
    nameController.text = item?.name ?? '';
    var category = item?.category ?? PackingCategory.other;
    var assigneeId =
        item?.assignedToUserId ?? _currentUserId ?? _members.first.userId;
    final originalAssigneeId = item?.assignedToUserId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit item' : 'Add item',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PackingCategory>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: PackingCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.icon} ${c.displayName}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => category = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: assigneeId,
                decoration: const InputDecoration(
                  labelText: 'Assign to',
                  border: OutlineInputBorder(),
                ),
                items: _members
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => assigneeId = value);
                },
              ),
              if (assigneeId != _currentUserId &&
                  (!isEdit || assigneeId != originalAssigneeId))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'They will get a notification',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  try {
                    if (isEdit) {
                      await _saveEditedItem(
                        item: item,
                        name: name,
                        category: category,
                        assigneeId: assigneeId,
                      );
                    } else {
                      await _packingListService.createItem(
                        tripId: widget.tripId,
                        name: name,
                        category: category,
                        assignedToUserId: assigneeId,
                      );
                      if (!mounted) return;
                      await _loadData(silent: true);
                      if (!mounted) return;
                      if (assigneeId != _currentUserId) {
                        SnackBarUtils.showSuccess(
                          context,
                          'Assigned to ${_memberNames[assigneeId]}',
                        );
                      }
                    }
                  } catch (_) {
                    if (!mounted) return;
                    SnackBarUtils.showError(
                      context,
                      isEdit ? 'Failed to update item' : 'Failed to add item',
                    );
                  }
                },
                child: Text(isEdit ? 'Save changes' : 'Add'),
              ),
              if (isEdit) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _confirmDeleteItem(item);
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'Delete item',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveEditedItem({
    required PackingItem item,
    required String name,
    required PackingCategory category,
    required String assigneeId,
  }) async {
    final updatedDraft = item.copyWith(name: name, category: category);

    if (assigneeId != item.assignedToUserId) {
      await _packingListService.reassignItem(
        item: updatedDraft,
        assignedToUserId: assigneeId,
      );
      if (!mounted) return;
      await _loadData(silent: true);
      if (!mounted) return;
      if (assigneeId != _currentUserId) {
        SnackBarUtils.showSuccess(
          context,
          'Assigned to ${_memberNames[assigneeId]}',
        );
      } else {
        SnackBarUtils.showSuccess(context, 'Item updated');
      }
    } else {
      await _packingListService.updateItem(updatedDraft);
      if (!mounted) return;
      await _loadData(silent: true);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Item updated');
    }
  }

  Future<void> _generateSuggestions() async {
    if (_trip == null) return;

    final assigneeId = await _pickMember(
      title: 'Assign AI suggestions to',
      initialUserId: _currentUserId,
    );
    if (assigneeId == null) return;

    setState(() => _isGenerating = true);
    try {
      final destinations = await _tripDestinationService.getTripDestinations(
        widget.tripId,
      );
      final itinerary = await _itineraryService.getItineraryItems(widget.tripId);

      final destinationContexts = destinations
          .map((d) => d.destination)
          .whereType<Destination>()
          .where((dest) => dest.name.isNotEmpty)
          .map(
            (dest) => PackingDestinationContext(
              name: dest.name,
              city: dest.city,
              province: dest.province,
              country: dest.country,
              latitude: dest.latitude,
              longitude: dest.longitude,
            ),
          )
          .toList();

      final existingNames = [
        ..._myItems.map((i) => i.name),
        ..._assignedByMe.map((i) => i.name),
      ];

      final suggestions = await _packingListService.generateSuggestions(
        tripTitle: _trip!.title,
        startDate: _trip!.startDate,
        endDate: _trip!.endDate,
        destinations: destinationContexts,
        activityTitles: itinerary.map((item) => item.title).toList(),
        existingItemNames: existingNames,
      );

      if (!mounted) return;

      if (suggestions.isEmpty) {
        SnackBarUtils.showInfo(context, 'No new suggestions — list looks complete');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI packing suggestions'),
          content: Text(
            'Add ${suggestions.length} items for ${_memberNames[assigneeId] ?? 'this member'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add all'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _packingListService.createItemsBulk(
        tripId: widget.tripId,
        items: suggestions,
        assignedToUserId: assigneeId,
      );

      if (!mounted) return;
      await _loadData(silent: true);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Added ${suggestions.length} items');
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to generate suggestions');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  bool _canManageItem(PackingItem item) {
    if (!_canEdit) return false;
    return item.isAssignedTo(_currentUserId ?? '') ||
        item.isCreatedBy(_currentUserId ?? '');
  }

  bool _canCheckItem(PackingItem item) {
    return item.isAssignedTo(_currentUserId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing list'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'My list (${_myItems.length})'),
            Tab(text: 'I assigned (${_assignedByMe.length})'),
          ],
        ),
        actions: [
          if (_canEdit && !_isLoading)
            IconButton(
              onPressed: _isGenerating ? null : _generateSuggestions,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              tooltip: 'AI suggestions',
            ),
        ],
      ),
      body: _isLoading
          ? const TripDetailSkeleton()
          : Column(
              children: [
                if (_tabController.index == 0 && _myItems.isNotEmpty)
                  _buildProgressHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItemsList(_myItems, isMyList: true),
                      _buildItemsList(_assignedByMe, isMyList: false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _canEdit && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showAddItemSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
    );
  }

  Widget _buildProgressHeader() {
    final progress = _myItems.isEmpty ? 0.0 : _checkedCount / _myItems.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_checkedCount of ${_myItems.length} packed',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<PackingItem> items, {required bool isMyList}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isMyList
                ? 'No items assigned to you yet'
                : 'You have not assigned items to others',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _buildGroupedList(items, isMyList: isMyList),
      ),
    );
  }

  List<Widget> _buildGroupedList(List<PackingItem> items, {required bool isMyList}) {
    final widgets = <Widget>[];
    final grouped = _grouped(items);

    for (final category in PackingCategory.values) {
      if (!grouped.containsKey(category)) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Text(
            '${category.icon} ${category.displayName}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      );
      for (final item in grouped[category]!) {
        widgets.add(_buildItemTile(item, isMyList: isMyList));
      }
    }
    return widgets;
  }

  Widget _buildItemTile(PackingItem item, {required bool isMyList}) {
    final canCheck = isMyList && _canCheckItem(item);
    final canManage = _canManageItem(item);

    return Dismissible(
      key: ValueKey(item.id),
      direction: canManage ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteItem(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: item.isChecked,
          onChanged: canCheck ? (_) => _toggleItem(item) : null,
          title: Text(
            item.name,
            style: TextStyle(
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked ? Colors.grey : null,
            ),
          ),
          subtitle: Text(
            _assigneeLabel(item),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          secondary: canManage
              ? PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        await _showEditItemSheet(item);
                      case 'delete':
                        await _confirmDeleteItem(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              : null,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
