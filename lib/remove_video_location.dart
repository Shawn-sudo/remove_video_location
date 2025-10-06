import 'dart:io';

import 'package:path/path.dart' as p;

import 'remove_video_location_platform_interface.dart';
import 'src/video_metadata_field.dart';

export 'src/video_metadata_field.dart';
export 'remove_video_location_platform_interface.dart'
    show RemoveVideoLocationPlatform;

/// Facade for removing selected metadata from video files.
class RemoveVideoLocation {
  RemoveVideoLocation._();

  /// Singleton instance for convenience.
  static final RemoveVideoLocation instance = RemoveVideoLocation._();

  /// Removes the requested [fields] from the video located at [inputPath].
  ///
  /// [outputPath] can be supplied to control the destination path. When null a
  /// sibling file is created next to [inputPath] with the suffix `_clean`.
  ///
  /// By default the method will not overwrite existing files. Provide
  /// [overwrite] to remove any stale destination file prior to processing.
  ///
  /// Returns the file path of the cleaned video.
  Future<String> removeMetadata({
    required String inputPath,
    String? outputPath,
    Set<VideoMetadataField> fields = const {VideoMetadataField.location},
    bool overwrite = false,
  }) async {
    if (inputPath.isEmpty) {
      throw ArgumentError('inputPath cannot be empty');
    }
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw ArgumentError('inputPath does not point to an existing file.');
    }

    final resolvedFields = fields.isEmpty
        ? const {VideoMetadataField.location}
        : fields;
    final resolvedOutputPath = _deriveOutputPath(
      inputFile: inputFile,
      explicitOutput: outputPath,
      overwrite: overwrite,
    );

    await RemoveVideoLocationPlatform.instance.removeMetadata(
      inputPath: inputFile.path,
      outputPath: resolvedOutputPath,
      fields: resolvedFields,
    );

    return resolvedOutputPath;
  }

  String _deriveOutputPath({
    required File inputFile,
    required bool overwrite,
    String? explicitOutput,
  }) {
    if (explicitOutput != null && explicitOutput.isNotEmpty) {
      final outputFile = File(explicitOutput);
      _prepareDestination(outputFile, overwrite: overwrite);
      return outputFile.path;
    }

    final directory = inputFile.parent.path;
    final baseName = p.basenameWithoutExtension(inputFile.path);
    final extension = p.extension(inputFile.path);
    var candidate = p.join(directory, '${baseName}_clean$extension');
    var counter = 1;

    while (File(candidate).existsSync()) {
      if (overwrite) {
        _prepareDestination(File(candidate), overwrite: true);
        break;
      }
      candidate = p.join(directory, '${baseName}_clean_$counter$extension');
      counter += 1;
    }

    if (!File(candidate).existsSync()) {
      _prepareDestination(File(candidate), overwrite: overwrite);
    }

    return candidate;
  }

  void _prepareDestination(File file, {required bool overwrite}) {
    if (file.existsSync()) {
      if (!overwrite) {
        throw StateError(
          'Destination file already exists: ${file.path}. Enable overwrite to replace it.',
        );
      }
      file.deleteSync();
    }
    file.parent.createSync(recursive: true);
  }
}
