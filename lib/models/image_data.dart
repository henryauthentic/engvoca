class ImageData {
  final String imageUrl;
  final String authorName;
  final String authorProfile;

  ImageData({
    required this.imageUrl,
    required this.authorName,
    required this.authorProfile,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      imageUrl: json['urls']?['small'] ?? '',
      authorName: json['user']?['name'] ?? 'Unknown Author',
      authorProfile: json['user']?['links']?['html'] ?? 'https://unsplash.com',
    );
  }
}
