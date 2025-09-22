import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../modules/notifications/notification_center_screen.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Timer? _periodicCheckTimer;
  static Timer? _backgroundPushTimer;
  static List<dynamic> _cachedDrugs = [];

  // Notification settings with defaults
  static const String _prefKeyCheckInterval = 'notification_check_interval';
  static const String _prefKeyStockThreshold = 'stock_threshold';
  static const String _prefKeyExpiryDays = 'expiry_days_ahead';
  static const String _prefKeyNotificationsEnabled = 'notifications_enabled';
  static const String _prefKeyQuietHoursStart = 'quiet_hours_start';
  static const String _prefKeyQuietHoursEnd = 'quiet_hours_end';
  static const String _prefKeyDailyReminderTime = 'daily_reminder_time';
  static const String _prefKeyDailyReminderEnabled = 'daily_reminder_enabled';

  // Default values
  static const int _defaultCheckInterval = 30; // minutes
  static const int _defaultStockThreshold = 5;
  static const int _defaultExpiryDaysAhead = 30;
  static const bool _defaultNotificationsEnabled = true;
  static const int _defaultQuietHoursStart = 22; // 10 PM
  static const int _defaultQuietHoursEnd = 7;   // 7 AM
  static const int _defaultDailyReminderHour = 9; // 9 AM
  static const bool _defaultDailyReminderEnabled = true;

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

    // Start the enhanced background push notification service
    await startBackgroundPushService();

    print('NotificationsService initialized with background push service');
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
    _backgroundPushTimer?.cancel();
    _cachedDrugs.clear();
    print('NotificationsService disposed');
  }

  // ===== BACKGROUND PUSH NOTIFICATION SERVICE WITH CUSTOMIZABLE TIMING =====

  /// Get notification settings from shared preferences
  static Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'checkInterval': prefs.getInt(_prefKeyCheckInterval) ?? _defaultCheckInterval,
      'stockThreshold': prefs.getInt(_prefKeyStockThreshold) ?? _defaultStockThreshold,
      'expiryDaysAhead': prefs.getInt(_prefKeyExpiryDays) ?? _defaultExpiryDaysAhead,
      'notificationsEnabled': prefs.getBool(_prefKeyNotificationsEnabled) ?? _defaultNotificationsEnabled,
      'quietHoursStart': prefs.getInt(_prefKeyQuietHoursStart) ?? _defaultQuietHoursStart,
      'quietHoursEnd': prefs.getInt(_prefKeyQuietHoursEnd) ?? _defaultQuietHoursEnd,
      'dailyReminderHour': prefs.getInt(_prefKeyDailyReminderTime) ?? _defaultDailyReminderHour,
      'dailyReminderEnabled': prefs.getBool(_prefKeyDailyReminderEnabled) ?? _defaultDailyReminderEnabled,
    };
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    int? checkInterval,
    int? stockThreshold,
    int? expiryDaysAhead,
    bool? notificationsEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    int? dailyReminderHour,
    bool? dailyReminderEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (checkInterval != null) await prefs.setInt(_prefKeyCheckInterval, checkInterval);
    if (stockThreshold != null) await prefs.setInt(_prefKeyStockThreshold, stockThreshold);
    if (expiryDaysAhead != null) await prefs.setInt(_prefKeyExpiryDays, expiryDaysAhead);
    if (notificationsEnabled != null) await prefs.setBool(_prefKeyNotificationsEnabled, notificationsEnabled);
    if (quietHoursStart != null) await prefs.setInt(_prefKeyQuietHoursStart, quietHoursStart);
    if (quietHoursEnd != null) await prefs.setInt(_prefKeyQuietHoursEnd, quietHoursEnd);
    if (dailyReminderHour != null) await prefs.setInt(_prefKeyDailyReminderTime, dailyReminderHour);
    if (dailyReminderEnabled != null) await prefs.setBool(_prefKeyDailyReminderEnabled, dailyReminderEnabled);

    // Restart background service with new settings
    await startBackgroundPushService();

    print('Notification settings updated and service restarted');
  }

  /// Check if current time is within quiet hours
  static Future<bool> _isInQuietHours() async {
    final settings = await getNotificationSettings();
    final now = DateTime.now();
    final currentHour = now.hour;
    final quietStart = settings['quietHoursStart'] as int;
    final quietEnd = settings['quietHoursEnd'] as int;

    if (quietStart < quietEnd) {
      // Same day quiet hours (e.g., 22:00 to 7:00 next day)
      return currentHour >= quietStart || currentHour < quietEnd;
    } else {
      // Quiet hours span midnight (e.g., 10:00 PM to 7:00 AM)
      return currentHour >= quietStart && currentHour < quietEnd;
    }
  }

  /// Start the background push notification service
  static Future<void> startBackgroundPushService() async {
    // Stop any existing background timer
    _backgroundPushTimer?.cancel();

    final settings = await getNotificationSettings();
    final isEnabled = settings['notificationsEnabled'] as bool;
    final checkInterval = settings['checkInterval'] as int;

    if (!isEnabled) {
      print('Background notifications disabled by user');
      return;
    }

    // Start background timer with user-defined interval
    _backgroundPushTimer = Timer.periodic(Duration(minutes: checkInterval), (timer) async {
      await _performBackgroundCheck();
    });

    // Schedule daily reminders if enabled
    final dailyReminderEnabled = settings['dailyReminderEnabled'] as bool;
    if (dailyReminderEnabled) {
      _scheduleDailyReminder();
    }

    print('Background push notification service started with ${checkInterval}min intervals');
  }

  /// Stop the background push notification service
  static Future<void> stopBackgroundPushService() async {
    _backgroundPushTimer?.cancel();
    _backgroundPushTimer = null;
    print('Background push notification service stopped');
  }

  /// Perform background check with user preferences
  static Future<void> _performBackgroundCheck() async {
    try {
      // Check if notifications are enabled and not in quiet hours
      final settings = await getNotificationSettings();
      final isEnabled = settings['notificationsEnabled'] as bool;

      if (!isEnabled || await _isInQuietHours()) {
        return;
      }

      if (_cachedDrugs.isEmpty) {
        return;
      }

      final stockThreshold = settings['stockThreshold'] as int;
      final expiryDaysAhead = settings['expiryDaysAhead'] as int;

      // Check stock levels with user-defined threshold
      await _checkAndNotifyStockLevelsWithSettings(_cachedDrugs, stockThreshold);

      // Check expiry with user-defined days ahead
      await _checkExpiryNotificationsWithSettings(_cachedDrugs, expiryDaysAhead);

    } catch (e) {
      print('Error during background notification check: $e');
    }
  }

  /// Check stock levels with custom threshold
  static Future<void> _checkAndNotifyStockLevelsWithSettings(List<dynamic> drugs, int threshold) async {
    for (var drug in drugs) {
      if (drug.stock == 0) {
        await _showBackgroundNotification(
          drug.hashCode + 5000,
          'Critical Stock Alert',
          'The drug ${drug.name} is completely out of stock!',
          'stock',
          isUrgent: true,
        );
      } else if (drug.stock <= threshold) {
        await _showBackgroundNotification(
          drug.hashCode + 6000,
          'Low Stock Warning',
          'The drug ${drug.name} has only ${drug.stock} units left.',
          'stock',
        );
      }
    }
  }

  /// Check expiry with custom days ahead
  static Future<void> _checkExpiryNotificationsWithSettings(List<dynamic> drugs, int daysAhead) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    for (var drug in drugs) {
      try {
        final expiryDate = DateTime.tryParse(drug.expiryDate);
        if (expiryDate != null && expiryDate.isBefore(futureDate) && expiryDate.isAfter(now)) {
          final daysUntilExpiry = expiryDate.difference(now).inDays;

          await _showBackgroundNotification(
            drug.hashCode + 7000,
            'Drug Expiry Alert',
            'The drug ${drug.name} will expire in $daysUntilExpiry day(s).',
            'expiry',
            isUrgent: daysUntilExpiry <= 7,
          );
        }
      } catch (e) {
        print('Error checking expiry for ${drug.name}: $e');
      }
    }
  }

  /// Show background notification with respect to user settings
  static Future<void> _showBackgroundNotification(
    int id,
    String title,
    String body,
    String payload, {
    bool isUrgent = false,
  }) async {
    try {
      // Respect quiet hours for non-urgent notifications
      if (!isUrgent && await _isInQuietHours()) {
        return;
      }

      await _notificationsPlugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'drug_background_channel',
            'Background Drug Notifications',
            channelDescription: 'Background notifications for drug management',
            importance: isUrgent ? Importance.max : Importance.high,
            priority: isUrgent ? Priority.high : Priority.defaultPriority,
            playSound: !await _isInQuietHours(),
            enableVibration: !await _isInQuietHours(),
            ongoing: isUrgent, // Keep urgent notifications visible
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      print('Error showing background notification: $e');
    }
  }

  /// Schedule daily reminder notifications
  static void _scheduleDailyReminder() async {
    final settings = await getNotificationSettings();
    final reminderHour = settings['dailyReminderHour'] as int;

    // Calculate time until next reminder
    final now = DateTime.now();
    var nextReminder = DateTime(now.year, now.month, now.day, reminderHour);

    if (nextReminder.isBefore(now)) {
      nextReminder = nextReminder.add(const Duration(days: 1));
    }

    final timeUntilReminder = nextReminder.difference(now);

    Timer(timeUntilReminder, () async {
      if (!await _isInQuietHours()) {
        await _showDailyReminder();
      }

      // Schedule next day's reminder
      Timer.periodic(const Duration(days: 1), (timer) async {
        if (!await _isInQuietHours()) {
          await _showDailyReminder();
        }
      });
    });
  }

  /// Show daily reminder notification
  static Future<void> _showDailyReminder() async {
    if (_cachedDrugs.isEmpty) return;

    final criticalCount = _cachedDrugs.where((drug) => drug.stock == 0).length;
    final settings = await getNotificationSettings();
    final lowStockCount = _cachedDrugs.where((drug) =>
      drug.stock > 0 && drug.stock <= (settings['stockThreshold'] as int)
    ).length;

    if (criticalCount > 0 || lowStockCount > 0) {
      String message = '';
      if (criticalCount > 0) {
        message += '$criticalCount drug(s) out of stock. ';
      }
      if (lowStockCount > 0) {
        message += '$lowStockCount drug(s) running low. ';
      }

      await _showBackgroundNotification(
        8000,
        'Daily Pharmacy Reminder',
        '${message}Tap to review your inventory.',
        'daily_reminder',
      );
    }
  }

  /// Get background service status
  static bool isBackgroundServiceRunning() {
    return _backgroundPushTimer != null && _backgroundPushTimer!.isActive;
  }

  /// Force run background check (for testing)
  static Future<void> forceBackgroundCheck() async {
    await _performBackgroundCheck();
    print('Forced background check completed');
  }
}

// To use this service:
// 1. Call NotificationsService.initialize() in your main() or app startup.
// 2. Call NotificationsService.scheduleDrugExpiryNotifications(drugs) with your drug list.
// 3. Call NotificationsService.scheduleDrugStockNotifications(drugs) to schedule stock notifications.
// 4. Call NotificationsService.checkAndNotifyStockLevels(drugs) to immediately check and notify about stock issues.
// Make sure to add flutter_local_notifications and timezone packages to pubspec.yaml.
