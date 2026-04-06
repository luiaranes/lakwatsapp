import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:larga/models/parsed_receipt.dart';
import 'package:larga/services/receipt_scanning_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class ScanReceiptScreen extends StatefulWidget {
  final String tripId;

  const ScanReceiptScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _receiptService = ReceiptScanningService();
  final _imagePicker = ImagePicker();

  File? _selectedImage;
  ParsedReceipt? _parsedReceipt;
  bool _isProcessing = false;
  String _processingStatus = '';

  @override
  void dispose() {
    _receiptService.dispose();
    super.dispose();
  }

  String _currencySymbol(String currency) {
    return switch (currency.toUpperCase()) {
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

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _parsedReceipt = null;
        });
        await _processReceipt();
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to capture image');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _parsedReceipt = null;
        });
        await _processReceipt();
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to pick image');
    }
  }

  Future<void> _processReceipt() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Extracting text from receipt...';
    });

    try {
      setState(() {
        _processingStatus = 'Uploading receipt image...';
      });

      final result = await _receiptService.scanReceipt(
        imageFile: _selectedImage!,
        tripId: widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _parsedReceipt = result;
        _isProcessing = false;
        _processingStatus = '';
      });

      if (result.confidence < 0.5) {
        SnackBarUtils.showInfo(
          context,
          'Low confidence scan. Please verify the details.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _processingStatus = '';
      });
      SnackBarUtils.showError(context, 'Failed to process receipt: $e');
    }
  }

  void _confirmAndReturn() {
    if (_parsedReceipt == null) return;
    Navigator.of(context).pop(_parsedReceipt);
  }

  void _retake() {
    setState(() {
      _selectedImage = null;
      _parsedReceipt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        actions: [
          if (_parsedReceipt != null)
            TextButton(
              onPressed: _confirmAndReturn,
              child: const Text('Use'),
            ),
        ],
      ),
      body: _selectedImage == null
          ? _buildCaptureView(theme)
          : _buildPreviewView(theme),
    );
  }

  Widget _buildCaptureView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Scan Your Receipt',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo or choose from gallery.\nWe\'ll extract the details automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _captureImage,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take Photo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                if (_isProcessing) _buildProcessingIndicator(theme),
                if (_parsedReceipt != null) _buildExtractedData(theme),
              ],
            ),
          ),
        ),
        _buildBottomActions(theme),
      ],
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _processingStatus,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedData(ThemeData theme) {
    final receipt = _parsedReceipt!;
    final confidence = receipt.confidence;
    final confidenceColor = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.5
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
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
                'Extracted Data',
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
                  '${(confidence * 100).toInt()}% confidence',
                  style: TextStyle(
                    fontSize: 12,
                    color: confidenceColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildDataRow(
            theme,
            icon: Icons.store_outlined,
            label: 'Merchant',
            value: receipt.merchant ?? 'Not detected',
            isDetected: receipt.hasValidMerchant,
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            theme,
            icon: Icons.payments_outlined,
            label: 'Amount',
            value: receipt.hasValidAmount
                ? receipt.displayAmount
                : 'Not detected',
            isDetected: receipt.hasValidAmount,
            isHighlighted: true,
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            theme,
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: receipt.hasValidDate
                ? DateFormat('MMM d, yyyy').format(receipt.date!)
                : 'Not detected',
            isDetected: receipt.hasValidDate,
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            theme,
            icon: Icons.category_outlined,
            label: 'Category',
            value: receipt.suggestedCategory?.displayName ?? 'Not detected',
            isDetected: receipt.suggestedCategory != null,
            emoji: receipt.suggestedCategory?.icon,
          ),
          if (receipt.lineItems != null && receipt.lineItems!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'Line Items',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...receipt.lineItems!.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.price != null)
                        Text(
                          '${_currencySymbol(receipt.currency ?? 'PHP')}${item.price!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                )),
            if (receipt.lineItems!.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${receipt.lineItems!.length - 5} more items',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(
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
                          fontStyle:
                              isDetected ? null : FontStyle.italic,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _retake,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isProcessing || _parsedReceipt == null
                  ? null
                  : _confirmAndReturn,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isProcessing ? 'Processing...' : 'Use This Data'),
            ),
          ),
        ],
      ),
    );
  }
}
