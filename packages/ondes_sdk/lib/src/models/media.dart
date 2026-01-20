/// Media attached to a post.
class PostMedia {
  /// Unique media identifier.
  final String uuid;

  /// Type of media (image, video).
  final String mediaType;

  /// Display URL for the media.
  final String displayUrl;

  /// Thumbnail URL (for videos).
  final String? thumbnailUrl;

  /// HLS streaming URL (for videos).
  final String? hlsUrl;

  /// Width in pixels.
  final int? width;

  /// Height in pixels.
  final int? height;

  /// Duration in seconds (for videos).
  final double? duration;

  /// Processing status.
  final String? processingStatus;

  /// Whether HLS is ready for streaming.
  final bool hlsReady;

  /// Order in the post's media list.
  final int order;

  const PostMedia({
    required this.uuid,
    required this.mediaType,
    required this.displayUrl,
    this.thumbnailUrl,
    this.hlsUrl,
    this.width,
    this.height,
    this.duration,
    this.processingStatus,
    this.hlsReady = false,
    this.order = 0,
  });

  /// Whether this is an image.
  bool get isImage => mediaType == 'image';

  /// Whether this is a video.
  bool get isVideo => mediaType == 'video';

  /// Create from JSON map.
  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      uuid: json['uuid'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image',
      displayUrl: json['display_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      hlsUrl: json['hls_url'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
      processingStatus: json['processing_status'] as String?,
      hlsReady: json['hls_ready'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'media_type': mediaType,
      'display_url': displayUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (hlsUrl != null) 'hls_url': hlsUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (processingStatus != null) 'processing_status': processingStatus,
      'hls_ready': hlsReady,
      'order': order,
    };
  }

  @override
  String toString() => 'PostMedia($mediaType, $uuid)';
}

/// Media item returned from the media picker.
class PickedMedia {
  /// Local file path.
  final String path;

  /// Type of media (image, video).
  final String type;

  /// File name.
  final String name;

  /// Base64 preview URL for images.
  final String? previewUrl;

  const PickedMedia({
    required this.path,
    required this.type,
    required this.name,
    this.previewUrl,
  });

  /// Whether this is an image.
  bool get isImage => type == 'image';

  /// Whether this is a video.
  bool get isVideo => type == 'video';

  /// Create from JSON map.
  factory PickedMedia.fromJson(Map<String, dynamic> json) {
    return PickedMedia(
      path: json['path'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      name: json['name'] as String? ?? '',
      previewUrl: json['previewUrl'] as String?,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type,
      'name': name,
      if (previewUrl != null) 'previewUrl': previewUrl,
    };
  }

  @override
  String toString() => 'PickedMedia($type, $name)';
}
