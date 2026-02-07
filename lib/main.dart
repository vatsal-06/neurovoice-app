import 'package:neurovoice_app/features/voice_check/voice_check_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('voice_results');
  await Hive.openBox('facial_results');
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => VoiceCheckViewModel())],
      child: const NeuroVoiceApp(),
    ),
  );
}
