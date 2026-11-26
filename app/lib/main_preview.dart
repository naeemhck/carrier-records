import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/carrier_records_app.dart';
import 'app/language_mode.dart';
import 'preview/preview_backend.dart';

/// Design preview: the real app shell and screens over synthetic records,
/// with no Supabase project, credentials or writes.
///
///     flutter run -d web-server -t lib/main_preview.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageModeStore.instance.load();
  runApp(ProviderScope(child: CarrierRecordsApp(session: PreviewSession())));
}
