import AVFoundation

public class SwiftRemoveVideoMetadataPlugin: NSObject, FlutterPlugin {
  private let workQueue = DispatchQueue(label: "com.example.remove_video_metadata.work")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "remove_video_metadata",
      binaryMessenger: registrar.messenger()
    )
    let instance = SwiftRemoveVideoMetadataPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "removeMetadata" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let inputPath = arguments["inputPath"] as? String,
      let outputPath = arguments["outputPath"] as? String
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Both inputPath and outputPath are required.",
        details: nil
      ))
      return
    }

    let fieldStrings = (arguments["fields"] as? [String]) ?? []

    workQueue.async {
      do {
        try self.removeMetadata(
          inputPath: inputPath,
          outputPath: outputPath,
          fields: Set(fieldStrings)
        )
        DispatchQueue.main.async {
          result(["outputPath": outputPath])
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "metadata_removal_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func removeMetadata(
    inputPath: String,
    outputPath: String,
    fields: Set<String>
  ) throws {
    let fileManager = FileManager.default
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)

    guard fileManager.fileExists(atPath: inputURL.path) else {
      throw MetadataError.inputMissing
    }

    if fileManager.fileExists(atPath: outputURL.path) {
      try fileManager.removeItem(at: outputURL)
    }
    try fileManager.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )

    let asset = AVURLAsset(url: inputURL, options: [
      AVURLAssetPreferPreciseDurationAndTimingKey: true
    ])

    guard asset.isExportable else {
      throw MetadataError.assetNotExportable
    }

    guard let exportSession = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      throw MetadataError.exportUnavailable
    }

    exportSession.outputURL = outputURL
    guard let outputType = exportSession.supportedFileTypes.first else {
      throw MetadataError.unsupportedFileType
    }
    exportSession.outputFileType = outputType
    exportSession.shouldOptimizeForNetworkUse = true

    let identifiersToRemove = identifiers(for: fields)
    exportSession.metadata = filteredMetadata(
      from: asset,
      removing: identifiersToRemove
    )

    let semaphore = DispatchSemaphore(value: 0)
    var exportError: Error?

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        break
      case .failed, .cancelled:
        exportError = exportSession.error
      default:
        break
      }
      semaphore.signal()
    }

    semaphore.wait()

    if let error = exportError {
      throw error
    }

    guard exportSession.status == .completed else {
      throw MetadataError.exportFailed
    }
  }

  private func filteredMetadata(
    from asset: AVAsset,
    removing identifiers: Set<AVMetadataIdentifier>
  ) -> [AVMetadataItem] {
    var retained: [AVMetadataItem] = []

    for item in asset.metadata {
      guard let identifier = item.identifier else {
        retained.append(item)
        continue
      }

      if !identifiers.contains(identifier) {
        retained.append(item)
      }
    }

    let formats = asset.availableMetadataFormats
    for format in formats {
      let items = asset.metadata(forFormat: format)
      for item in items {
        guard let identifier = item.identifier else {
          retained.append(item)
          continue
        }

        if !identifiers.contains(identifier) {
          retained.append(item)
        }
      }
    }

    return retained
  }

  private func identifiers(for fields: Set<String>) -> Set<AVMetadataIdentifier> {
    var identifiers: Set<AVMetadataIdentifier> = []

    for field in fields {
      switch field {
      case MetadataField.location.rawValue:
        identifiers.formUnion([
          .commonIdentifierLocation,
          .quickTimeMetadataLocationISO6709,
          .quickTimeUserDataLocationISO6709,
        ])
      case MetadataField.creationTimestamp.rawValue:
        identifiers.formUnion([
          .commonIdentifierCreationDate,
          .quickTimeMetadataCreationDate,
          .quickTimeUserDataCreationDate,
        ])
      default:
        continue
      }
    }

    return identifiers
  }

  private enum MetadataField: String {
    case location
    case creationTimestamp
  }

  private enum MetadataError: LocalizedError {
    case inputMissing
    case assetNotExportable
    case exportUnavailable
    case unsupportedFileType
    case exportFailed

    var errorDescription: String? {
      switch self {
      case .inputMissing:
        return "The input video could not be found."
      case .assetNotExportable:
        return "The provided asset cannot be exported in pass-through mode."
      case .exportUnavailable:
        return "Failed to initialise the export session."
      case .unsupportedFileType:
        return "No compatible output file type is available for export."
      case .exportFailed:
        return "The export session finished without producing a valid file."
      }
    }
  }
}
