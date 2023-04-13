import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_geofence/geofence.dart';
import 'package:flutter_geofence/platform_interface/platform_interface.dart';
import 'package:flutter_geofence/types.dart';

// This is the entrypoint for the background isolate. Since we can only enter
// an isolate once, we setup a MethodChannel to listen for method invocations
// from the native portion of the plugin. This allows for the plugin to perform
// any necessary processing in Dart (e.g., populating a custom object) before
// invoking the provided callback.
@pragma('vm:entry-point')
void _geofenceCallbackDispatcher() {
  // Initialize state necessary for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel _channel = MethodChannel('ph.josephmangmang/geofence_background');

  // This is where we handle background events from the native portion of the plugin.
  _channel.setMethodCallHandler((MethodCall call) async {
    print("geofence_background: ${call.method}");
    if (call.method == 'GeofenceBackground#onMessage') {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments["geofenceUserCallbackHandle"]);

      // PluginUtilities.getCallbackFromHandle performs a lookup based on the
      // callback handle and returns a tear-off of the original callback.
      final closure = PluginUtilities.getCallbackFromHandle(handle)!
          as Future<void> Function(Geolocation, GeolocationEvent event);

      try {
        Map<String, dynamic> messageMap =
            Map<String, dynamic>.from(call.arguments['geoRegion']);
        final Geolocation geoLocation = Geolocation.fromMap(messageMap);
        final GeolocationEvent event = GeolocationEvent.values.firstWhere(
            (element) => element.name == messageMap['event'],
            orElse: () => GeolocationEvent.entry);

        await closure(geoLocation, event);
      } catch (e) {
        // ignore: avoid_print
        print(
            'FlutterGeofence: An error occurred in your background geofence event handler:');
        // ignore: avoid_print
        print(e);
      }
    } else {
      throw UnimplementedError('${call.method} has not been implemented');
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling alarms.
  _channel.invokeMethod<void>('GeofenceBackground#initialized');
}

class MethodChannelGeofence extends GeofencePlatform {
  /// Create an instance of [MethodChannelGeofence] with optional [Geofence]
  MethodChannelGeofence() : super() {
    if (_initialized) return;

    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'backgroundLocationUpdated':
          Coordinate coordinate =
              Coordinate(call.arguments["lat"], call.arguments["lng"]);
          GeofencePlatform.backgroundLocationUpdated.sink.add(coordinate);
          break;
        case 'userLocationUpdated':
          Coordinate coordinate =
              Coordinate(call.arguments["lat"], call.arguments["lng"]);
          GeofencePlatform.userLocationUpdated.sink.add(coordinate);
          break;
        case 'Geofence#onBackgroundMessage':
          Map<String, dynamic> geolocationMap =
              Map<String, dynamic>.from(call.arguments);

          final event = GeolocationEvent.values.firstWhere(
              (element) => element.name == call.arguments["event"],
              orElse: () => GeolocationEvent.entry);

          return GeofencePlatform.onBackgroundGeoEvent?.call(
            Geolocation.fromMap(geolocationMap),
            event,
          );
        default:
          throw UnimplementedError('${call.method} has not been implemented');
      }
    });
    _initialized = true;
  }

  static bool _initialized = false;
  static bool _bgHandlerInitialized = false;

  /// Returns a stub instance to allow the platform interface to access
  /// the class instance statically.
  static MethodChannelGeofence get instance {
    return MethodChannelGeofence._();
  }

  MethodChannelGeofence._() : super();

  /// The [MethodChannel] to which calls will be delegated.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('ph.josephmangmang/geofence');

  /// Adds a geolocation for a certain geo-event
  @override
  Future<void> addGeolocation(Geolocation geolocation, GeolocationEvent event) {
    return channel.invokeMethod("addRegion", {
      "lng": geolocation.longitude,
      "lat": geolocation.latitude,
      "id": geolocation.id,
      "radius": geolocation.radius,
      "event": event.toString(),
    });
  }

  /// Stops listening to a geolocation for a certain geo-event
  @override
  Future<void> removeGeolocation(
      Geolocation geolocation, GeolocationEvent event) {
    return channel.invokeMethod("removeRegion", {
      "lng": geolocation.longitude,
      "lat": geolocation.latitude,
      "id": geolocation.id,
      "radius": geolocation.radius,
      "event": event.toString(),
    });
  }

  /// Stops listening to all regions
  @override
  Future<void> removeAllGeolocations() {
    return channel.invokeMethod("removeRegions", null);
  }

  /// Get the latest location the user has been.
  @override
  Future<Coordinate?> getCurrentLocation() async {
    channel.invokeMethod("getUserLocation", null);
    return GeofencePlatform.broadcastLocationStream?.first;
  }

  @override
  Future<void> startListeningForLocationChanges() {
    return channel.invokeMethod("startListeningForLocationChanges");
  }

  @override
  Future<void> stopListeningForLocationChanges() {
    return channel.invokeMethod("stopListeningForLocationChanges");
  }

  @override
  void requestPermissions() {
    channel.invokeMethod("requestPermissions", null);
  }

  @override
  Future<void> registerBackgroundGeoEventHandler(
      BackgroundGeofenceEventHandler handler) async {
    // if (defaultTargetPlatform != TargetPlatform.android) {
    //   return;
    // }

    if (!_bgHandlerInitialized) {
      _bgHandlerInitialized = true;
      final CallbackHandle bgHandle =
          PluginUtilities.getCallbackHandle(_geofenceCallbackDispatcher)!;
      final CallbackHandle userHandle =
          PluginUtilities.getCallbackHandle(handler)!;
      await channel.invokeMapMethod('Geofence#startBackgroundIsolate', {
        'pluginCallbackHandle': bgHandle.toRawHandle(),
        "geofenceUserCallbackHandle": userHandle.toRawHandle(),
      });
    }
  }
}
