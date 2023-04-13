package com.intivoto.flutter_geofence

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.IBinder
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FlutterGeofencePlugin */
class FlutterGeofencePlugin() : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, Service() {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var geofenceManager: GeofenceManager? = null
    private var currentActivity: Activity? = null
        set(value) {
            if (value != null) {
                if (ContextHolder.getApplicationContext() == null) {
                    var c: Context = value
                    if (c.applicationContext != null) {
                        c = value.applicationContext
                    }
                    ContextHolder.setApplicationContext(c)
                }
            }
            field = value
        }

    override fun onBind(p0: Intent): IBinder? {
        return null;
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "ph.josephmangmang/geofence")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
//        val methodCallTask: Task<*>? = null

        when (call.method) {
            // This message is sent when the Dart side of this plugin is told to initialize.
            // In response, this (native) side of the plugin needs to spin up a background
            // Dart isolate by using the given pluginCallbackHandle, and then setup a background
            // method channel to communicate with the new background isolate. Once completed,
            // this onMethodCall() method will receive messages from both the primary and background
            // method channels.
            "Geofence#startBackgroundIsolate" -> {
                val arguments = call.arguments as? HashMap<*, *>

                var pluginCallbackHandle: Long = 0
                var userCallbackHandle: Long = 0

                val arg1 = arguments?.get("pluginCallbackHandle")
                val arg2 = arguments?.get("geofenceUserCallbackHandle")

                pluginCallbackHandle = if (arg1 is Long) {
                    arg1
                } else {
                    (arg1 as Int).toLong()
                }

                userCallbackHandle = if (arg2 is Long) {
                    arg2
                } else {
                    (arg2 as Int).toLong()
                }

                var shellArgs: FlutterShellArgs? = null
                currentActivity?.let {
                    // Supports both Flutter Activity types:
                    //    io.flutter.embedding.android.FlutterFragmentActivity
                    //    io.flutter.embedding.android.FlutterActivity
                    // We could use `getFlutterShellArgs()` but this is only available on `FlutterActivity`.
                    shellArgs = FlutterShellArgs.fromIntent(it.intent)
                }

                FlutterGeofenceBackgroundService.setCallbackDispatcher(pluginCallbackHandle)
                FlutterGeofenceBackgroundService.setUserCallbackHandle(userCallbackHandle)
                FlutterGeofenceBackgroundService.startBackgroundIsolate(
                    pluginCallbackHandle, shellArgs
                )
                result.success(null)
            }
            "addRegion" -> {
                val arguments = call.arguments as? HashMap<*, *>
                if (arguments != null) {
                    val region = safeLet(
                        arguments["id"] as? String,
                        arguments["radius"] as? Double,
                        arguments["lat"] as? Double,
                        arguments["lng"] as? Double,
                        arguments["event"] as? String
                    )
                    { id, radius, latitude, longitude, event ->
                        GeoRegion(
                            id,
                            radius.toFloat(),
                            latitude,
                            longitude,
                            events = when (event) {
                                "GeolocationEvent.entry" -> listOf(GeoEvent.entry)
                                "GeolocationEvent.exit" -> listOf(GeoEvent.exit)
                                else -> GeoEvent.values().toList()
                            }
                        )
                    }
                    if (region != null) {
                        geofenceManager?.startMonitoring(region)
                        result.success(null)
                    } else {
                        result.error(
                            "Invalid arguments",
                            "Has invalid arguments",
                            "Has invalid arguments"
                        )
                    }
                } else {
                    result.error(
                        "Invalid arguments",
                        "Has invalid arguments",
                        "Has invalid arguments"
                    )
                }
            }
            "removeRegion" -> {
                val arguments = call.arguments as? HashMap<*, *>
                if (arguments != null) {
                    val region = safeLet(
                        arguments["id"] as? String,
                        arguments["radius"] as? Double,
                        arguments["lat"] as? Double,
                        arguments["lng"] as? Double,
                        arguments["event"] as? String
                    )
                    { id, radius, latitude, longitude, event ->
                        GeoRegion(
                            id,
                            radius.toFloat(),
                            latitude,
                            longitude,
                            events = when (event) {
                                "GeolocationEvent.entry" -> listOf(GeoEvent.entry)
                                "GeolocationEvent.exit" -> listOf(GeoEvent.exit)
                                else -> GeoEvent.values().toList()
                            }
                        )
                    }
                    if (region != null) {
                        geofenceManager?.stopMonitoring(region)
                        result.success(null)
                    } else {
                        result.error(
                            "Invalid arguments",
                            "Has invalid arguments",
                            "Has invalid arguments"
                        )
                    }
                } else {
                    result.error(
                        "Invalid arguments",
                        "Has invalid arguments",
                        "Has invalid arguments"
                    )
                }
            }
            "removeRegions" -> {

                geofenceManager?.stopMonitoringAllRegions()
                result.success(null)
            }
            "getUserLocation" -> {
                geofenceManager?.getUserLocation()
                result.success(null)
            }
            "requestPermissions" -> {
                requestPermissions()
            }
            "startListeningForLocationChanges" -> {
                geofenceManager?.startListeningForLocationChanges()
                result.success(null)
            }
            "stopListeningForLocationChanges" -> {
                geofenceManager?.stopListeningForLocationChanges()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }


//        methodCallTask?.addOnCompleteListener { task ->
//            if (task.isSuccessful) {
//                result.success(task.result)
//            } else {
//                val exception = task.exception
//                result.error(
//                    "geofence",
//                    exception?.message,
//                    getExceptionDetails(exception)
//                )
//            }
//        }
    }

    private fun getExceptionDetails(exception: Exception?): Map<String, Any?> {
        val details: MutableMap<String, Any?> = java.util.HashMap()
        details["code"] = "unknown"
        if (exception != null) {
            details["message"] = exception.message
        } else {
            details["message"] = "An unknown error has occurred."
        }
        return details
    }

    private fun requestPermissions() {
        safeLet(currentActivity, currentActivity?.applicationContext) { activity, context ->
            checkPermissions(context, activity)
        }
    }

    @SuppressLint("InlinedApi")
    private fun checkPermissions(context: Context, activity: Activity) {
        // Here, thisActivity is the current activity
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            )
            != PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
            != PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ),
                999
            )
        } else {
            // Permission has already been granted
            startGeofencing(context)
        }
    }

    private fun startGeofencing(context: Context) {
        context.let {
            geofenceManager = GeofenceManager(it, {
                channel.invokeMethod(
                    "userLocationUpdated",
                    hashMapOf("lat" to it.latitude, "lng" to it.longitude)
                )
            }, {
                channel.invokeMethod(
                    "backgroundLocationUpdated",
                    hashMapOf("lat" to it.latitude, "lng" to it.longitude)
                )
            })
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean =
        when (requestCode) {
            999 -> {
                if (grantResults != null && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    currentActivity?.let {
                        startGeofencing(it.applicationContext)
                    }
                    true
                } else {
                    false
                }
            }
            else -> false
        }
}