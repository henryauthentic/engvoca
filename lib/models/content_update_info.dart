enum UpdateUXType { none, patch, minor, major }
enum ContentSyncStatus { idle, success, failed, latest }

class ContentUpdateInfo {
  final bool hasUpdate;
  final UpdateUXType uxType;
  final String title;
  final bool requiresSchemaMigration;
  final int deltaWords;
  final int deltaTopics;

  ContentUpdateInfo({
    required this.hasUpdate,
    this.uxType = UpdateUXType.none,
    this.title = '',
    this.requiresSchemaMigration = false,
    this.deltaWords = 0,
    this.deltaTopics = 0,
  });
}
