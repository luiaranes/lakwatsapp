import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:larga/models/expense_split.dart';

class SplitMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  bool isSelected;
  double? amount;
  double? percentage;

  SplitMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.isSelected = false,
    this.amount,
    this.percentage,
  });
}

class ExpenseSplitData {
  final SplitType splitType;
  final List<String> memberIds;
  final Map<String, double>? percentages;
  final Map<String, double>? amounts;

  ExpenseSplitData({
    required this.splitType,
    required this.memberIds,
    this.percentages,
    this.amounts,
  });
}

class ExpenseSplitSelector extends StatefulWidget {
  final List<SplitMember> members;
  final double totalAmount;
  final String currency;
  final String? paidByUserId;
  final ExpenseSplitData? initialData;
  final ValueChanged<ExpenseSplitData?> onChanged;

  const ExpenseSplitSelector({
    super.key,
    required this.members,
    required this.totalAmount,
    required this.currency,
    this.paidByUserId,
    this.initialData,
    required this.onChanged,
  });

  @override
  State<ExpenseSplitSelector> createState() => _ExpenseSplitSelectorState();
}

class _ExpenseSplitSelectorState extends State<ExpenseSplitSelector> {
  bool _splitEnabled = false;
  SplitType _splitType = SplitType.equal;
  late List<SplitMember> _members;
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};

  @override
  void initState() {
    super.initState();
    _members = widget.members.map((m) => SplitMember(
      userId: m.userId,
      displayName: m.displayName,
      avatarUrl: m.avatarUrl,
      isCurrentUser: m.isCurrentUser,
      isSelected: false,
    )).toList();

    if (widget.initialData != null) {
      _splitEnabled = true;
      _splitType = widget.initialData!.splitType;
      for (final member in _members) {
        member.isSelected = widget.initialData!.memberIds.contains(member.userId);
        if (widget.initialData!.percentages != null) {
          member.percentage = widget.initialData!.percentages![member.userId];
        }
        if (widget.initialData!.amounts != null) {
          member.amount = widget.initialData!.amounts![member.userId];
        }
      }
    } else {
      // Enable split by default for all trips
      _splitEnabled = true;
      for (final member in _members) {
        member.isSelected = true;
      }
      _updateEqualSplitAmounts();
    }

    for (final member in _members) {
      _amountControllers[member.userId] = TextEditingController(
        text: member.amount?.toStringAsFixed(2) ?? '',
      );
      _percentageControllers[member.userId] = TextEditingController(
        text: member.percentage?.toStringAsFixed(1) ?? '',
      );
    }

    // Notify parent of initial split state after first frame
    if (widget.initialData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyChange();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExpenseSplitSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAmount != widget.totalAmount && _splitType == SplitType.equal) {
      _updateEqualSplitAmounts();
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateEqualSplitAmounts() {
    final selectedMembers = _members.where((m) => m.isSelected).toList();
    if (selectedMembers.isEmpty) return;

    final splitAmount = widget.totalAmount / selectedMembers.length;
    final percentage = 100.0 / selectedMembers.length;

    for (final member in selectedMembers) {
      member.amount = double.parse(splitAmount.toStringAsFixed(2));
      member.percentage = double.parse(percentage.toStringAsFixed(2));
    }

    for (final member in _members.where((m) => !m.isSelected)) {
      member.amount = null;
      member.percentage = null;
    }
  }

  void _notifyChange() {
    if (!_splitEnabled) {
      widget.onChanged(null);
      return;
    }

    final selectedIds = _members.where((m) => m.isSelected).map((m) => m.userId).toList();
    if (selectedIds.isEmpty) {
      widget.onChanged(null);
      return;
    }

    Map<String, double>? percentages;
    Map<String, double>? amounts;

    if (_splitType == SplitType.percentage) {
      percentages = {};
      for (final member in _members.where((m) => m.isSelected)) {
        percentages[member.userId] = member.percentage ?? 0;
      }
    } else if (_splitType == SplitType.exact) {
      amounts = {};
      for (final member in _members.where((m) => m.isSelected)) {
        amounts[member.userId] = member.amount ?? 0;
      }
    }

    widget.onChanged(ExpenseSplitData(
      splitType: _splitType,
      memberIds: selectedIds,
      percentages: percentages,
      amounts: amounts,
    ));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _members.where((m) => m.isSelected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(
            'Split this expense',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _splitEnabled ? 'Expense will be shared among selected members' : 'No splitting',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: _splitEnabled,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _splitEnabled = value;
              if (value) {
                for (final member in _members) {
                  member.isSelected = true;
                }
                _updateEqualSplitAmounts();
              }
            });
            _notifyChange();
          },
        ),
        if (_splitEnabled) ...[
          const SizedBox(height: 8),
          _buildSplitTypeSelector(),
          const SizedBox(height: 16),
          _buildMembersList(),
          const SizedBox(height: 8),
          _buildSummary(selectedCount),
        ],
      ],
    );
  }

  Widget _buildSplitTypeSelector() {
    return SegmentedButton<SplitType>(
      segments: const [
        ButtonSegment(
          value: SplitType.equal,
          label: Text('Equal'),
          icon: Icon(Icons.balance, size: 18),
        ),
        ButtonSegment(
          value: SplitType.percentage,
          label: Text('Percent'),
          icon: Icon(Icons.percent, size: 18),
        ),
        ButtonSegment(
          value: SplitType.exact,
          label: Text('Exact'),
          icon: Icon(Icons.pin, size: 18),
        ),
      ],
      selected: {_splitType},
      onSelectionChanged: (selection) {
        setState(() {
          _splitType = selection.first;
          if (_splitType == SplitType.equal) {
            _updateEqualSplitAmounts();
          } else if (_splitType == SplitType.percentage) {
            final selectedMembers = _members.where((m) => m.isSelected).toList();
            final equalPercentage = selectedMembers.isNotEmpty
                ? 100.0 / selectedMembers.length
                : 0.0;
            for (final member in selectedMembers) {
              member.percentage = double.parse(equalPercentage.toStringAsFixed(1));
              _percentageControllers[member.userId]?.text =
                  member.percentage!.toStringAsFixed(1);
            }
          } else if (_splitType == SplitType.exact) {
            final selectedMembers = _members.where((m) => m.isSelected).toList();
            final equalAmount = selectedMembers.isNotEmpty
                ? widget.totalAmount / selectedMembers.length
                : 0.0;
            for (final member in selectedMembers) {
              member.amount = double.parse(equalAmount.toStringAsFixed(2));
              _amountControllers[member.userId]?.text =
                  member.amount!.toStringAsFixed(2);
            }
          }
        });
        _notifyChange();
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildMembersList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _members.asMap().entries.map((entry) {
          final index = entry.key;
          final member = entry.value;
          final isLast = index == _members.length - 1;
          final isPayer = member.userId == widget.paidByUserId;

          return Column(
            children: [
              _buildMemberTile(member, isPayer),
              if (!isLast) Divider(height: 1, indent: 56, color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberTile(SplitMember member, bool isPayer) {
    final theme = Theme.of(context);
    final symbol = _getCurrencySymbol(widget.currency);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: member.isSelected,
            onChanged: (value) {
              setState(() {
                member.isSelected = value ?? false;
                if (_splitType == SplitType.equal) {
                  _updateEqualSplitAmounts();
                }
              });
              _notifyChange();
            },
          ),
          CircleAvatar(
            radius: 18,
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            backgroundColor: isPayer ? theme.colorScheme.primaryContainer : Colors.grey[300],
            child: member.avatarUrl == null
                ? Text(
                    _getInitials(member.displayName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPayer ? theme.colorScheme.primary : Colors.grey[700],
                    ),
                  )
                : null,
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.isCurrentUser ? '${member.displayName} (You)' : member.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: member.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isPayer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Paid',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: member.isSelected ? _buildSplitInput(member, symbol) : null,
    );
  }

  Widget _buildSplitInput(SplitMember member, String symbol) {
    if (_splitType == SplitType.equal) {
      final selectedCount = _members.where((m) => m.isSelected).length;
      final amount = selectedCount > 0 ? widget.totalAmount / selectedCount : 0.0;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$symbol${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_splitType == SplitType.percentage) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 100,
          child: TextField(
            controller: _percentageControllers[member.userId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
              suffixText: '%',
              hintText: '0',
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) {
              setState(() {
                member.percentage = double.tryParse(value) ?? 0;
                member.amount = widget.totalAmount * (member.percentage! / 100);
              });
              _notifyChange();
            },
          ),
        ),
      );
    }

    if (_splitType == SplitType.exact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 120,
          child: TextField(
            controller: _amountControllers[member.userId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
              prefixText: symbol,
              hintText: '0.00',
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) {
              setState(() {
                member.amount = double.tryParse(value) ?? 0;
                if (widget.totalAmount > 0) {
                  member.percentage = (member.amount! / widget.totalAmount) * 100;
                }
              });
              _notifyChange();
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSummary(int selectedCount) {
    final symbol = _getCurrencySymbol(widget.currency);

    double totalAssigned = 0;
    double totalPercentage = 0;

    for (final member in _members.where((m) => m.isSelected)) {
      if (_splitType == SplitType.equal) {
        totalAssigned = widget.totalAmount;
        totalPercentage = 100;
        break;
      } else if (_splitType == SplitType.percentage) {
        totalPercentage += member.percentage ?? 0;
        totalAssigned += (member.percentage ?? 0) / 100 * widget.totalAmount;
      } else if (_splitType == SplitType.exact) {
        totalAssigned += member.amount ?? 0;
        totalPercentage += ((member.amount ?? 0) / widget.totalAmount) * 100;
      }
    }

    final isBalanced = (totalAssigned - widget.totalAmount).abs() < 0.01;
    final remaining = widget.totalAmount - totalAssigned;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green.withAlpha(25) : Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBalanced ? Colors.green.withAlpha(51) : Colors.orange.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 20,
            color: isBalanced ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBalanced
                      ? 'Split balanced'
                      : remaining > 0
                          ? '$symbol${remaining.toStringAsFixed(2)} remaining'
                          : '$symbol${(-remaining).toStringAsFixed(2)} over budget',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isBalanced ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                Text(
                  '$selectedCount ${selectedCount == 1 ? 'member' : 'members'} • ${totalPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$symbol${totalAssigned.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isBalanced ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
