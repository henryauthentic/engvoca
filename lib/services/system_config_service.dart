import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemConfigService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _featureFlags = {};
  List<Map<String, dynamic>> _activeAnnouncements = [];
  // Track dismissed announcement IDs for popup/bottom_sheet so they show only once per session
  final Set<String> _sessionDismissed = {};

  Map<String, dynamic> get featureFlags => _featureFlags;
  List<Map<String, dynamic>> get activeAnnouncements => _activeAnnouncements;

  SystemConfigService() {
    _initListeners();
  }

  void _initListeners() {
    // 1. Lắng nghe Feature Flags
    _db.collection('config').doc('featureFlags').snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _featureFlags = snapshot.data()!['flags'] ?? {};
        notifyListeners();
      }
    });

    // 2. Lắng nghe Announcements
    _db.collection('announcements')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      
      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final prefs = await SharedPreferences.getInstance();

      final allAnn = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((ann) {
        // Date filtering
        final startDate = ann['startDate'] as String?;
        final endDate = ann['endDate'] as String?;
        if (startDate != null && startDate.compareTo(todayStr) > 0) return false;
        if (endDate != null && endDate.compareTo(todayStr) < 0) return false;

        // Platform targeting
        final targetPlatform = ann['targetPlatform'] as String? ?? 'all';
        if (targetPlatform != 'all') {
          if (targetPlatform == 'android' && !Platform.isAndroid) return false;
          if (targetPlatform == 'ios' && !Platform.isIOS) return false;
        }

        // showOnlyOnce check
        final showOnlyOnce = ann['showOnlyOnce'] == true;
        if (showOnlyOnce) {
          final dismissedKey = 'dismissed_ann_${ann['id']}';
          if (prefs.getBool(dismissedKey) == true) return false;
        }

        // Cooldown check
        final cooldownHours = (ann['cooldownHours'] as num?)?.toInt() ?? 0;
        if (cooldownHours > 0) {
          final lastDismissKey = 'dismiss_time_${ann['id']}';
          final lastDismiss = prefs.getInt(lastDismissKey) ?? 0;
          if (lastDismiss > 0) {
            final elapsed = today.millisecondsSinceEpoch - lastDismiss;
            if (elapsed < cooldownHours * 3600 * 1000) return false;
          }
        }

        return true;
      }).toList();

      // Sort by priority
      allAnn.sort((a, b) {
        final pA = (a['priority'] as num?)?.toInt() ?? 0;
        final pB = (b['priority'] as num?)?.toInt() ?? 0;
        return pA.compareTo(pB);
      });

      _activeAnnouncements = allAnn;
      notifyListeners();
    });
  }

  /// Dismiss an announcement (save to SharedPreferences)
  Future<void> dismissAnnouncement(String announcementId) async {
    _sessionDismissed.add(announcementId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_ann_$announcementId', true);
    await prefs.setInt('dismiss_time_$announcementId', DateTime.now().millisecondsSinceEpoch);
    // Remove from active list
    _activeAnnouncements.removeWhere((a) => a['id'] == announcementId);
    notifyListeners();
  }

  /// Check if an announcement was dismissed this session (for popup/sheet)
  bool isDismissedThisSession(String announcementId) {
    return _sessionDismissed.contains(announcementId);
  }

  /// Kiểm tra xem một cờ tính năng có được bật không
  bool isFeatureEnabled(String flagKey, {bool defaultValue = false}) {
    if (_featureFlags.containsKey(flagKey)) {
      return _featureFlags[flagKey] == true;
    }
    return defaultValue;
  }
}
