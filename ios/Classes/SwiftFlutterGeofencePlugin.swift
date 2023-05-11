import Flutter
import UIKit
import CoreLocation

public class SwiftFlutterGeofencePlugin: NSObject, FlutterPlugin {
	private var geofenceManager: GeofenceManager!
    
    static var instance: SwiftFlutterGeofencePlugin?
    static var registerPlugins: FlutterPluginRegistrantCallback?
    private var regionsState: [CLRegion: CLRegionState] = [:]
    
    var initialized = false
    let eventTypePosition = 0
    let eventTypeLyfecycle = 1
    let keyCallbackHandle = "geofence_user_callback_handle"
    let keyCallbackDispatcherHandle = "callback_dispatcher_handle"
    let keyIsTrecking = "is_trecking"
    
    var _eventQueue: NSMutableArray!
    var _persistentState: UserDefaults!
    var _locationManager: CLLocationManager!
    var _headlessRunner: FlutterEngine!
    var _registrar: FlutterPluginRegistrar!
    var _mainChannel: FlutterMethodChannel!
    var _backgroundChannel: FlutterMethodChannel!
    var isCallbackDispatcherReady = false
	
    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        registerPlugins = callback
    }
    
	public static func register(with registrar: FlutterPluginRegistrar) {
        if (instance == nil) {
            let instance = SwiftFlutterGeofencePlugin(registrar: registrar)
            registrar.addApplicationDelegate(instance)
        }
	}
	
	public init(registrar: FlutterPluginRegistrar) {
		super.init()
        // 1. Retrieve NSUserDefaults which will be used to store callback handles
               // between launches.
        _persistentState = UserDefaults.standard
        _eventQueue = NSMutableArray()
        
        
        
        // 3. Initialize the Dart runner which will be used to run the callback
        // dispatcher.
        _headlessRunner = FlutterEngine.init(name: "GeofenceIsolate", project: nil, allowHeadlessExecution: true)
        _registrar = registrar
        
        // 4. Create the method channel used by the Dart interface to invoke
        // methods and register to listen for method calls.
        
        _mainChannel = FlutterMethodChannel(name: "ph.josephmangmang/geofence", binaryMessenger: registrar.messenger())
        _registrar.addMethodCallDelegate(self, channel: _mainChannel)
        
        // 5. Create a second method channel to be used to communicate with the
        // callback dispatcher. This channel will be registered to listen for
        // method calls once the callback dispatcher is started.
        _backgroundChannel = FlutterMethodChannel(name: "ph.josephmangmang/geofence_background", binaryMessenger: _headlessRunner as! FlutterBinaryMessenger)
        
		self.geofenceManager = GeofenceManager(callback: { [weak self] (region) in
			self?.handleGeofenceEvent(region: region)
		}, locationUpdate: { [weak self] (coordinate) in
			self?._mainChannel.invokeMethod("userLocationUpdated", arguments: ["lat": coordinate.latitude, "lng": coordinate.longitude])
		}, backgroundLocationUpdated: { [weak self] (coordinate) in
			self?._mainChannel.invokeMethod("backgroundLocationUpdated", arguments: ["lat": coordinate.latitude, "lng": coordinate.longitude])
		})
	}
	
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
           // Check to see if we're being launched due to a location event.
           if (launchOptions[UIApplication.LaunchOptionsKey.location] != nil) {
               // Restart the headless service.
               self.startLocationService(self.getHandle(forKey: keyCallbackDispatcherHandle))
           }
       
           // Note: if we return false, this vetos the launch of the application.
           return true
       }
       
       private func startLocationService(_ callbackDispatcherHandle: Int64) {
           if(isCallbackDispatcherReady){
               return
           }
           
           guard let info: FlutterCallbackInformation = FlutterCallbackCache
               .lookupCallbackInformation(callbackDispatcherHandle) else {
               print("failed to find callback"); return
           }
           let entrypoint = info.callbackName
           let uri = info.callbackLibraryPath
           _headlessRunner.run(withEntrypoint: entrypoint, libraryURI: uri)
       
           // Once our headless runner has been started, we need to register the application's plugins
           // with the runner in order for them to work on the background isolate. `registerPlugins` is
           // a callback set from AppDelegate.m in the main application. This callback should register
           // all relevant plugins (excluding those which require UI).
           guard let registerPlugins = SwiftFlutterGeofencePlugin.registerPlugins else {
               print("failed to set registerPlugins"); return
           }
           registerPlugins(_headlessRunner)
           _registrar.addMethodCallDelegate(self, channel:_backgroundChannel)
           isCallbackDispatcherReady = true
       }
    
	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "GeofenceBackground#initialized":  initialized(result)
        case "Geofence#startBackgroundIsolate": initializeService(call, result)
        case "addRegion": handleAddRegion(call, result)
        case "removeRegion": handleRemoveRegion(call, result)
        case "removeRegions":
            geofenceManager.stopMonitoringAllRegions()
            result(nil)
        case "getUserLocation":
            geofenceManager.getUserLocation()
            result(nil)
        case "startListeningForLocationChanges":
            geofenceManager.startListeningForLocationChanges()
            result(nil)
        case "stopListeningForLocationChanges":
            geofenceManager.stopListeningForLocationChanges()
            result(nil)
        case "requestPermissions":
            geofenceManager.requestPermissions()
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
        
	}
    
    private func initializeService(_ call: FlutterMethodCall, _ result: FlutterResult) {
        
        print("initializeService")
        let map = call.arguments as! NSDictionary
        guard
            let callbackDispatcherHandle = map["pluginCallbackHandle"] as? Int64,
            let callbackHandle = map["geofenceUserCallbackHandle"] as? Int64
            else {return}
        saveHandle(callbackDispatcherHandle, forKey: keyCallbackDispatcherHandle)
        saveHandle(callbackHandle, forKey: keyCallbackHandle)
        
        self.startLocationService(callbackDispatcherHandle)
        result(nil)
    }
    
    private func initialized(_ result: FlutterResult) {
        synchronized(self) {
            
            self.initialized = true
            // Send the geofence events that occurred while the background
            // isolate was initializing.
//            while (_eventQueue.count > 0) {
//                let updateMap = _eventQueue[0] as! [String : Any]
//                _eventQueue.removeObject(at: 0)
//                sendEvent(updateMap)
//            }
        }
        
        result(nil);
    }
    
    private func handleAddRegion(_ call: FlutterMethodCall, _ result: FlutterResult) {
        guard let arguments = call.arguments as? [AnyHashable: Any] else { return }
        guard let identifier = arguments["id"] as? String,
              let latitude = arguments["lat"] as? Double,
              let longitude = arguments["lng"] as? Double else {
            return
        }
        let radius = arguments["radius"] as? Double
        let event = arguments["event"] as? String
        addRegion(identifier: identifier, latitude: latitude, longitude: longitude, radius: radius, event: event ?? "")
        result(nil)
    }
    
    private func handleRemoveRegion(_ call: FlutterMethodCall, _ result: FlutterResult){
        guard let arguments = call.arguments as? [AnyHashable: Any] else { return }
        guard let identifier = arguments["id"] as? String,
              let latitude = arguments["lat"] as? Double,
              let longitude = arguments["lng"] as? Double else {
            return
        }
        let radius = arguments["radius"] as? Double
        let event = arguments["event"] as? String
        removeRegion(identifier: identifier, latitude: latitude, longitude: longitude, radius: radius, event: event ?? "")
        result(nil)
    }
	private func handleGeofenceEvent(region: GeoRegion) {
        print("handleGeofenceEvent: \(region)")
        let updateMap = prepareUpdateMap(region: region)
        synchronized(self) {
            if (initialized) {
                self.sendEvent(updateMap)
            }
//            else {
//                _eventQueue.add(updateMap)
//            }
        }
	}
	
	private func addRegion(identifier: String, latitude: Double, longitude: Double, radius: Double?, event: String) {
		let events: [GeoEvent]
		switch event {
		case "GeolocationEvent.entry":
			events = [.entry]
		case "GeolocationEvent.exit":
			events = [.exit]
		default:
			events = [.entry, .exit]
		}
		let georegion = GeoRegion(id: identifier, radius: radius ?? 50.0, latitude: latitude, longitude: longitude, events: events)
		geofenceManager.startMonitoring(georegion: georegion)
	}
	
	private func removeRegion(identifier: String, latitude: Double, longitude: Double, radius: Double?, event: String) {
		let events: [GeoEvent]
		switch event {
		case "GeolocationEvent.entry":
			events = [.entry]
		case "GeolocationEvent.exit":
			events = [.exit]
		default:
			events = [.entry, .exit]
		}
		let georegion = GeoRegion(id: identifier, radius: radius ?? 50.0, latitude: latitude, longitude: longitude, events: events)
		geofenceManager.stopMonitoring(georegion: georegion)
	}
}

