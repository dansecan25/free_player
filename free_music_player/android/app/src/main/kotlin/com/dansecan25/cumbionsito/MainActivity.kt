package com.dansecan25.cumbionsito

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * Extends audio_service's activity (needed for background playback) and adds the
 * channel the in-app updater uses to read the version and install downloaded APKs.
 */
class MainActivity : AudioServiceActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAppVersion" -> result.success(appVersion())
                        "canInstallPackages" -> result.success(canInstallPackages())
                        "openInstallSettings" -> {
                            openInstallSettings()
                            result.success(null)
                        }
                        "sha256" -> {
                            val file = updateFile(call)
                            executor.execute {
                                val hash = runCatching { sha256(file) }
                                mainHandler.post {
                                    hash.fold(
                                        { result.success(it) },
                                        { result.error("HASH_FAILED", it.message, null) },
                                    )
                                }
                            }
                        }
                        "installApk" -> {
                            installApk(updateFile(call))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("UPDATER_ERROR", error.message, null)
                }
            }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private fun appVersion(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf("versionName" to info.versionName, "versionCode" to code)
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
        )
    }

    /** Only files inside the updates cache folder may be hashed or installed. */
    private fun updateFile(call: MethodCall): File {
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("Missing path")
        val folder = File(cacheDir, UPDATES_DIR).canonicalFile
        val file = File(path).canonicalFile
        require(file.parentFile == folder && file.isFile) { "Not a downloaded update" }
        return file
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun installApk(file: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, APK_MIME_TYPE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    companion object {
        /** Must match AppInfo.updaterChannel in Dart. */
        private const val UPDATER_CHANNEL = "cumbionsito/updater"

        /** Must match AppInfo.updateCacheDir and res/xml/update_file_paths.xml. */
        private const val UPDATES_DIR = "updates"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
