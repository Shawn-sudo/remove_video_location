import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'remove_video_metadata_method_channel.dart';
import 'src/video_metadata_field.dart';

/// Platform interface for the remove_video_metadata plugin.
abstract class RemoveVideoMetadataPlatform extends PlatformInterface {
  RemoveVideoMetadataPlatform() : super(token: _token);

  static final Object _token = Object();

  static RemoveVideoMetadataPlatform _instance =
      MethodChannelRemoveVideoMetadata();

  /// The default instance of [RemoveVideoMetadataPlatform] to use.
  static RemoveVideoMetadataPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RemoveVideoMetadataPlatform] when
  /// they register themselves.
  static set instance(RemoveVideoMetadataPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Removes metadata for the provided [fields] from the source video found at
  /// [inputPath], writing the resulting video to [outputPath]. The returned
  /// string should resolve to the final output path on disk.
  Future<String> removeMetadata({
    required String inputPath,
    required String outputPath,
    required Set<VideoMetadataField> fields,
  });
}
