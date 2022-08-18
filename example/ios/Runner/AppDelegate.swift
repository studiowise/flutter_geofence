import UIKit
import Flutter
import flutter_geofence

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register the plugins with the AppDelegate
    registerPlugins(self)
  
    // Set registerPlugins as a callback within GeofencingPlugin. This allows
    // for the Geofencing plugin to register the plugins with the background
    // FlutterEngine instance created to handle events. If this step is skipped,
    // other plugins will not work in the geofencing callbacks!
    SwiftFlutterGeofencePlugin.setPluginRegistrantCallback(registerPlugins)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

func registerPlugins(_ registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
}
