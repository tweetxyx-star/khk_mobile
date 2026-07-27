import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'api_service.dart';

// Must be a top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.messageId}');
  debugPrint('Background data: ${message.data}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Call this in main() after Firebase.initializeApp()
  static Future<void> init() async {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission for iOS + Android 13+
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      return;
    }

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await _saveTokenToServer(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToServer);

    // Initialize local notifications
    await _initLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.messageId}');
      debugPrint('Data: ${message.data}');
      _showLocalNotification(message);
    });

    // Handle when app is opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Handle notification tap when app was terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  }

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false, // We already requested via Firebase
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
        if (response.payload != null) {
          // Parse payload if needed
          _handleNotificationTap({'payload': response.payload});
        }
      },
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'khk_bookings', // id
      'KHK Bookings', // name
      description: 'Booking confirmations and updates from KHK Cricket',
      importance: Importance.max,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _saveTokenToServer(String token) async {
    try {
      debugPrint('Saving FCM token to server...');
      await ApiService.post('/user/fcm-token', {
        'fcm_token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'device_name': Platform.localHostname,
      });
      debugPrint('FCM token saved successfully');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'khk_bookings',
            'KHK Bookings',
            channelDescription: 'Booking confirmations and updates',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotif.show(
        notification.hashCode,
        notification.title ?? 'KHK Cricket',
        notification.body,
        notificationDetails,
        payload: message.data.toString(),
      );
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle navigation based on notification data
    // Example: if data['type'] == 'booking', navigate to booking details
    debugPrint('Handle notification tap with data: $data');

    // You can use a global navigator key or event bus to navigate
    // Navigator.pushNamed(context, '/booking', arguments: data['booking_id']);
  }

  // Call this on logout to remove token
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
