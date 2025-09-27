import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/repositories/drugs_repositories.dart';
import '../../core/models/Drugs/drug_model.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationsService._ensureTimezoneInit();
      await NotificationsService._initNotificationsPluginIfNeeded();
      await NotificationsService._backgroundEnsureSupabase();

      await NotificationsService._performCheckAndNotify(isFromBackground: true);

      return Future.value(true);
    } catch (e) {
      // Best-effort logging; background isolate has no console sometimes
      return Future.value(false);
    }
  });
}

class NotificationsService {
  // Public navigator key used by MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Channels
  static const String _channelStockId = 'pharmanow_low_stock';
  static const String _channelExpiryId = 'pharmanow_expiry';
  static const String _channelDailyId = 'pharmanow_daily';

  static const String _workTag = 'pharmanow_background_check';
  static const String _workUniqueName = 'pharmanow_periodic_check';

  // Settings keys
  static const String _kNotificationsEnabled = 'notificationsEnabled';
  static const String _kCheckInterval = 'checkInterval'; // minutes
  static const String _kStockThreshold = 'stockThreshold';
  static const String _kExpiryDaysAhead = 'expiryDaysAhead';
  static const String _kQuietStart = 'quietHoursStart'; // 0-23
  static const String _kQuietEnd = 'quietHoursEnd'; // 0-23
  static const String _kDailyEnabled = 'dailyReminderEnabled';
  static const String _kDailyHour = 'dailyReminderHour';
  static const String _kDailyMinute = 'dailyReminderMinute';
  static const String _kBgRunning = 'bg_running';

  // Store Supabase credentials for background isolate
  static const String _kSupabaseUrl = 'supabase_url';
  static const String _kSupabaseKey = 'supabase_key';

  static final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static bool _timezoneInitialized = false;

  // Initialize services (called from main.dart)
  static Future<void> initialize({String? supabaseUrl, String? supabaseKey}) async {
    // Persist Supabase creds if provided (main.dart can pass them)
    if (supabaseUrl != null && supabaseKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSupabaseUrl, supabaseUrl);
      await prefs.setString(_kSupabaseKey, supabaseKey);
    }

    await _ensureTimezoneInit();
    await _initNotificationsPluginIfNeeded();

    // Request permissions when applicable
    await _requestPlatformPermissions();

    // Ensure default settings exist
    await _ensureDefaultSettings();

    // Schedule daily reminder if needed
    await _scheduleOrCancelDailyReminder();

