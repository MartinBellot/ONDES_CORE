class MiniApp {
  final int? dbId; // Internal DB ID needed for API calls
  final String id;
  final String name;
  final String version;
  final String description;
  final String iconUrl;
  final String downloadUrl;
  bool isInstalled;
  String? localPath;

  MiniApp({
    this.dbId,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.iconUrl,
    required this.downloadUrl,
    this.isInstalled = false,
    this.localPath,
  });

  factory MiniApp.fromJson(Map<String, dynamic> json) {
    return MiniApp(
      dbId: json['id'], // Integer ID from Django
      id: json['bundle_id'], // Backend uses bundle_id
      name: json['name'],
      version: json['latest_version'] ?? "0.0.0",
      description: json['description'],
      iconUrl: json['icon'] ?? "", // Backend returns full URL or null
      downloadUrl: json['download_url'] ?? "",
    );

  }
}
