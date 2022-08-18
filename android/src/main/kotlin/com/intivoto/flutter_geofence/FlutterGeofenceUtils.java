package com.intivoto.flutter_geofence;

import java.util.Map;

public class FlutterGeofenceUtils {
    static final int JOB_ID = 2022;
    static final String SHARED_PREFERENCES_KEY = "com.intivoto.flutter_geofence.callback";
    static final String EXTRA_GEO_LOCATION = "geo_location";


    static Map<String, Object> geoRerionToMap(GeoRegion geoRegion) {
        return GeofenceManagerKt.serialized(geoRegion);
    }
}
