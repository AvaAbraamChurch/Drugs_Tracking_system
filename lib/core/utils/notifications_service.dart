import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:async';
import '../../modules/notifications/notification_center_screen.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Timer? _periodicCheckTimer;
  static List<dynamic> _cachedDrugs = [];

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission for notifications (not alarms)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Start periodic background checks instead of scheduling alarms
    _startPeriodicChecks();

    print('NotificationsService initialized without alarm permissions');
  }

  /// Start periodic checks for drug stock and expiry (no alarms needed)
  static void _startPeriodicChecks() {
    // Stop any existing timer
    _periodicCheckTimer?.cancel();

    // Check every 30 minutes for stock/expiry issues
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (_cachedDrugs.isNotEmpty) {
        _performPeriodicCheck();
      }
    });

    print('Started periodic checks every 30 minutes (no alarms required)');
  }

  /// Perform periodic check without using alarms
  static Future<void> _performPeriodicCheck() async {
    try {
      await checkAndNotifyStockLevels(_cachedDrugs);
      await _checkExpiryNotifications(_cachedDrugs);
    } catch (e) {
      print('Error during periodic check: $e');
    }
  }

  /// Check for expiring drugs and show immediate notifications
  static Future<void> _checkExpiryNotifications(List<dynamic> drugs) async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final endOfNextMonth = DateTime(now.year, now.month + 2, 0);

    for (var drug in drugs) {
      try {
        final expiryDate = DateTime.tryParse(drug.expiryDate);
        if (expiryDate != null &&
            expiryDate.isAfter(nextMonth.subtract(const Duration(days: 1))) &&
            expiryDate.isBefore(endOfNextMonth.add(const Duration(days: 1)))) {

          // Show immediate notification for expiring drugs
          await _notificationsPlugin.show(
            drug.hashCode + 4000, // unique id for expiry notifications
            'Drug Expiry Reminder',
            'The drug ${drug.name} will expire on ${drug.expiryDate}.',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'drug_expiry_channel',
                'Drug Expiry Notifications',
                channelDescription: 'Reminds about drugs expiring next month',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: 'expiry',
          );
          print('Showed expiry notification for: ${drug.name}');
        }
      } catch (e) {
        print('Error checking expiry for ${drug.name}: $e');
      }
    }
  }

  /// Handle notification tap events
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;

    // Navigate to notification center based on payload
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => NotificationCenterScreen(
            notificationType: payload == 'expiry' ? 'expiry' :
                            payload == 'stock' ? 'stock' : null,
          ),
        ),
      );
    }
  }

  /// Update the cached drugs list and perform immediate checks
  static Future<void> updateDrugsList(List<dynamic> drugs) async {
    _cachedDrugs = drugs;

    // Immediately check for any critical issues
    await checkAndNotifyStockLevels(drugs);
    await _checkExpiryNotifications(drugs);

    print('Updated drugs list and performed immediate checks');
  }

  /// Remove scheduled notification methods and replace with immediate checks
  static Future<void> scheduleDrugExpiryNotifications(List<dynamic> drugs) async {
    // Instead of scheduling, update the cache and check immediately
    await updateDrugsList(drugs);
    print('Updated expiry monitoring (using periodic checks instead of alarms)');
  }

  /// Remove scheduled notification methods and replace with immediate checks
  static Future<void> scheduleDrugStockNotifications(List<dynamic> drugs, {int lowStockThreshold = 5}) async {
    // Instead of scheduling, update the cache and check immediately
    await updateDrugsList(drugs);
    print('Updated stock monitoring (using periodic checks instead of alarms)');
  }

  /// Immediately shows a notification for critically low stock (0 units)
  static Future<void> showCriticalStockNotification(dynamic drug) async {
    try {
      await _notificationsPlugin.show(
        drug.hashCode + 2000, // unique id for critical stock
        'Critical Stock Alert',
        'The drug ${drug.name} is out of stock!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'drug_stock_channel',
            'Drug Stock Notifications',
            channelDescription: 'Alerts about low drug stock levels',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: 'stock', // Add payload for navigation
      );
    } catch (e) {
      print('Error showing critical stock notification: ${e.toString()}');
    }
  }

  /// Shows immediate notification for low stock items
  static Future<void> showLowStockNotification(dynamic drug, {int lowStockThreshold = 5}) async {
    if (drug.stock <= lowStockThreshold && drug.stock > 0) {
      try {
        await _notificationsPlugin.show(
          drug.hashCode + 3000, // unique id for low stock
          'Low Stock Warning',
          'The drug ${drug.name} has only ${drug.stock} units left. Consider restocking soon.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'drug_stock_channel',
              'Drug Stock Notifications',
              channelDescription: 'Alerts about low drug stock levels',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: 'stock', // Add payload for navigation
        );
      } catch (e) {
        print('Error showing low stock notification: ${e.toString()}');
      }
    }
  }

  /// Checks all drugs and shows immediate notifications for stock issues
  static Future<void> checkAndNotifyStockLevels(List<dynamic> drugs, {int lowStockThreshold = 5}) async {
    for (var drug in drugs) {
      if (drug.stock == 0) {
        await showCriticalStockNotification(drug);
      } else if (drug.stock <= lowStockThreshold) {
        await showLowStockNotification(drug, lowStockThreshold: lowStockThreshold);
      }
    }
  }

  /// Show immediate test notifications (no scheduling)
  static Future<void> showTestNotification() async {
    try {
      await _notificationsPlugin.show(
        0,
        'Test Notification',
        'This is a test notification (no alarms used).',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'drug_expiry_channel',
            'Drug Expiry Notifications',
            channelDescription: 'Reminds about drugs expiring next month',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: 'expiry',
      );
      print('Showed test notification successfully');
    } catch (e) {
      print('Error showing test notification: ${e.toString()}');
    }
  }

  /// Test method for stock notifications (immediate)
  static Future<void> showTestStockNotification() async {
    try {
      await _notificationsPlugin.show(
        100,
        'Test Stock Notification',
        'This is a test stock notification (no alarms used).',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'drug_stock_channel',
            'Drug Stock Notifications',
            channelDescription: 'Alerts about low drug stock levels',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: 'stock',
      );
      print('Showed test stock notification successfully');
    } catch (e) {
      print('Error showing test stock notification: ${e.toString()}');
    }
  }

  /// Clean up resources
  static void dispose() {
    _periodicCheckTimer?.cancel();
    _cachedDrugs.clear();
    print('NotificationsService disposed');
  }
}

// To use this service:
// 1. Call NotificationsService.initialize() in your main() or app startup.
// 2. Call NotificationsService.scheduleDrugExpiryNotifications(drugs) with your drug list.
// 3. Call NotificationsService.scheduleDrugStockNotifications(drugs) to schedule stock notifications.
// 4. Call NotificationsService.checkAndNotifyStockLevels(drugs) to immediately check and notify about stock issues.
// Make sure to add flutter_local_notifications and timezone packages to pubspec.yaml.
