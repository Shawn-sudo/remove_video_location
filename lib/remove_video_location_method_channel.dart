import 'package:flutter/services.dart';

import 'remove_video_location_platform_interface.dart';
import 'src/video_metadata_field.dart';

/// An implementation of [RemoveVideoLocationPlatform] that communicates with the
/// host platform over a method channel.
class MethodChannelRemoveVideoLocation extends RemoveVideoLocationPlatform {
  MethodChannelRemoveVideoLocation({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('remove_video_location');

  final MethodChannel _channel;

  @override
  Future<String> removeMetadata({
    required String inputPath,
    required String outputPath,
    required Set<VideoMetadataField> fields,
  }) async {
    final payload = <String, dynamic>{
      'inputPath': inputPath,
      'outputPath': outputPath,
      'fields': fields.map((field) => field.wireValue).toList(),
    };

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'removeMetadata',
      payload,
    );

    final resolvedPath = result?['outputPath'] as String?;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      throw PlatformException(
        code: 'metadata_removal_failed',
        message: 'The platform implementation did not return an output path.',
        details: result,
      );
    }

    return resolvedPath;
  }
}
