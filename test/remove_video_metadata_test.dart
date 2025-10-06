import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:remove_video_metadata/remove_video_metadata.dart';
import 'package:remove_video_metadata/remove_video_metadata_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoveVideoMetadata', () {
    late Directory tempDir;
    late FakeRemoveVideoMetadataPlatform fakePlatform;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'remove_video_metadata_test',
      );
      fakePlatform = FakeRemoveVideoMetadataPlatform();
      RemoveVideoMetadataPlatform.instance = fakePlatform;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('delegates to the platform implementation', () async {
      final inputFile = File('${tempDir.path}/input.mp4')
        ..writeAsBytesSync(List<int>.generate(8, (i) => i));
      final outputFile = File('${tempDir.path}/output.mp4');

      final resultPath = await RemoveVideoMetadata.instance.removeMetadata(
        inputPath: inputFile.path,
        outputPath: outputFile.path,
        fields: const {
          VideoMetadataField.location,
          VideoMetadataField.creationTimestamp,
        },
        overwrite: true,
      );

      expect(resultPath, outputFile.path);
      expect(fakePlatform.lastInputPath, inputFile.path);
      expect(fakePlatform.lastOutputPath, outputFile.path);
      expect(
        fakePlatform.lastFields,
        equals(const {
          VideoMetadataField.location,
          VideoMetadataField.creationTimestamp,
        }),
      );
      expect(outputFile.existsSync(), isTrue);
    });

    test('uses a derived output path when none is provided', () async {
      final inputFile = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(List<int>.generate(8, (i) => i));
      final occupied = File('${tempDir.path}/clip_clean.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);

      final resultPath = await RemoveVideoMetadata.instance.removeMetadata(
        inputPath: inputFile.path,
        fields: const {VideoMetadataField.location},
      );

      expect(resultPath, isNot(equals(occupied.path)));
      expect(resultPath, endsWith('clip_clean_1.mp4'));
      expect(fakePlatform.lastOutputPath, resultPath);
      expect(File(resultPath).existsSync(), isTrue);
    });

    test('maps wire values correctly', () {
      for (final field in VideoMetadataField.values) {
        final roundTripped = VideoMetadataFieldWireValue.fromWireValue(
          field.wireValue,
        );
        expect(roundTripped, field);
      }
    });
  });
}

class FakeRemoveVideoMetadataPlatform extends RemoveVideoMetadataPlatform {
  String? lastInputPath;
  String? lastOutputPath;
  Set<VideoMetadataField>? lastFields;

  @override
  Future<String> removeMetadata({
    required String inputPath,
    required String outputPath,
    required Set<VideoMetadataField> fields,
  }) async {
    lastInputPath = inputPath;
    lastOutputPath = outputPath;
    lastFields = fields;

    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(const []);

    return outputPath;
  }
}
