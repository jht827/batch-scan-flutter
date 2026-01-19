import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const BatchScanApp());
}

enum ScanStep {
  scanId,
  scanPostCode,
}

enum FirstScanFormat {
  qrCode,
  code39,
}

class ScanRow {
  const ScanRow({required this.o1, required this.l1, this.s1 = 1});

  final String o1;
  final String l1;
  final int s1;
}

class BatchScanApp extends StatelessWidget {
  const BatchScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batch Scan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BatchScanScreen(),
    );
  }
}

class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({super.key});

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen> {
  final MobileScannerController _scannerController =
      MobileScannerController(autoStart: true);

  ScanStep _step = ScanStep.scanId;
  FirstScanFormat _firstScanFormat = FirstScanFormat.qrCode;
  String? _currentId;
  final List<ScanRow> _rows = [];

  DateTime? _lastScanTime;
  String? _lastScanValue;
  bool _flashVisible = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerFlash() {
    setState(() {
      _flashVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _flashVisible = false;
      });
    });
  }

  void _handleDetection(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.firstWhere(
      (barcode) => barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty,
      orElse: () => capture.barcodes.first,
    );
    final rawValue = barcode.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastScanValue == rawValue &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 800) {
      return;
    }
    _lastScanValue = rawValue;
    _lastScanTime = now;

    final format = barcode.format;
    if (_step == ScanStep.scanId) {
      final expectedFormat = _firstScanFormat == FirstScanFormat.qrCode
          ? BarcodeFormat.qrCode
          : BarcodeFormat.code39;
      if (format != expectedFormat) {
        final formatLabel =
            _firstScanFormat == FirstScanFormat.qrCode ? 'QR code' : 'Code 39';
        _showMessage('Expected $formatLabel for ID.');
        return;
      }
      _triggerFlash();
      setState(() {
        _currentId = rawValue;
        _step = ScanStep.scanPostCode;
      });
    } else {
      if (format != BarcodeFormat.code128) {
        _showMessage('Expected Code128 for post code.');
        return;
      }
      _triggerFlash();
      setState(() {
        _rows.add(ScanRow(o1: _currentId ?? '', l1: rawValue));
        _currentId = null;
        _step = ScanStep.scanId;
      });
    }
  }

  void _cancelCurrent() {
    setState(() {
      _currentId = null;
      _step = ScanStep.scanId;
    });
    _showMessage('Current scan cleared.');
  }

  void _undoLastRow() {
    if (_rows.isEmpty) {
      _showMessage('No rows to undo.');
      return;
    }
    setState(() {
      _rows.removeLast();
    });
    _showMessage('Last row removed.');
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needsQuotes) {
      return value;
    }
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildCsv() {
    final buffer = StringBuffer('o1,l1,s1\n');
    for (final row in _rows) {
      buffer
        ..write(_escapeCsv(row.o1))
        ..write(',')
        ..write(_escapeCsv(row.l1))
        ..write(',')
        ..write(row.s1)
        ..write('\n');
    }
    return buffer.toString();
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) {
      _showMessage('No rows to export.');
      return;
    }
    final csv = _buildCsv();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now();
    final formatted =
        '${timestamp.year.toString().padLeft(4, '0')}'
        '${timestamp.month.toString().padLeft(2, '0')}'
        '${timestamp.day.toString().padLeft(2, '0')}_'
        '${timestamp.hour.toString().padLeft(2, '0')}'
        '${timestamp.minute.toString().padLeft(2, '0')}'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final file = File('${directory.path}/scan_export_$formatted.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Scan export',
    );

    _showMessage('CSV saved to ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _step == ScanStep.scanId
        ? 'Step 1/2: Scan ID ${_firstScanFormat == FirstScanFormat.qrCode ? 'QR' : 'Code 39'}'
        : 'Step 2/2: Scan Post Code128';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Scan'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 5,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleDetection,
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      IgnorePointer(
                        ignoring: _step == ScanStep.scanPostCode,
                        child: Opacity(
                          opacity: _step == ScanStep.scanPostCode ? 0.5 : 1,
                          child: SegmentedButton<FirstScanFormat>(
                            segments: const [
                              ButtonSegment(
                                value: FirstScanFormat.qrCode,
                                label: Text('QR'),
                              ),
                              ButtonSegment(
                                value: FirstScanFormat.code39,
                                label: Text('Code 39'),
                              ),
                            ],
                            selected: <FirstScanFormat>{_firstScanFormat},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _firstScanFormat = selection.first;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_step == ScanStep.scanPostCode && _currentId != null)
                        Text(
                          'Captured ID: ${_currentId!}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      const SizedBox(height: 8),
                      Text('Rows captured: ${_rows.length}'),
                      const Spacer(),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton(
                            onPressed: _cancelCurrent,
                            child: const Text('Cancel current'),
                          ),
                          ElevatedButton(
                            onPressed: _undoLastRow,
                            child: const Text('Undo last row'),
                          ),
                          FilledButton(
                            onPressed: _exportCsv,
                            child: const Text('Export CSV'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flashVisible ? 0.35 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Container(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
