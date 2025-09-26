import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/Drugs/drug_model.dart';
import '../repositories/drugs_repositories.dart';

/// Background task callback dispatcher - MUST be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('Background task started: $task');

      switch (task) {
        case 'drugMonitoringTask':
          await _performBackgroundCheck(inputData);
          break;
        case 'force_check':
          await _performBackgroundCheck(inputData);
          break;
        default:
          print('Unknown task: $task');
          break;
      }

      print('Background task completed: $task');
      return Future.value(true);
    } catch (e) {
      print('Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Background check implementation - top-level function for background execution
Future<void> _performBackgroundCheck(Map<String, dynamic>? inputData) async {
  try {
    print('Performing background drug check...');

    // Get settings from input data or use defaults
    final stockThreshold = inputData?['stockThreshold'] as int? ?? 5;
    final expiryDaysAhead = inputData?['expiryDaysAhead'] as int? ?? 30;
    final quietHoursStart = inputData?['quietHoursStart'] as int? ?? 22;
    final quietHoursEnd = inputData?['quietHoursEnd'] as int? ?? 7;

    // Initialize notification plugin for background use
    final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(initSettings);

    // Get drugs data (in a real background task, you'd need to fetch from a local cache
    // since network calls may not work reliably in background)
    final drugsRepository = DrugsRepository();
    final drugs = await drugsRepository.getAllDrugs();

    print('Found ${drugs.length} drugs to check');

    for (final drug in drugs) {
      // Check stock levels
      if (drug.stock <= stockThreshold) {
        final isUrgent = drug.stock == 0;
        await _sendBackgroundStockNotification(notificationsPlugin, drug, isUrgent, quietHoursStart, quietHoursEnd);
      }

      // Check expiry dates
      try {
        final expiryDate = DateTime.parse(drug.expiryDate);
        final now = DateTime.now();
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        if (daysUntilExpiry <= expiryDaysAhead) {
          final isUrgent = daysUntilExpiry <= 7;
          await _sendBackgroundExpiryNotification(notificationsPlugin, drug, daysUntilExpiry, isUrgent, quietHoursStart, quietHoursEnd);
        }
      } catch (e) {
        print('Error parsing expiry date for ${drug.name}: $e');
      }
    }

    print('Background check completed');
  } catch (e) {
    print('Error in background check: $e');
  }
}

/// Send stock notification in background
Future<void> _sendBackgroundStockNotification(
  FlutterLocalNotificationsPlugin plugin,
  DrugModel drug,
  bool isUrgent,
  int quietStart,
  int quietEnd,
) async {
  if (!isUrgent && _isQuietHoursBackground(quietStart, quietEnd)) {
    return;
  }

  final title = isUrgent ? '🚨 URGENT: Stock Critical!' : '⚠️ Low Stock Alert';
  final body = '${drug.name} is running low (${drug.stock} units remaining)';

  await plugin.show(
    drug.id ?? 0,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        isUrgent ? 'urgent_alerts' : 'low_stock_alerts',
        isUrgent ? 'Urgent Alerts' : 'Low Stock Alerts',
        channelDescription: isUrgent ? 'Critical medication alerts' : 'Notifications for low stock medications',
        importance: isUrgent ? Importance.max : Importance.high,
        priority: isUrgent ? Priority.max : Priority.high,
      ),
    ),
    payload: 'low_stock:${drug.id}',
  );
}

/// Send expiry notification in background
Future<void> _sendBackgroundExpiryNotification(
  FlutterLocalNotificationsPlugin plugin,
  DrugModel drug,
  int daysUntilExpiry,
  bool isUrgent,
  int quietStart,
  int quietEnd,
) async {
  if (!isUrgent && _isQuietHoursBackground(quietStart, quietEnd)) {
    return;
  }

  String title;
  String body;

  if (daysUntilExpiry <= 0) {
    title = '🚨 EXPIRED MEDICATION!';
    body = '${drug.name} has expired. Remove it immediately!';
  } else if (daysUntilExpiry <= 7) {
    title = '🚨 URGENT: Expiring Soon!';
    body = '${drug.name} expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
  } else {
    title = '📅 Expiry Reminder';
    body = '${drug.name} expires in $daysUntilExpiry days';
  }

  await plugin.show(
    drug.id != null ? drug.id! + 10000 : 10000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        isUrgent ? 'urgent_alerts' : 'expiry_alerts',
        isUrgent ? 'Urgent Alerts' : 'Expiry Alerts',
        channelDescription: isUrgent ? 'Critical medication alerts' : 'Notifications for expiring medications',
        importance: isUrgent ? Importance.max : Importance.high,
        priority: isUrgent ? Priority.max : Priority.high,
      ),
    ),
    payload: 'expiry:${drug.id}',
  );
}

