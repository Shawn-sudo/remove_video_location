package com.example.remove_video_location

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

class RemoveVideoLocationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != METHOD_REMOVE_METADATA) {
      result.notImplemented()
      return
    }

    val inputPath = call.argument<String>("inputPath")
    val outputPath = call.argument<String>("outputPath")
    val fieldList = call.argument<List<String>>("fields") ?: emptyList()

    if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
      result.error(
        "invalid_arguments",
        "Both inputPath and outputPath are required.",
        null,
      )
      return
    }

    val fields = fieldList.toSet()

    executor.execute {
      try {
        removeMetadata(inputPath, outputPath, fields)
        mainHandler.post {
          result.success(mapOf("outputPath" to outputPath))
        }
      } catch (throwable: Throwable) {
        val message = throwable.message ?: "Failed to remove metadata."
        mainHandler.post {
          result.error("metadata_removal_failed", message, null)
        }
      }
    }
  }

  @Throws(Exception::class)
  private fun removeMetadata(
    inputPath: String,
    outputPath: String,
    fields: Set<String>,
  ) {
    val inputFile = File(inputPath)
    require(inputFile.exists()) { "Input video does not exist at $inputPath" }

    val outputFile = File(outputPath)
    if (outputFile.exists()) {
      outputFile.delete()
    }
    outputFile.parentFile?.mkdirs()

    val extractor = MediaExtractor()
    val retriever = MediaMetadataRetriever()
    var muxer: MediaMuxer? = null
    var muxerStarted = false

    try {
      extractor.setDataSource(inputPath)
      retriever.setDataSource(inputPath)

      muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

      val trackCount = extractor.trackCount
      val trackIndexMap = IntArray(trackCount)
      var maxBufferSize = DEFAULT_BUFFER_SIZE

      for (trackIndex in 0 until trackCount) {
        val format = extractor.getTrackFormat(trackIndex)
        if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
          maxBufferSize = max(maxBufferSize, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
        }
        trackIndexMap[trackIndex] = muxer.addTrack(format)
      }

      retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        ?.toIntOrNull()
        ?.let { rotation -> muxer.setOrientationHint(rotation) }

      if (!fields.contains(FIELD_LOCATION)) {
        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION)
          ?.let { locationString ->
            parseIso6709Location(locationString)?.let { (latitude, longitude) ->
              muxer.setLocation(latitude, longitude)
            }
          }
      }

      muxer.start()
      muxerStarted = true

      val buffer = ByteBuffer.allocateDirect(maxBufferSize)
      val bufferInfo = MediaCodec.BufferInfo()

      for (trackIndex in 0 until trackCount) {
        extractor.selectTrack(trackIndex)
      }

      while (true) {
        buffer.clear()
        val sampleSize = extractor.readSampleData(buffer, 0)
        if (sampleSize < 0) {
          break
        }

        bufferInfo.offset = 0
        bufferInfo.size = sampleSize
        bufferInfo.presentationTimeUs = extractor.sampleTime
        bufferInfo.flags = extractor.sampleFlags

        val sampleTrackIndex = extractor.sampleTrackIndex
        if (sampleTrackIndex < 0 || sampleTrackIndex >= trackIndexMap.size) {
          throw IllegalStateException("Invalid track index from extractor: $sampleTrackIndex")
        }

        muxer.writeSampleData(trackIndexMap[sampleTrackIndex], buffer, bufferInfo)
        extractor.advance()
      }
    } finally {
      extractor.release()
      retriever.release()

      if (muxerStarted) {
        try {
          muxer?.stop()
        } catch (_: Exception) {
          // Ignored - stopping the muxer can legitimately throw if no samples were written.
        }
      }
      muxer?.release()

      if (!outputFile.exists()) {
        throw IllegalStateException("Failed to create cleaned video at $outputPath")
      }
    }
  }

  private fun parseIso6709Location(value: String): Pair<Float, Float>? {
    val cleaned = value.trim().trimEnd('/')
    if (cleaned.isEmpty()) {
      return null
    }

    var splitIndex = -1
    for (i in 1 until cleaned.length) {
      val char = cleaned[i]
      if (char == '+' || char == '-') {
        splitIndex = i
        break
      }
    }

    if (splitIndex <= 0 || splitIndex >= cleaned.length - 1) {
      return null
    }

    val latitudePart = cleaned.substring(0, splitIndex)
    val longitudePart = cleaned.substring(splitIndex)

    val latitude = latitudePart.toFloatOrNull()
    val longitude = longitudePart.toFloatOrNull()

    return if (latitude != null && longitude != null) {
      latitude to longitude
    } else {
      null
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }

  companion object {
    private const val CHANNEL = "remove_video_location"
    private const val METHOD_REMOVE_METADATA = "removeMetadata"
    private const val FIELD_LOCATION = "location"
    private const val DEFAULT_BUFFER_SIZE = 512 * 1024
  }
}
