import 'package:flutter/material.dart';

/// Provider quản lý state của luồng Onboarding 4 bước
class OnboardingProvider extends ChangeNotifier {
  // === State ===
  String _learningLevel = '';           // beginner, intermediate, advanced
  final List<String> _selectedTopics = [];  // Topic IDs
  int _dailyGoal = 15;                 // 10, 15, or 30 minutes

  // === Getters ===
  String get learningLevel => _learningLevel;
  List<String> get selectedTopics => List.unmodifiable(_selectedTopics);
  int get dailyGoal => _dailyGoal;

  bool get isLevelSelected => _learningLevel.isNotEmpty;
  bool get hasTopicsSelected => _selectedTopics.isNotEmpty;

  // === Actions ===
  void setLevel(String value) {
    _learningLevel = value;
    notifyListeners();
  }

  void toggleTopic(String topicId) {
    if (_selectedTopics.contains(topicId)) {
      _selectedTopics.remove(topicId);
    } else {
      _selectedTopics.add(topicId);
    }
    notifyListeners();
  }

  void setDailyGoal(int minutes) {
    _dailyGoal = minutes;
    notifyListeners();
  }

  void reset() {
    _learningLevel = '';
    _selectedTopics.clear();
    _dailyGoal = 15;
    notifyListeners();
  }
}