extension SwiftFlutterGeofencePlugin {
    private func sendEvent(_ updateMap: [String : Any]) {
        _backgroundChannel.invokeMethod("GeofenceBackground#onMessage", arguments: updateMap)
    }
    
    private func prepareUpdateMap(region: GeoRegion) -> [String : Any] {
        let regionMap = region.toDictionary()
        
        let updateMap = [
            "type"              : eventTypePosition,
            "geofenceUserCallbackHandle"    : getHandle(forKey: keyCallbackHandle),
            "geoRegion"       : regionMap
        ] as [String : Any]
        
        print("prepareUpdateMap: \(updateMap)")
        return updateMap
    }
    
}

// persistance state
extension SwiftFlutterGeofencePlugin {
    
    private func saveHandle(_ handle: Int64, forKey key: String) {
        _persistentState.set(handle, forKey: key)
    }
    
    private func getHandle(forKey key: String) -> Int64 {
        return _persistentState.object(forKey: key) as? Int64 ?? 0
    }
    
    private func isTrecking() -> Bool {
        return _persistentState.bool(forKey: keyIsTrecking)
    }
    
    private func saveIsTrecking(_ value: Bool) {
        return _persistentState.set(value, forKey: keyIsTrecking)
    }
}

public func synchronized<T>(_ lock: AnyObject, body: () throws -> T) rethrows -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try body()
}
