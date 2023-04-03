import 'dart:async';
import 'dart:ffi';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_geofence/geofence.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/subjects.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    new FlutterLocalNotificationsPlugin();

void main() => runApp(MaterialApp(
      home: Scaffold(body: MyApp()),
    ));
BehaviorSubject<String> geoeventStream = BehaviorSubject();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final calcabenApartment = <String, dynamic>{
    'lat': 9.627392,
    'long': 123.8784023,
    'name': 'Calcaben Apartment',
    'radius': 150.0
  };
  final enterLocation = Geolocation(
    latitude: calcabenApartment['lat'] as double,
    longitude: calcabenApartment['long'] as double,
    radius: calcabenApartment['radius'] as double,
    id: '${calcabenApartment['name']}_enter',
  );
  final exitLocation = Geolocation(
    latitude: calcabenApartment['lat'] as double,
    longitude: calcabenApartment['long'] as double,
    radius: calcabenApartment['radius'] as double,
    id: '${calcabenApartment['name']}_exit',
  );
  String _message = "Message\n\n";
  late StreamSubscription<String> streamSubscription;

  @override
  void initState() {
    super.initState();
    _init();
    streamSubscription = geoeventStream.listen((event) {
      addLog(event);
      scheduleNotification('Event', event);
    });
    Geofence.onGeofenceEventReceived(geofenceEventCallback);
  }

  @override
  void dispose() {
    super.dispose();
    streamSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          alignment: AlignmentDirectional.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                calcabenApartment['name'],
                style: TextStyle(fontSize: 30),
              ),
              MaterialButton(
                color: Colors.lightBlueAccent,
                child: Text('Add Coordinates'),
                onPressed: () {
                  addGeolocation(enterLocation, GeolocationEvent.entry);
                  addGeolocation(exitLocation, GeolocationEvent.exit);
                  showSnackbar(
                      '${calcabenApartment['name']} added to geofence');
                },
              ),
              MaterialButton(
                color: Colors.lightBlueAccent,
                child: Text('Remove Coordinates'),
                onPressed: () {
                  Geofence.removeAllGeolocations();
                },
              ),
              SingleChildScrollView(child: Text(_message))
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _init() async {
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS =
    DarwinInitializationSettings(onDidReceiveLocalNotification: null);
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (await Permission.location.request().isGranted) {
      final locationAlways =
          await Permission.locationAlways.request().isGranted;
      if (locationAlways) {
        Geofence.requestPermissions();
      } else {
        // don't continue missing permission access
        return;
      }
    }
    Geofence.startListeningForLocationChanges();
    await Geofence.removeAllGeolocations();
  }

  void addGeolocation(Geolocation geolocation, GeolocationEvent event) {
    Geofence.addGeolocation(geolocation, event).then((onValue) {
      final message =
          '${event.name.split('.').last}: Your geofence has been added! ${geolocation.id}';
      print(message);
      addLog(message);
    }).catchError((error) {
      print('failed with $error');
    });
  }

  void showSnackbar(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  void addLog(String s) {
    setState(() {
      _message = "$_message$s\n";
    });
  }

  Future<void> scheduleNotification(String title, String subtitle) async {
    print("scheduling one with $title and $subtitle");
    var rng = new Random();
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your channel id', 'your channel name',
        importance: Importance.high, priority: Priority.high, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        rng.nextInt(100000), title, subtitle, platformChannelSpecifics,
        payload: 'item x');
  }
}

Future<void> geofenceEventCallback(
    Geolocation geolocation, GeolocationEvent event) async {
  print(
      'geofenceEventCallback: geolocation:${geolocation.id} event:${event.name}');
  geoeventStream.add('geolocation:${geolocation.id} event:${event.name}');
}
