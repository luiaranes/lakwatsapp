import 'package:flutter/material.dart';
import 'package:larga/models/trip.dart';
import 'package:larga/models/itinerary_item.dart';
import 'package:larga/models/parsed_itinerary.dart';
import 'package:larga/services/quick_add_itinerary_service.dart';
import 'package:larga/services/itinerary_service.dart';
import 'package:larga/utils/snackbar_utils.dart';
import 'package:larga/screens/add_edit_itinerary_item_screen.dart';
import 'package:larga/widgets/voice_input_button.dart';

class QuickAddItineraryScreen extends StatefulWidget {
  final String tripId;
  final int dayNumber;
  final Trip? trip;

  const QuickAddItineraryScreen({
    super.key,
    required this.tripId,
    required this.dayNumber,
    this.trip,
  });

  @override
  State<QuickAddItineraryScreen> createState() =>
      _QuickAddItineraryScreenState();
}

class _QuickAddItineraryScreenState extends State<QuickAddItineraryScreen> {
  final _quickAddService = QuickAddItineraryService();
  final _itineraryService = ItineraryService();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  ParsedItinerary? _parsedItinerary;

  bool _isParsing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _parseText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isParsing = true;
      _parsedItinerary = null;
    });

    try {
      final result = await _quickAddService.parseItineraryText(
        text: text,
        dayNumber: widget.dayNumber,
        tripCurrency: widget.trip?.currency ?? 'PHP',
        tripStartDate: widget.trip?.startDate?.toIso8601String(),
      );

      if (!mounted) return;

      setState(() {
        _parsedItinerary = result;
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
      SnackBarUtils.showError(context, 'Failed to parse activity');
    }
  }

  Future<void> _quickSave() async {
    if (_parsedItinerary == null || !_parsedItinerary!.hasValidTitle) {
      SnackBarUtils.showError(context, 'Please enter a valid activity');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final item = await _itineraryService.createItem(
        tripId: widget.tripId,
        dayNumber: widget.dayNumber,
        title: _parsedItinerary!.title!,
        description: _parsedItinerary!.description,
        startTime: _parsedItinerary!.startTime,
        endTime: _parsedItinerary!.endTime,
        location: _parsedItinerary!.location,
        category: _parsedItinerary!.suggestedCategory ?? ItineraryCategory.other,
        estimatedCost: _parsedItinerary!.estimatedCost,
        currency: _parsedItinerary!.currency,
        notes: _parsedItinerary!.notes,
      );

      if (!mounted) return;

      SnackBarUtils.showSuccess(context, 'Activity added!');
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(context, 'Failed to save activity');
    }
  }

  void _editBeforeSaving() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddEditItineraryItemScreen(
          tripId: widget.tripId,
          dayNumber: widget.dayNumber,
          trip: widget.trip,
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
        title: Text('Quick Add - Day ${widget.dayNumber}'),
        actions: [
          if (_parsedItinerary != null)
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
                    if (_parsedItinerary != null) _buildParsedResult(theme),
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
                  'Describe your activity',
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
              hintText: 'e.g., "9am flight to Boracay 3500 php"',
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
            'Understanding your activity...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedResult(ThemeData theme) {
    final itinerary = _parsedItinerary!;
    final confidence = itinerary.confidence;
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
                'Parsed Activity',
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
            icon: Icons.title_outlined,
            label: 'Title',
            value: itinerary.title ?? 'Not detected',
            isDetected: itinerary.hasValidTitle,
            isHighlighted: true,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            theme,
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: itinerary.hasValidTime
                ? _formatTime(itinerary.startTime!)
                : 'Not detected',
            isDetected: itinerary.hasValidTime,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            theme,
            icon: Icons.category_outlined,
            label: 'Category',
            value: itinerary.suggestedCategory?.displayName ?? 'Other',
            isDetected: itinerary.suggestedCategory != null,
            emoji: itinerary.suggestedCategory?.icon,
          ),
          if (itinerary.hasValidLocation) ...[
            const SizedBox(height: 12),
            _buildResultRow(
              theme,
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: itinerary.location!,
              isDetected: true,
            ),
          ],
          if (itinerary.hasValidCost) ...[
            const SizedBox(height: 12),
            _buildResultRow(
              theme,
              icon: Icons.payments_outlined,
              label: 'Est. Cost',
              value: itinerary.displayCost,
              isDetected: true,
            ),
          ],
          if (itinerary.description != null &&
              itinerary.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildResultRow(
              theme,
              icon: Icons.description_outlined,
              label: 'Details',
              value: itinerary.description!,
              isDetected: true,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
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
      '9am flight to Boracay 3500',
      'lunch at Manam 12:30 500 pesos',
      'afternoon island hopping 1500',
      'check in hotel 2pm',
      'sunset at Puka Beach',
      'free time to explore D\'mall',
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

  Widget _buildBottomActions(ThemeData theme) {
    final canSave = _parsedItinerary != null && _parsedItinerary!.hasValidTitle;

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
        label: Text(_isSaving ? 'Saving...' : 'Add Activity'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }
}
