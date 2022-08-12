import 'geofence.dart';

/// Defines a handler for incoming geofence event
typedef BackgroundGeofenceEventHandler = Future<void> Function(Geolocation geolocation, GeolocationEvent event);
