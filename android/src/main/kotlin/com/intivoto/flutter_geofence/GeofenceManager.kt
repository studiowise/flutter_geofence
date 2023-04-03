package com.intivoto.flutter_geofence

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.Looper
import android.os.Parcel
import android.os.Parcelable
import android.renderscript.RenderScript
import android.util.Log
import com.google.android.gms.location.*
import com.google.android.gms.location.Geofence.*
import com.google.android.gms.location.LocationRequest.PRIORITY_LOW_POWER


enum class GeoEvent {
    entry,
    exit
}

data class GeoRegion(
    val id: String,
    val radius: Float,
    val latitude: Double,
    val longitude: Double,
    val events: List<GeoEvent>
) : Parcelable {
    constructor(parcel: Parcel) : this(
        parcel.readString()!!,
        parcel.readFloat(),
        parcel.readDouble(),
        parcel.readDouble(),
        parcel.readString()?.split(",")?.map { GeoEvent.valueOf(it) } ?: emptyList()
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(id)
        parcel.writeFloat(radius)
        parcel.writeDouble(latitude)
        parcel.writeDouble(longitude)
        parcel.writeString(events.joinToString(",") { it.name })
    }

    override fun describeContents(): Int {
        return 0
    }

    companion object CREATOR : Parcelable.Creator<GeoRegion> {
        override fun createFromParcel(parcel: Parcel): GeoRegion {
            return GeoRegion(parcel)
        }

        override fun newArray(size: Int): Array<GeoRegion?> {
            return arrayOfNulls(size)
        }
    }

}

fun GeoRegion.serialized(): Map<String, Any?> {
    return hashMapOf(
        "id" to id,
        "radius" to radius,
        "latitude" to latitude,
        "longitude" to longitude,
        "event" to events.firstOrNull()?.name
    )
}

fun GeoRegion.convertRegionToGeofence(): Geofence {
    val transitionType: Int = if (events.contains(GeoEvent.entry)) {
        GEOFENCE_TRANSITION_ENTER
    } else {
        GEOFENCE_TRANSITION_EXIT
    }

    return Geofence.Builder()
        .setRequestId(id)
        .setCircularRegion(
            latitude,
            longitude,
            radius
        ).setLoiteringDelay(5 * 60 * 1000)// 5mins
        .setExpirationDuration(NEVER_EXPIRE)
        .setTransitionTypes(transitionType)
        .build()
}

class GeofenceManager(
    context: Context,
    val locationUpdate: (Location) -> Unit, val backgroundUpdate: (Location) -> Unit
) {

    private val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)


    private val geofencePendingIntent: PendingIntent by lazy {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        }
    }


    fun startMonitoring(geoRegion: GeoRegion) {
        geofencingClient.addGeofences(
            getGeofencingRequest(geoRegion.convertRegionToGeofence()),
            geofencePendingIntent
        )?.run {
            addOnSuccessListener {
                // Geofences added
                Log.d("DC", "added them")
            }
            addOnFailureListener {
                // Failed to add geofences
                Log.d("DC", "something not ok")
            }
        }
    }

    fun stopMonitoring(geoRegion: GeoRegion) {
        val regionsToRemove = listOf(geoRegion.id)
        geofencingClient.removeGeofences(regionsToRemove)
    }

    fun stopMonitoringAllRegions() {
        geofencingClient.removeGeofences(geofencePendingIntent)?.run {
            addOnSuccessListener {
                // Geofences removed
            }
            addOnFailureListener {
                // Failed to remove geofences
            }
        }
    }

    private fun getGeofencingRequest(geofence: Geofence): GeofencingRequest {
        val geofenceList = listOf(geofence)
        return GeofencingRequest.Builder().apply {
            setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            addGeofences(geofenceList)
        }.build()
    }

    private fun refreshLocation() {
        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { locationUpdate(it) }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            LocationRequest.create(),
            locationCallback,
            Looper.getMainLooper()
        )
    }

    fun getUserLocation() {
        fusedLocationClient.apply {
            lastLocation.addOnCompleteListener {
                it.result?.let {
                    if (System.currentTimeMillis() - it.time > 60 * 1000) {
                        refreshLocation()
                    } else {
                        locationUpdate(it)
                    }
                }
            }
        }
    }

    private val backgroundLocationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            locationResult.lastLocation?.let { backgroundUpdate(it) }
        }
    }

    fun startListeningForLocationChanges() {
        val request = LocationRequest().setInterval(900000L).setFastestInterval(900000L)
            .setPriority(PRIORITY_LOW_POWER)
        fusedLocationClient.requestLocationUpdates(
            request,
            backgroundLocationCallback,
            Looper.getMainLooper()
        )
    }

    fun stopListeningForLocationChanges() {
        fusedLocationClient.removeLocationUpdates(backgroundLocationCallback)
    }

}