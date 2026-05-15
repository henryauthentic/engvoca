// ============================================
// FILE: lib/db/database_helper.dart
// Conditional Export: Tự động chọn đúng adapter theo platform
// Mobile → SQLite (database_helper_mobile.dart)
// Web   → Firestore (database_helper_web.dart)
// ============================================

export 'database_helper_mobile.dart'
    if (dart.library.html) 'database_helper_web.dart';