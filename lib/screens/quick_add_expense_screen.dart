import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/expense.dart';
import 'package:larga/models/expense_split.dart';
import 'package:larga/models/parsed_expense.dart';
import 'package:larga/services/quick_add_service.dart';
import 'package:larga/services/expense_service.dart';
import 'package:larga/services/expense_split_service.dart';
import 'package:larga/services/trip_service.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/add_edit_expense_screen.dart';
import 'package:larga/widgets/expense_split_selector.dart';
import 'package:larga/widgets/voice_input_button.dart';

class QuickAddExpenseScreen extends StatefulWidget {
  final String tripId;
  final Trip? trip;

  const QuickAddExpenseScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<QuickAddExpenseScreen> createState() => _QuickAddExpenseScreenState();
}

class _QuickAddExpenseScreenState extends State<QuickAddExpenseScreen> {
  final _quickAddService = QuickAddService();
  final _expenseService = ExpenseService();
  final _expenseSplitService = ExpenseSplitService();
  final _tripService = TripService();
  final _profileService = ProfileService();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  Trip? _trip;
  ParsedExpense? _parsedExpense;
  List<TripMemberInfo> _tripMembers = [];
  List<SplitMember> _splitMembers = [];
  ExpenseSplitData? _splitData;

  bool _isParsing = false;
  bool _isSaving = false;
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadTripMembers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadTripMembers() async {
    try {
      final members = await _tripService.getTripMembers(widget.tripId);
      final authIds = members.map((m) => m.userId).toList();
      final profiles = await _profileService.getProfilesByAuthIds(authIds);
      final profileMap = {for (var p in profiles) p.authId: p};

      final currentUserId = _tripService.currentUserId;

      final tripMembers = members.map((m) {
        final profile = profileMap[m.userId];
        return TripMemberInfo(
          userId: m.userId,
          name: profile?.displayName ?? 'Unknown',
        );
      }).toList();

      final splitMembers = members.map((m) {
        final profile = profileMap[m.userId];
        return SplitMember(
          userId: m.userId,
          displayName: profile?.displayName ?? 'Unknown',
          avatarUrl: profile?.avatarUrl,
          isCurrentUser: m.userId == currentUserId,
        );
      }).toList();

      // Sort: current user first
      splitMembers.sort((a, b) {
        if (a.isCurrentUser) return -1;
        if (b.isCurrentUser) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      if (!mounted) return;

      setState(() {
        _tripMembers = tripMembers;
        _splitMembers = splitMembers;
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Failed to load trip members: $e');
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _parseText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isParsing = true;
      _parsedExpense = null;
    });

    try {
      final result = await _quickAddService.parseExpenseText(
        text: text,
        tripCurrency: _trip?.currency ?? 'PHP',
        tripMembers: _tripMembers,
      );

      if (!mounted) return;

      setState(() {
        _parsedExpense = result;
        _isParsing = false;
      });

      if (result.confidence < 0.5) {
        SnackBarUtils.showInfo(
          context,
          'Low confidence. Please verify the details.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsing = false);
      SnackBarUtils.showError(context, 'Failed to parse expense');
    }
  }

  Future<void> _quickSave() async {
    if (_parsedExpense == null || !_parsedExpense!.hasValidAmount) {
      SnackBarUtils.showError(context, 'Please enter a valid expense');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final expense = await _expenseService.createExpense(
        tripId: widget.tripId,
        amount: _parsedExpense!.amount!,
        description: _parsedExpense!.description ?? 'Expense',
        expenseDate: _parsedExpense!.date ?? DateTime.now(),
        currency: _parsedExpense!.currency ?? _trip?.currency ?? 'PHP',
        category: _parsedExpense!.suggestedCategory ?? ExpenseCategory.other,
        notes: _parsedExpense!.notes,
      );

      // Handle expense splits if configured
      if (_splitData != null && _splitData!.memberIds.isNotEmpty) {
        switch (_splitData!.splitType) {
          case SplitType.equal:
            await _expenseSplitService.createEqualSplits(
              expenseId: expense.id,
              totalAmount: _parsedExpense!.amount!,
              memberIds: _splitData!.memberIds,
            );
            break;
          case SplitType.percentage:
            if (_splitData!.percentages != null) {
              await _expenseSplitService.createPercentageSplits(
                expenseId: expense.id,
                totalAmount: _parsedExpense!.amount!,
                memberPercentages: _splitData!.percentages!,
              );
            }
            break;
          case SplitType.exact:
            if (_splitData!.amounts != null) {
              await _expenseSplitService.createExactSplits(
                expenseId: expense.id,
                totalAmount: _parsedExpense!.amount!,
                memberAmounts: _splitData!.amounts!,
              );
            }
            break;
        }
      }

      if (!mounted) return;

      SnackBarUtils.showSuccess(context, 'Expense added!');
      Navigator.of(context).pop(expense);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(context, 'Failed to save expense');
    }
  }

  void _editBeforeSaving() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddEditExpenseScreen(
          tripId: widget.tripId,
          existingExpense: null,
          trip: _trip,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add'),
        actions: [
          if (_parsedExpense != null)
            TextButton(
              onPressed: _editBeforeSaving,
              child: const Text('Edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputSection(theme),
                    const SizedBox(height: 16),
                    if (_isParsing) _buildParsingIndicator(theme),
                    if (_parsedExpense != null) ...[
                      _buildParsedResult(theme),
                      const SizedBox(height: 16),
                      _buildSplitSection(theme),
                    ],
                    const SizedBox(height: 16),
                    _buildExampleHints(theme),
                  ],
                ),
              ),
            ),
            _buildBottomActions(theme),
          ],
        ),
      ),
    );
  }

