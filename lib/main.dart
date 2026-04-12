import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');
  
  // Initialize Settings Service
  await SettingsService.instance.init();
  print('✅ Settings Service initialized');
  
  // Initialize Notification Service
  await NotificationService.instance.initialize();
  print('✅ Notification Service initialized');
  
  // Initialize Date Formatting for Vietnamese Locale (fl_chart)
  await initializeDateFormatting('vi_VN', null);
  print('✅ Date Formatting initialized');
  
  runApp(const MyApp());
}