/// Check quiet hours in background
bool _isQuietHoursBackground(int quietStart, int quietEnd) {
  final now = DateTime.now();
  final currentHour = now.hour;

  if (quietStart < quietEnd) {
    return currentHour >= quietStart && currentHour < quietEnd;
  } else {
    return currentHour >= quietStart || currentHour < quietEnd;
  }
}

class NotificationsService {
  static const String _backgroundTaskName = 'drugMonitoringTask';

  // Add navigator key for navigation from notifications
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Notification channel IDs
  static const String _lowStockChannelId = 'low_stock_alerts';
  static const String _expiryChannelId = 'expiry_alerts';
  static const String _dailyReminderChannelId = 'daily_reminders';
  static const String _urgentChannelId = 'urgent_alerts';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final DrugsRepository _drugsRepository = DrugsRepository();

  /// Initialize the notification service
  static Future<void> initialize() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Initialize notification plugin
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        requestCriticalPermission: true,
        requestProvisionalPermission: true
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize without background notification response handler to avoid the error
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels
      await _createNotificationChannels();

      // Initialize workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );

      // Start background service with initial settings
      await startBackgroundService();

      print('NotificationsService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationsService: $e');
      // Continue without crashing the app
    }
  }

  /// Show test notification for debugging
  static Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      99999,
      'PharmaNow Test',
      'Notification service is working correctly!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications for debugging',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Low stock alerts channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _lowStockChannelId,
            'Low Stock Alerts',
            description: 'Notifications for low stock medications',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Expiry alerts channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _expiryChannelId,
            'Expiry Alerts',
            description: 'Notifications for expiring medications',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Daily reminders channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _dailyReminderChannelId,
            'Daily Reminders',
            description: 'Daily medication inventory summaries',
            importance: Importance.defaultImportance,
            playSound: true,
          ),
        );

        // Urgent alerts channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _urgentChannelId,
            'Urgent Alerts',
            description: 'Critical medication alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }
  }

  /// Handle notification tap events
  static void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation based on notification payload
    print('Notification tapped: ${response.payload}');

    // Navigate to notification center with payload
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(
        '/notification-center',
        arguments: response.payload,
      );
    }
  }

  /// Start the background service
  static Future<void> startBackgroundService() async {
    try {
      final settings = await getNotificationSettings();

      if (settings['notificationsEnabled'] as bool) {
        // Cancel existing tasks
        await Workmanager().cancelAll();

        // Start periodic monitoring task
        await Workmanager().registerPeriodicTask(
          _backgroundTaskName,
          _backgroundTaskName,
          frequency: Duration(minutes: settings['checkInterval'] as int),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          inputData: {
            'stockThreshold': settings['stockThreshold'],
            'expiryDaysAhead': settings['expiryDaysAhead'],
            'quietHoursStart': settings['quietHoursStart'],
            'quietHoursEnd': settings['quietHoursEnd'],
          },
        );

        // Start daily reminder if enabled
        if (settings['dailyReminderEnabled'] as bool) {
          await _scheduleDailyReminder(
            settings['dailyReminderHour'] as int,
            settings['dailyReminderMinute'] as int,
          );
        }

        print('Background service started successfully');
      }
    } catch (e) {
      print('Error starting background service: $e');
      // Continue without crashing the app
    }
  }

  /// Stop the background service
  static Future<void> stopBackgroundService() async {
    await Workmanager().cancelAll();
    await _notificationsPlugin.cancelAll();
  }

  /// Check if background service is running
  static bool isBackgroundServiceRunning() {
    // This is a simplified check - in a real app you might want to track this more precisely
    return true; // You can implement more sophisticated tracking if needed
  }

  /// Schedule daily reminder with fallback for exact alarm permission
  static Future<void> _scheduleDailyReminder(int hour, int minute) async {
    try {
      // Check if we can schedule exact alarms on Android
      bool canScheduleExactAlarms = true;

      if (Platform.isAndroid) {
        try {
          final androidPlugin = _notificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

          if (androidPlugin != null) {
            // Try to check if exact alarms are permitted
            // This is a workaround since there's no direct API to check this
            canScheduleExactAlarms = await androidPlugin.canScheduleExactNotifications() ?? false;
          }
        } catch (e) {
          print('Cannot check exact alarm permission, falling back to inexact: $e');
          canScheduleExactAlarms = false;
        }
      }

      final scheduleMode = canScheduleExactAlarms
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notificationsPlugin.zonedSchedule(
        9999, // Special ID for daily reminder
        'PharmaNav Daily Summary',
        'Check your medication inventory for today',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _dailyReminderChannelId,
            'Daily Reminders',
            channelDescription: 'Daily medication inventory summaries',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        payload: 'daily_reminder',
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('Daily reminder scheduled successfully with ${canScheduleExactAlarms ? "exact" : "inexact"} timing');
    } catch (e) {
      print('Error scheduling daily reminder: $e');
      // If scheduling fails, we'll rely on the background service for notifications
    }
  }

  /// Calculate next instance of specified time
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Force a background check (for testing)
  static Future<void> forceBackgroundCheck() async {
    await Workmanager().registerOneOffTask(
      'force_check',
      _backgroundTaskName,
      inputData: await getNotificationSettings(),
    );
  }

  /// Get notification settings from SharedPreferences
  static Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'notificationsEnabled': prefs.getBool('notificationsEnabled') ?? true,
      'checkInterval': prefs.getInt('checkInterval') ?? 30,
      'stockThreshold': prefs.getInt('stockThreshold') ?? 5,
      'expiryDaysAhead': prefs.getInt('expiryDaysAhead') ?? 30,
      'quietHoursStart': prefs.getInt('quietHoursStart') ?? 22,
      'quietHoursEnd': prefs.getInt('quietHoursEnd') ?? 7,
      'dailyReminderEnabled': prefs.getBool('dailyReminderEnabled') ?? true,
      'dailyReminderHour': prefs.getInt('dailyReminderHour') ?? 9,
      'dailyReminderMinute': prefs.getInt('dailyReminderMinute') ?? 0,
    };
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    required bool notificationsEnabled,
    required int checkInterval,
    required int stockThreshold,
    required int expiryDaysAhead,
    required int quietHoursStart,
    required int quietHoursEnd,
    required bool dailyReminderEnabled,
    required int dailyReminderHour,
    required int dailyReminderMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('notificationsEnabled', notificationsEnabled);
    await prefs.setInt('checkInterval', checkInterval);
    await prefs.setInt('stockThreshold', stockThreshold);
    await prefs.setInt('expiryDaysAhead', expiryDaysAhead);
    await prefs.setInt('quietHoursStart', quietHoursStart);
    await prefs.setInt('quietHoursEnd', quietHoursEnd);
    await prefs.setBool('dailyReminderEnabled', dailyReminderEnabled);
    await prefs.setInt('dailyReminderHour', dailyReminderHour);
    await prefs.setInt('dailyReminderMinute', dailyReminderMinute);

    // Restart background service with new settings
    await startBackgroundService();
  }

  /// Check if current time is in quiet hours
  static bool _isQuietHours(int quietStart, int quietEnd) {
    final now = DateTime.now();
    final currentHour = now.hour;

    if (quietStart < quietEnd) {
      return currentHour >= quietStart && currentHour < quietEnd;
    } else {
      // Quiet hours span midnight (e.g., 22:00 to 07:00)
      return currentHour >= quietStart || currentHour < quietEnd;
    }
  }

  /// Send low stock notification
  static Future<void> _sendLowStockNotification(DrugModel drug, bool isUrgent) async {
    final settings = await getNotificationSettings();

    if (!isUrgent && _isQuietHours(settings['quietHoursStart'], settings['quietHoursEnd'])) {
      return; // Skip non-urgent notifications during quiet hours
    }

    final channelId = isUrgent ? _urgentChannelId : _lowStockChannelId;
    final title = isUrgent ? '🚨 URGENT: Stock Critical!' : '⚠️ Low Stock Alert';
    final body = '${drug.name} is running low (${drug.stock} units remaining)';

    await _notificationsPlugin.show(
      drug.id ?? 0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          isUrgent ? 'Urgent Alerts' : 'Low Stock Alerts',
          channelDescription: isUrgent ? 'Critical medication alerts' : 'Notifications for low stock medications',
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.max : Priority.high,
          ticker: body,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isUrgent ? InterruptionLevel.critical : InterruptionLevel.active,
        ),
      ),
      payload: 'low_stock:${drug.id}',
    );
  }

  /// Send expiry notification
  static Future<void> _sendExpiryNotification(DrugModel drug, int daysUntilExpiry, bool isUrgent) async {
    final settings = await getNotificationSettings();

    if (!isUrgent && _isQuietHours(settings['quietHoursStart'], settings['quietHoursEnd'])) {
      return; // Skip non-urgent notifications during quiet hours
    }

    final channelId = isUrgent ? _urgentChannelId : _expiryChannelId;
    String title;
    String body;

    if (daysUntilExpiry <= 0) {
      title = '🚨 EXPIRED MEDICATION!';
      body = '${drug.name} has expired. Remove it immediately!';
    } else if (daysUntilExpiry <= 7) {
      title = '🚨 URGENT: Expiring Soon!';
      body = '${drug.name} expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    } else {
      title = '📅 Expiry Reminder';
      body = '${drug.name} expires in $daysUntilExpiry days';
    }

    await _notificationsPlugin.show(
      drug.id != null ? drug.id! + 10000 : 10000, // Offset ID to avoid conflicts
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          isUrgent ? 'Urgent Alerts' : 'Expiry Alerts',
          channelDescription: isUrgent ? 'Critical medication alerts' : 'Notifications for expiring medications',
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.max : Priority.high,
          ticker: body,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isUrgent ? InterruptionLevel.critical : InterruptionLevel.active,
        ),
      ),
      payload: 'expiry:${drug.id}',
    );
  }

  /// Main background task logic
  static Future<void> performBackgroundCheck() async {
    try {
      final settings = await getNotificationSettings();

      if (!(settings['notificationsEnabled'] as bool)) {
        return;
      }

      final drugs = await _drugsRepository.getAllDrugs();
      final stockThreshold = settings['stockThreshold'] as int;
      final expiryDaysAhead = settings['expiryDaysAhead'] as int;

      for (final drug in drugs) {
        // Check stock levels
        if (drug.stock <= stockThreshold) {
          final isUrgent = drug.stock == 0;
          await _sendLowStockNotification(drug, isUrgent);
        }

        // Check expiry dates
        try {
          final expiryDate = DateTime.parse(drug.expiryDate);
          final now = DateTime.now();
          final daysUntilExpiry = expiryDate.difference(now).inDays;

          if (daysUntilExpiry <= expiryDaysAhead) {
            final isUrgent = daysUntilExpiry <= 7;
            await _sendExpiryNotification(drug, daysUntilExpiry, isUrgent);
          }
        } catch (e) {
          print('Error parsing expiry date for ${drug.name}: $e');
        }
      }
    } catch (e) {
      print('Error in background check: $e');
    }
  }

  /// Monitor and trigger critical alerts for the provided drugs list
  /// This method is called from the HomeCubit to check for immediate alerts
  static Future<void> monitorAndTriggerCriticalAlerts(List<Map<String, dynamic>> drugsData) async {
    try {
      final settings = await getNotificationSettings();

      if (!(settings['notificationsEnabled'] as bool)) {
        return;
      }

      final stockThreshold = settings['stockThreshold'] as int;
      final expiryDaysAhead = settings['expiryDaysAhead'] as int;

      for (final drugData in drugsData) {
        final drug = DrugModel.fromJson(drugData);

        // Check for critical stock situations
        if (drug.stock <= stockThreshold) {
          final isUrgent = drug.stock == 0;
          await _sendLowStockNotification(drug, isUrgent);
        }

        // Check for expiry situations
        try {
          final expiryDate = DateTime.parse(drug.expiryDate);
          final now = DateTime.now();
          final daysUntilExpiry = expiryDate.difference(now).inDays;

          if (daysUntilExpiry <= expiryDaysAhead) {
            final isUrgent = daysUntilExpiry <= 7;
            await _sendExpiryNotification(drug, daysUntilExpiry, isUrgent);
          }
        } catch (e) {
          print('Error parsing expiry date for ${drug.name}: $e');
        }
      }
    } catch (e) {
      print('Error in critical alerts monitoring: $e');
    }
  }

  /// Update the drugs list for ongoing monitoring
  /// This method can be used to update the service with the latest drug information
  static Future<void> updateDrugsList(List<Map<String, dynamic>> drugsData) async {
    // Store the drugs data in SharedPreferences for background access
    try {
      final prefs = await SharedPreferences.getInstance();
      final drugsJson = drugsData.map((drug) => drug.toString()).toList();
      await prefs.setStringList('cached_drugs_data', drugsJson);

      // Optionally trigger an immediate check for critical situations
      await monitorAndTriggerCriticalAlerts(drugsData);
    } catch (e) {
      print('Error updating drugs list: $e');
    }
  }

  /// Get cached drugs data from SharedPreferences
  static Future<List<Map<String, dynamic>>> getCachedDrugsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.getStringList('cached_drugs_data') ?? [];

      // This is a simplified implementation
      // In a real scenario, you might want to store this as proper JSON
      return [];
    } catch (e) {
      print('Error getting cached drugs data: $e');
      return [];
    }
  }
}
