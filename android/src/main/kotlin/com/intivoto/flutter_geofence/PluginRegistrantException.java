
package com.intivoto.flutter_geofence;

// Only applicable to v1 embedding applications.
class PluginRegistrantException extends RuntimeException {
    public PluginRegistrantException() {
        super(
                "PluginRegistrantCallback is not set. Did you forget to call "
                        + "FlutterGeofenceBackgroundService.setPluginRegistrant? See the documentation for instructions.");
    }
}
