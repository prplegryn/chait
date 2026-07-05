package com.prplegryn.chait

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "chait.app/logs"
    private val relativeLogPath = "${Environment.DIRECTORY_DOWNLOADS}/Chait/logs/"
    private val logUris = mutableMapOf<String, android.net.Uri>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "append" -> {
                        val fileName = call.argument<String>("fileName").orEmpty()
                        val text = call.argument<String>("text").orEmpty()
                        Thread {
                            try {
                                val path = appendPublicLog(fileName, text)
                                runOnUiThread { result.success(path) }
                            } catch (error: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "LOG_WRITE_FAILED",
                                        error.message ?: error.javaClass.simpleName,
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "path" -> {
                        val fileName = call.argument<String>("fileName").orEmpty()
                        result.success(publicPath(fileName))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun appendPublicLog(fileName: String, text: String): String {
        require(fileName.isNotBlank()) { "empty log file name" }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val collection = MediaStore.Downloads.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY
            )
            val uri = logUris[fileName] ?: findExistingLogUri(fileName) ?: resolver.insert(
                collection,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativeLogPath)
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
            ) ?: error("cannot create public log file")
            logUris[fileName] = uri
            resolver.openOutputStream(uri, "wa")?.use { stream ->
                stream.write(text.toByteArray(Charsets.UTF_8))
            } ?: error("cannot open public log file")
            return publicPath(fileName)
        }
        return appendLegacyPublicLog(fileName, text)
    }

    private fun findExistingLogUri(fileName: String): android.net.Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        val collection = MediaStore.Downloads.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY
        )
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?"
        val args = arrayOf(fileName, relativeLogPath)
        applicationContext.contentResolver.query(
            collection,
            projection,
            selection,
            args,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return ContentUris.withAppendedId(collection, id)
            }
        }
        return null
    }

    @Suppress("DEPRECATION")
    private fun appendLegacyPublicLog(fileName: String, text: String): String {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "Chait/logs"
        )
        if (!dir.exists()) {
            dir.mkdirs()
        }
        val file = File(dir, fileName)
        file.appendText(text, Charsets.UTF_8)
        return file.absolutePath
    }

    private fun publicPath(fileName: String): String {
        return "/storage/emulated/0/Download/Chait/logs/$fileName"
    }
}
