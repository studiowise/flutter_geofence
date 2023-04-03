package com.intivoto.flutter_geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "GeoBroadcastReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DC", "Called onreceive")
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "something went wrong")
            return
        }
        if (ContextHolder.getApplicationContext() == null) {
            var c = context
            if (c.applicationContext != null) {
                c = context.applicationContext
            }
            ContextHolder.setApplicationContext(c)
        }


        // Get the transition type.
        val geofenceTransition = geofencingEvent.geofenceTransition

        if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER || geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            val event =
                if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER) GeoEvent.entry else GeoEvent.exit
            val triggeringGeofences = geofencingEvent.triggeringGeofences ?: emptyList()

            for (geofence: Geofence in triggeringGeofences) {
                val region = GeoRegion(
                    id = geofence.requestId,
                    latitude = geofencingEvent.triggeringLocation?.latitude ?: -1.0,
                    longitude = geofencingEvent.triggeringLocation?.longitude ?: -1.0,
                    radius = 50.0.toFloat(),
                    events = listOf(event)
                )

                Log.i(TAG, region.toString())

                val onBackgroundMessageIntent = Intent(
                    context,
                    FlutterGeofenceBackgroundService::class.java
                )
                onBackgroundMessageIntent.apply {
                    putExtra(FlutterGeofenceUtils.EXTRA_GEO_LOCATION, region)
                }
                FlutterGeofenceBackgroundService.enqueueMessageProcessing(
                    context, onBackgroundMessageIntent
                )
            }
        } else {
            // Log the error.
            Log.e(TAG, "Not an event of interest")
        }
    }

}