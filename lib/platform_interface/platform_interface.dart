import 'dart:async';

import 'package:flutter_geofence/geofence.dart';
import 'package:flutter_geofence/method_channel/method_channel.dart';
import 'package:flutter_geofence/types.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class GeofencePlatform extends PlatformInterface {
  GeofencePlatform() : super(token: _token) {
    broadcastLocationStream = userLocationUpdated.stream.asBroadcastStream();
  }

  /// Create an instance with a [Geofence] using an existing instance.
  factory GeofencePlatform.instanceFor() {
    return GeofencePlatform.instance;
  }

  static final Object _token = Object();

  static GeofencePlatform? _instance;

  /// The current default [GeofencePlatform] instance.
  ///
  /// It will always default to [MethodChannelFirebaseMessaging]
  /// if no other implementation was provided.
  static GeofencePlatform get instance {
    return _instance ??= MethodChannelGeofence.instance;
  }

  /// Sets the [GeofencePlatform.instance]
  static set instance(GeofencePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  static BackgroundGeofenceEventHandler? _onBackgroundMessageHandler;

  /// Set a geofence event handler function which is called when the app is in the
  /// background or terminated.
  ///
  /// This provided handler must be a top-level function and cannot be
  /// anonymous otherwise an [ArgumentError] will be thrown.
  static BackgroundGeofenceEventHandler? get onBackgroundGeoEvent {
    return _onBackgroundMessageHandler;
  }

  /// Allows the background geofence event handler to be created and calls the
  /// instance delegate [registerBackgroundGeoEventHandler] to perform any
  /// platform specific registration logic.
  static set onBackgroundGeoEvent(BackgroundGeofenceEventHandler? handler) {
    _onBackgroundMessageHandler = handler;

    if (handler != null) {
      instance.registerBackgroundGeoEventHandler(handler);
    }
  }

  //ignore: close_sinks
  static StreamController<Coordinate> userLocationUpdated =
      new StreamController<Coordinate>();

  // ignore: close_sinks
  static StreamController<Coordinate> backgroundLocationUpdated =
      new StreamController<Coordinate>();
  static Stream<Coordinate>? broadcastLocationStream;

  /// Adds a geolocation for a certain geo-event
  Future<void> addGeolocation(Geolocation geolocation, GeolocationEvent event) {
    throw UnimplementedError('addGeolocation() is not implemented');
  }

  /// Stops listening to a geolocation for a certain geo-event
  Future<void> removeGeolocation(
      Geolocation geolocation, GeolocationEvent event) {
    throw UnimplementedError('removeGeolocation() is not implemented');
  }

  /// Stops listening to all regions
  Future<void> removeAllGeolocations() {
    throw UnimplementedError('removeAllGeolocations() is not implemented');
  }

  /// Get the latest location the user has been.
  Future<Coordinate?> getCurrentLocation() async {
    throw UnimplementedError('getCurrentLocation() is not implemented');
  }

  Future<void> startListeningForLocationChanges() {
    throw UnimplementedError(
        'startListeningForLocationChanges() is not implemented');
  }

  Future<void> stopListeningForLocationChanges() {
    throw UnimplementedError(
        'stopListeningForLocationChanges() is not implemented');
  }

  void requestPermissions() {
    throw UnimplementedError('requestPermissions() is not implemented');
  }

  /// Startup; needed to setup all callbacks and prevent race-issues.
  void initialize() {
    throw UnimplementedError('initialize() is not implemented');
  }

  /// Allows delegates to create a background geofence event handler implementation.
  ///
  /// For example, on native platforms this could be to setup an isolate, whereas
  /// on web a service worker can be registered.
  void registerBackgroundGeoEventHandler(
      BackgroundGeofenceEventHandler handler) {
    throw UnimplementedError(
        'registerBackgroundMessageHandler() is not implemented');
  }
}
