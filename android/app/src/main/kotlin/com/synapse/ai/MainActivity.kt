package com.synapse_ai.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File

class MainActivity : FlutterActivity(), MethodCallHandler {
    private val TAG = "SynapseMainActivity"
    private val CHANNEL = "com.synapse.ai/native"
    private val PERMISSION_REQUEST_CODE = 12345
    
    companion object {
        var mainActivity: MainActivity? = null
        var pendingResult: Result? = null
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mainActivity = this
        try {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestAllPermissions()
            }
            startForegroundServiceInternal()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate", e)
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            Log.e(TAG, "Plugin registration error", e)
        }
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getDeviceInfo" -> getDeviceInfo(result)
            "isAccessibilityEnabled" -> result.success(checkAccessibilityEnabled())
            "requestAccessibility" -> requestAccessibility(result)
            "isOverlayEnabled" -> result.success(checkOverlayEnabled())
            "requestOverlay" -> requestOverlay(result)
            "isBatteryOptimizationIgnored" -> result.success(checkBatteryOptimizationIgnored())
            "requestIgnoreBatteryOptimization" -> requestIgnoreBatteryOptimization(result)
            "takeScreenshot" -> takeScreenshot(result)
            "getCurrentActivity" -> result.success(mainActivity != null)
            "openSettings" -> openSettings(result)
            "startService" -> startService(result)
            "stopService" -> stopService(result)
            "getPackageInfo" -> getPackageInfo(result)
            "checkPermissions" -> checkPermissions(result)
            "requestPermissions" -> requestPermissions(result)
            "openPermissionSettings" -> openPermissionSettings(result)
            "getForegroundServiceStatus" -> getForegroundServiceStatus(result)
            "restartApp" -> restartApp(result)
            else -> result.notImplemented()
        }
    }
    
    private fun requestAllPermissions() {
        try {
            val permissions = mutableListOf<String>()
            
            permissions.add(Manifest.permission.RECORD_AUDIO)
            permissions.add(Manifest.permission.CAMERA)
            permissions.add(Manifest.permission.READ_PHONE_STATE)
            permissions.add(Manifest.permission.CALL_PHONE)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                permissions.add(Manifest.permission.ANSWER_PHONE_CALLS)
            }
            
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
                permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            } else {
                permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
                permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
                permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
            
            val missingPermissions = permissions.filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            
            if (missingPermissions.isNotEmpty()) {
                ActivityCompat.requestPermissions(
                    this,
                    missingPermissions.toTypedArray(),
                    PERMISSION_REQUEST_CODE
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions", e)
        }
    }
    
    private fun getDeviceInfo(result: Result) {
        try {
            val info = mapOf(
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL,
                "device" to Build.DEVICE,
                "product" to Build.PRODUCT,
                "brand" to Build.BRAND,
                "androidVersion" to Build.VERSION.RELEASE,
                "sdkVersion" to Build.VERSION.SDK_INT,
                "isTablet" to isTablet(),
                "isRooted" to isRooted(),
                "batteryOptimizationIgnored" to checkBatteryOptimizationIgnored(),
                "accessibilityEnabled" to checkAccessibilityEnabled(),
                "overlayEnabled" to checkOverlayEnabled()
            )
            result.success(info)
        } catch (e: Exception) {
            Log.e(TAG, "getDeviceInfo error", e)
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun isTablet(): Boolean {
        return resources.configuration.smallestScreenWidthDp >= 600
    }
    
    private fun isRooted(): Boolean {
        val paths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        return paths.any { File(it).exists() }
    }
    
    private fun checkAccessibilityEnabled(): Boolean {
        return try {
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            enabledServices?.contains(packageName) == true
        } catch (e: Exception) {
            false
        }
    }
    
    private fun checkOverlayEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun checkBatteryOptimizationIgnored(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } catch (e: Exception) {
                false
            }
        } else {
            true
        }
    }
    
    private fun requestAccessibility(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun requestOverlay(result: Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun requestIgnoreBatteryOptimization(result: Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun takeScreenshot(result: Result) {
        result.success(true)
    }
    
    private fun openSettings(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun startService(result: Result) {
        try {
            startForegroundServiceInternal()
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun stopService(result: Result) {
        result.success(true)
    }
    
    private fun startForegroundServiceInternal() {
        Log.d(TAG, "Foreground service check initialized")
    }
    
    private fun getPackageInfo(result: Result) {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val info = mapOf(
                "versionName" to (packageInfo.versionName ?: "1.0.0"),
                "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) packageInfo.longVersionCode else packageInfo.versionCode.toLong(),
                "packageName" to packageInfo.packageName
            )
            result.success(info)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun checkPermissions(result: Result) {
        try {
            val permissions = mapOf(
                "recordAudio" to ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO),
                "camera" to ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA),
                "phoneState" to ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE),
                "callPhone" to ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE),
                "location" to ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            )
            result.success(permissions)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun requestPermissions(result: Result) {
        try {
            requestAllPermissions()
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun openPermissionSettings(result: Result) {
        openSettings(result)
    }
    
    private fun getForegroundServiceStatus(result: Result) {
        result.success(true)
    }
    
    private fun restartApp(result: Result) {
        try {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            startActivity(intent)
            Runtime.getRuntime().exit(0)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            Log.d(TAG, "Permissions result received")
        }
    }
    
    override fun onResume() {
        super.onResume()
        mainActivity = this
    }
    
    override fun onPause() {
        super.onPause()
        mainActivity = this
    }
    
    override fun onDestroy() {
        super.onDestroy()
        mainActivity = null
        pendingResult = null
    }
}
