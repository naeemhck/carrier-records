import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'output_export_service.dart';

abstract interface class OutputDestination {
  Future<bool> save(Uint8List bytes, String format, String name);
  Future<bool> print(Uint8List bytes, String name);
}

class NativeOutputDestination implements OutputDestination {
  @override
  Future<bool> save(Uint8List bytes, String format, String name) async {
    final mime = format == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (format == 'pdf') {
        return Printing.sharePdf(bytes: bytes, filename: name);
      }
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime, name: name)],
          fileNameOverrides: [name],
        ),
      );
      return result.status == ShareResultStatus.success;
    }
    final target = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(label: format.toUpperCase(), extensions: [format]),
      ],
    );
    if (target == null) {
      return false;
    }
    await XFile.fromData(bytes, mimeType: mime, name: name).saveTo(target.path);
    return true;
  }

  @override
  Future<bool> print(Uint8List bytes, String name) => Printing.layoutPdf(
    onLayout: (_) => bytes,
    name: name,
    dynamicLayout: false,
  );
}

class OutputFileActions extends StatefulWidget {
  const OutputFileActions({
    super.key,
    required this.service,
    required this.load,
    this.destination,
  });
  final OutputExportService service;
  final Future<Map<String, dynamic>> Function() load;
  final OutputDestination? destination;
  @override
  State<OutputFileActions> createState() => _OutputFileActionsState();
}

class _OutputFileActionsState extends State<OutputFileActions> {
  bool busy = false;
  String? status;
  Future<void> run(String operation) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final payload = await widget.load();
      final format = operation == 'print' ? 'pdf' : operation;
      final bytes = await widget.service.generate(payload, format);
      if (!mounted) {
        return;
      }
      final identity = payload['issued'] == true
          ? payload['metadata']['document_number'] as String
          : payload['report_kind'] as String;
      final name =
          '${identity.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.$format';
      final destination = widget.destination ?? NativeOutputDestination();
      final done = operation == 'print'
          ? await destination.print(bytes, name)
          : await destination.save(bytes, format, name);
      if (mounted) {
        setState(
          () => status = done
              ? operation == 'print'
                    ? 'Print job submitted. Check printer status.'
                    : defaultTargetPlatform == TargetPlatform.android
                    ? 'Share completed.'
                    : 'File saved.'
              : 'Save/share/print cancelled or not confirmed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Unable to export or print. Current access and a complete authorized payload are required. Retry after checking the connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: busy ? null : () => run('pdf'),
            child: const Text('Save / share PDF'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => run('xlsx'),
            child: const Text('Save / share Excel'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => run('print'),
            child: const Text('Print'),
          ),
        ],
      ),
      if (busy) const LinearProgressIndicator(),
      if (status != null) Text(status!),
    ],
  );
}