    // Register periodic background check
    await _registerOrCancelBackgroundWork();
  }

  // API used by UI
  static Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'notificationsEnabled': prefs.getBool(_kNotificationsEnabled) ?? true,
      'checkInterval': prefs.getInt(_kCheckInterval) ?? 30,
      'stockThreshold': prefs.getInt(_kStockThreshold) ?? 5,
      'expiryDaysAhead': prefs.getInt(_kExpiryDaysAhead) ?? 30,
      'quietHoursStart': prefs.getInt(_kQuietStart) ?? 22,
      'quietHoursEnd': prefs.getInt(_kQuietEnd) ?? 7,
      'dailyReminderEnabled': prefs.getBool(_kDailyEnabled) ?? true,
      'dailyReminderHour': prefs.getInt(_kDailyHour) ?? 9,
      'dailyReminderMinute': prefs.getInt(_kDailyMinute) ?? 0,
    };
  }

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
    await prefs.setBool(_kNotificationsEnabled, notificationsEnabled);
    await prefs.setInt(_kCheckInterval, checkInterval);
    await prefs.setInt(_kStockThreshold, stockThreshold);
    await prefs.setInt(_kExpiryDaysAhead, expiryDaysAhead);
    await prefs.setInt(_kQuietStart, quietHoursStart);
    await prefs.setInt(_kQuietEnd, quietHoursEnd);
    await prefs.setBool(_kDailyEnabled, dailyReminderEnabled);
    await prefs.setInt(_kDailyHour, dailyReminderHour);
    await prefs.setInt(_kDailyMinute, dailyReminderMinute);

    await _scheduleOrCancelDailyReminder();
    await _registerOrCancelBackgroundWork();
  }

  static bool isBackgroundServiceRunning() {
    // Heuristic flag; Workmanager doesn't expose actual status
    return _cachedBgRunning ?? false;
  }

  static bool? _cachedBgRunning;

  static Future<void> forceBackgroundCheck() async {
    await _performCheckAndNotify(isFromBackground: false);
  }

  // Internal helpers
  static Future<void> _ensureDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kNotificationsEnabled)) {
      await prefs.setBool(_kNotificationsEnabled, true);
    }
    if (!prefs.containsKey(_kCheckInterval)) {
      await prefs.setInt(_kCheckInterval, 30);
    }
    if (!prefs.containsKey(_kStockThreshold)) {
      await prefs.setInt(_kStockThreshold, 5);
    }
    if (!prefs.containsKey(_kExpiryDaysAhead)) {
      await prefs.setInt(_kExpiryDaysAhead, 30);
    }
    if (!prefs.containsKey(_kQuietStart)) {
      await prefs.setInt(_kQuietStart, 22);
    }
    if (!prefs.containsKey(_kQuietEnd)) {
      await prefs.setInt(_kQuietEnd, 7);
    }
    if (!prefs.containsKey(_kDailyEnabled)) {
      await prefs.setBool(_kDailyEnabled, true);
    }
    if (!prefs.containsKey(_kDailyHour)) {
      await prefs.setInt(_kDailyHour, 9);
    }
    if (!prefs.containsKey(_kDailyMinute)) {
      await prefs.setInt(_kDailyMinute, 0);
    }
  }

  static Future<void> _registerOrCancelBackgroundWork() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    final intervalMin = prefs.getInt(_kCheckInterval) ?? 30;

    // Cancel existing first to apply changes
    try {
      await Workmanager().cancelByUniqueName(_workUniqueName);
    } catch (_) {}

    if (!enabled) {
      _cachedBgRunning = false;
      await prefs.setBool(_kBgRunning, false);
      return;
    }

    // Workmanager minimum periodic interval on Android is 15 minutes
    final effectiveMinutes = max(15, intervalMin);

    // Initialize workmanager
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
    } catch (_) {
      // Already initialized
    }

    try {
      await Workmanager().registerPeriodicTask(
        _workUniqueName,
        _workTag,
        frequency: Duration(minutes: effectiveMinutes),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        initialDelay: Duration(minutes: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
        tag: _workTag,
      );
      _cachedBgRunning = true;
      await prefs.setBool(_kBgRunning, true);
    } catch (e) {
      _cachedBgRunning = false;
      await prefs.setBool(_kBgRunning, false);
    }
  }

  static Future<void> _scheduleOrCancelDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kDailyEnabled) ?? true;

    // Cancel any previous daily schedule
    await _flnp.cancel(_dailyNotificationId);

    if (!enabled) return;

    final hour = prefs.getInt(_kDailyHour) ?? 9;
    final minute = prefs.getInt(_kDailyMinute) ?? 0;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelDailyId,
        'Daily Summary',
        channelDescription: 'Daily inventory summary reminders',
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.reminder,
        ticker: 'Daily Summary',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _flnp.zonedSchedule(
      _dailyNotificationId,
      'Daily Inventory Summary',
      'Tap to view today\'s inventory status',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily',
    );
  }

  static const int _dailyNotificationId = 1000;
  static const int _stockNotificationId = 1001;
  static const int _expiryNotificationId = 1002;

  static Future<void> _initNotificationsPluginIfNeeded() async {
    if (_notificationsInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Navigator.of(ctx).pushNamed('/notification-center', arguments: payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _notificationsInitialized = true;
  }

  // --- Compatibility helpers used by UI layers ---
  static Future<void> monitorAndTriggerCriticalAlerts(List<Map<String, dynamic>> drugsData) async {
    await _initNotificationsPluginIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    final enabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    if (!enabled) return;

    final threshold = prefs.getInt(_kStockThreshold) ?? 5;
    final daysAhead = prefs.getInt(_kExpiryDaysAhead) ?? 30;
    final quietStart = prefs.getInt(_kQuietStart) ?? 22;
    final quietEnd = prefs.getInt(_kQuietEnd) ?? 7;

    final now = DateTime.now();
    final inQuiet = _isWithinQuietHours(quietStart, quietEnd, now);

    List<DrugModel> models = drugsData.map((m) {
      return DrugModel(
        id: m['id'] as int?,
        name: (m['name'] ?? '') as String,
        stock: (m['stock'] ?? 0) as int,
        expiryDate: (m['expiryDate'] ?? m['expiry_date'] ?? '') as String,
        imageUrl: (m['imageUrl'] ?? m['image_url'] ?? '') as String,
      );
    }).toList();

    final lowStock = models.where((d) => d.stock < threshold).toList();
    final urgentLow = lowStock.where((d) => d.stock <= 0).toList();
    final nonUrgentLow = lowStock.where((d) => d.stock > 0).toList();

    bool isExpiringSoon(DrugModel d) {
      final dt = DateTime.tryParse(d.expiryDate);
      if (dt == null) return false;
      final diff = dt.difference(now).inDays;
      return diff >= 0 && diff <= daysAhead;
    }

    final expiring = models.where(isExpiringSoon).toList();

    if (urgentLow.isNotEmpty) {
      await _showStockNotification(urgentLow, isUrgent: true);
    }
    if (!inQuiet) {
      if (nonUrgentLow.isNotEmpty) {
        await _showStockNotification(nonUrgentLow, isUrgent: false);
      }
      if (expiring.isNotEmpty) {
        await _showExpiryNotification(expiring);
      }
    }
  }

  static Future<void> updateDrugsList(List<Map<String, dynamic>> drugsData) async {
    // No persistent cache required for now; method exists to satisfy callers.
    // Could store lightweight metrics if needed in the future.
    return;
  }

  static Future<void> showTestNotification() async {
    await _initNotificationsPluginIfNeeded();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelDailyId,
        'General',
        channelDescription: 'General notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _flnp.show(
      9999,
      'Test Notification',
      'Notifications are working',
      details,
      payload: 'test',
    );
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // No-op in background; app will route on foreground open via payload
  }

  static Future<void> _requestPlatformPermissions() async {
    // Android 13+ explicit notification permission
    try {
      final androidImpl = _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  static Future<void> _ensureTimezoneInit() async {
    if (_timezoneInitialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(tz.local.name));
    _timezoneInitialized = true;
  }

  static Future<void> _backgroundEnsureSupabase() async {
    // Ensure Supabase is initialized if needed (background isolate)
    try {
      // If already initialized, a second call may throw; ignore
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_kSupabaseUrl);
      final key = prefs.getString(_kSupabaseKey);
      if (url != null && key != null) {
        if (!_isSupabaseReady()) {
          await Supabase.initialize(url: url, anonKey: key);
        }
      }
    } catch (_) {}
  }

  static bool _isSupabaseReady() {
    try {
      // Accessing instance may throw if not initialized
      Supabase.instance.client; // ignore: unnecessary_statements
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isWithinQuietHours(int startHour, int endHour, DateTime now) {
    if (startHour == endHour) return true; // 24h quiet
    if (startHour < endHour) {
      // Same day window, e.g., 22->7 is false here
      return now.hour >= startHour && now.hour < endHour;
    } else {
      // Overnight window, e.g., 22->7
      return now.hour >= startHour || now.hour < endHour;
    }
  }

  static Future<void> _performCheckAndNotify({required bool isFromBackground}) async {
    await _initNotificationsPluginIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    final enabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    if (!enabled) return;

    final threshold = prefs.getInt(_kStockThreshold) ?? 5;
    final daysAhead = prefs.getInt(_kExpiryDaysAhead) ?? 30;
    final quietStart = prefs.getInt(_kQuietStart) ?? 22;
    final quietEnd = prefs.getInt(_kQuietEnd) ?? 7;

    // Quiet hours suppress non-urgent alerts
    final now = DateTime.now();
    final inQuiet = _isWithinQuietHours(quietStart, quietEnd, now);

    // Fetch data via repository (requires Supabase initialized)
    final repo = DrugsRepository();
    List<DrugModel> lowStock = [];
    List<DrugModel> expiring = [];
    try {
      lowStock = await repo.getLowStockDrugs(threshold);
    } catch (_) {}

    try {
      expiring = await repo.getDrugsExpiringSoon(daysAhead);
    } catch (_) {}

    // Filter urgent vs non-urgent
    final urgentLow = lowStock.where((d) => d.stock <= 0).toList();
    final nonUrgentLow = lowStock.where((d) => d.stock > 0).toList();

    // Show notifications
    if (urgentLow.isNotEmpty) {
      await _showStockNotification(urgentLow, isUrgent: true);
    }

    if (!inQuiet) {
      if (nonUrgentLow.isNotEmpty) {
        await _showStockNotification(nonUrgentLow, isUrgent: false);
      }
      if (expiring.isNotEmpty) {
        await _showExpiryNotification(expiring);
      }
    }
  }

  static Future<void> _showStockNotification(List<DrugModel> drugs, {required bool isUrgent}) async {
    final count = drugs.length;
    final topNames = drugs.take(3).map((d) => d.name).join(', ');

    final android = AndroidNotificationDetails(
      _channelStockId,
      'Stock Alerts',
      channelDescription: 'Alerts for low or out-of-stock drugs',
      importance: isUrgent ? Importance.max : Importance.high,
      priority: isUrgent ? Priority.max : Priority.high,
      category: AndroidNotificationCategory.alarm,
      styleInformation: InboxStyleInformation(
        drugs.take(5).map((d) => '${d.name} — stock: ${d.stock}').toList(),
        summaryText: count > 1 ? '+${count - 1} more' : null,
      ),
      ticker: 'Stock Alerts',
    );

    final ios = const DarwinNotificationDetails();

    await _flnp.show(
      _stockNotificationId,
      isUrgent ? 'Critical: ${count} item(s) out of stock' : 'Low stock: ${count} item(s)',
      count == 1 ? '${drugs.first.name} — stock: ${drugs.first.stock}' : topNames,
      NotificationDetails(android: android, iOS: ios),
      payload: 'low_stock',
    );
  }

  static Future<void> _showExpiryNotification(List<DrugModel> drugs) async {
    final count = drugs.length;
    String computeDays(String expiryIso) {
      final dt = DateTime.tryParse(expiryIso);
      if (dt == null) return '';
      final days = dt.difference(DateTime.now()).inDays;
      return days >= 0 ? '$days day${days == 1 ? '' : 's'}' : 'expired';
    }

    final android = AndroidNotificationDetails(
      _channelExpiryId,
      'Expiry Alerts',
      channelDescription: 'Alerts for drugs expiring soon',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: InboxStyleInformation(
        drugs.take(5).map((d) => '${d.name} — in ${computeDays(d.expiryDate)}').toList(),
        summaryText: count > 1 ? '+${count - 1} more' : null,
      ),
      ticker: 'Expiry Alerts',
    );

    final ios = const DarwinNotificationDetails();

    await _flnp.show(
      _expiryNotificationId,
      'Expiring soon: ${count} item(s)',
      count == 1 ? '${drugs.first.name} — in ${computeDays(drugs.first.expiryDate)}' : drugs.take(3).map((d) => d.name).join(', '),
      NotificationDetails(android: android, iOS: ios),
      payload: 'expiry',
    );
  }
}