  void _onVoiceTranscript(String transcript) {
    _textController.text = transcript;
    _parseText(transcript);
  }

  Widget _buildInputSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_outlined,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Describe your expense',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              VoiceInputButton(
                onTranscript: _onVoiceTranscript,
                onError: (error) {
                  SnackBarUtils.showError(context, error);
                },
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'e.g., "lunch at Jollibee 350 pesos"',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: theme.textTheme.titleMedium,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (text) {
              if (text.isNotEmpty) _parseText(text);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isParsing || _textController.text.isEmpty
                ? null
                : () => _parseText(_textController.text),
            icon: _isParsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_isParsing ? 'Parsing...' : 'Parse with AI'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsingIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Understanding your expense...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedResult(ThemeData theme) {
    final expense = _parsedExpense!;
    final confidence = expense.confidence;
    final confidenceColor = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Parsed Expense',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: confidenceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildResultRow(
            theme,
            icon: Icons.description_outlined,
            label: 'Description',
            value: expense.description ?? 'Not detected',
            isDetected: expense.hasValidDescription,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            theme,
            icon: Icons.payments_outlined,
            label: 'Amount',
            value: expense.hasValidAmount ? expense.displayAmount : 'Not detected',
            isDetected: expense.hasValidAmount,
            isHighlighted: true,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            theme,
            icon: Icons.category_outlined,
            label: 'Category',
            value: expense.suggestedCategory?.displayName ?? 'Other',
            isDetected: expense.suggestedCategory != null,
            emoji: expense.suggestedCategory?.icon,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            theme,
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: expense.date != null
                ? DateFormat('MMM d, yyyy').format(expense.date!)
                : 'Today',
            isDetected: expense.date != null,
          ),
          if (expense.hasSplitInfo) ...[
            const SizedBox(height: 12),
            _buildResultRow(
              theme,
              icon: Icons.people_outline,
              label: 'Split with',
              value: expense.splitWith!.join(', '),
              isDetected: true,
            ),
          ],
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildResultRow(
              theme,
              icon: Icons.note_outlined,
              label: 'Notes',
              value: expense.notes!,
              isDetected: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDetected,
    bool isHighlighted = false,
    String? emoji,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDetected ? theme.colorScheme.primary : Colors.grey[400],
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  style: isHighlighted
                      ? theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDetected
                              ? theme.colorScheme.primary
                              : Colors.grey[400],
                        )
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: isDetected ? null : Colors.grey[400],
                          fontStyle: isDetected ? null : FontStyle.italic,
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExampleHints(ThemeData theme) {
    final examples = [
      'lunch at Jollibee 350',
      'taxi to airport \$15',
      'coffee 150 php with Maria',
      'hotel 5000 for 2 nights',
      'yesterday dinner 800 pesos',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mic_outlined, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              'Try saying or typing:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: examples.map((example) {
            return InkWell(
              onTap: () {
                _textController.text = example;
                _parseText(example);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '"$example"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSplitSection(ThemeData theme) {
    if (_isLoadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_splitMembers.length < 2) {
      return const SizedBox.shrink();
    }

    final amount = _parsedExpense?.amount ?? 0.0;
    final currency = _parsedExpense?.currency ?? _trip?.currency ?? 'PHP';

    return ExpenseSplitSelector(
      members: _splitMembers,
      totalAmount: amount,
      currency: currency,
      paidByUserId: _tripService.currentUserId,
      initialData: _splitData,
      onChanged: (data) {
        setState(() {
          _splitData = data;
        });
      },
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    final canSave = _parsedExpense != null && _parsedExpense!.hasValidAmount;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: canSave && !_isSaving ? _quickSave : null,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check),
        label: Text(_isSaving ? 'Saving...' : 'Add Expense'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }
}
