/// The metadata fields that can be removed from a video file.
enum VideoMetadataField {
  /// Geographic location stored alongside the video (ISO 6709 coordinates).
  location,

  /// Creation timestamp stored in the container metadata.
  creationTimestamp,
}

extension VideoMetadataFieldWireValue on VideoMetadataField {
  /// String identifier passed across the platform channel.
  String get wireValue {
    switch (this) {
      case VideoMetadataField.location:
        return 'location';
      case VideoMetadataField.creationTimestamp:
        return 'creationTimestamp';
    }
  }

  /// Converts a wire value received from the host platform back into an enum.
  static VideoMetadataField fromWireValue(String value) {
    switch (value) {
      case 'location':
        return VideoMetadataField.location;
      case 'creationTimestamp':
        return VideoMetadataField.creationTimestamp;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported metadata field.',
        );
    }
  }
}
