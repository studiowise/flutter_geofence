import 'dart:async';

import 'package:flutter_geofence/Geolocation.dart';
import 'package:flutter_geofence/platform_interface/platform_interface.dart';
import 'package:flutter_geofence/types.dart';

export 'Geolocation.dart';

typedef void GeofenceCallback(Geolocation foo);

class Coordinate {
  final double latitude;
  final double longitude;

  Coordinate(this.latitude, this.longitude);
}

class Geofence {
  // Cached and lazily loaded instance of [GeofencePlatform] to avoid
  // creating a [MethodChannelFirebaseMessaging] when not needed or creating an
  // instance with the default app before a user specifies an app.
  GeofencePlatform? _delegatePackingProperty;

  static Map<String, Geofence> _geofenceInstances = {};

  GeofencePlatform get _delegate {
    return _delegatePackingProperty ??= GeofencePlatform.instanceFor();
  }

  Geofence._();

  static Geofence get instance {
    return Geofence._instanceFor();
  }

  factory Geofence._instanceFor() {
    return _geofenceInstances.putIfAbsent('geofence_app', () {
      return Geofence._();
    });
  }

  StreamController<Coordinate> get backgroundLocationUpdated =>
      GeofencePlatform.backgroundLocationUpdated;

  /// Adds a geolocation for a certain geo-event
  static Future<void> addGeolocation(
      Geolocation geolocation, GeolocationEvent event) {
    return instance._delegate.addGeolocation(geolocation, event);
  }

  /// Stops listening to a geolocation for a certain geo-event
  static Future<void> removeGeolocation(
      Geolocation geolocation, GeolocationEvent event) {
    return instance._delegate.removeGeolocation(geolocation, event);
  }

  /// Stops listening to all regions
  static Future<void> removeAllGeolocations() {
    return instance._delegate.removeAllGeolocations();
  }

  /// Get the latest location the user has been.
  static Future<Coordinate?> getCurrentLocation() {
    return instance._delegate.getCurrentLocation();
  }

  static Future<void> startListeningForLocationChanges() {
    return instance._delegate.startListeningForLocationChanges();
  }

  static Future<void> stopListeningForLocationChanges() {
    return instance._delegate.stopListeningForLocationChanges();
  }

  static void requestPermissions() {
    instance._delegate.requestPermissions();
  }

  // ignore: use_setters_to_change_properties
  /// Set a message handler function which is called when the app is in the
  /// background or terminated.
  ///
  /// This provided handler must be a top-level function and cannot be
  /// anonymous otherwise an [ArgumentError] will be thrown.
  // ignore: use_setters_to_change_properties
  static void onGeofenceEventReceived(BackgroundGeofenceEventHandler handler) {
    GeofencePlatform.onBackgroundGeoEvent = handler;
  }
}
