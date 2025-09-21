import 'package:flutter/material.dart';
import '../../core/utils/notifications_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Notification settings variables
  bool _notificationsEnabled = true;
  int _checkInterval = 30; // minutes
  int _stockThreshold = 5;
  int _expiryDaysAhead = 30;
  int _quietHoursStart = 22; // 10 PM
  int _quietHoursEnd = 7; // 7 AM
  bool _dailyReminderEnabled = true;
  int _dailyReminderHour = 9; // 9 AM

  // Dropdown options
  final List<int> _intervalOptions = [5, 10, 15, 30, 45, 60, 120, 180]; // minutes
  final List<int> _stockThresholdOptions = [1, 2, 3, 5, 10, 15, 20, 25];
  final List<int> _expiryDaysOptions = [7, 14, 21, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      final settings = await NotificationsService.getNotificationSettings();

      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] as bool;
        _checkInterval = settings['checkInterval'] as int;
        _stockThreshold = settings['stockThreshold'] as int;
        _expiryDaysAhead = settings['expiryDaysAhead'] as int;
        _quietHoursStart = settings['quietHoursStart'] as int;
        _quietHoursEnd = settings['quietHoursEnd'] as int;
        _dailyReminderEnabled = settings['dailyReminderEnabled'] as bool;
        _dailyReminderHour = settings['dailyReminderHour'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isSaving = true);

      await NotificationsService.updateNotificationSettings(
        notificationsEnabled: _notificationsEnabled,
        checkInterval: _checkInterval,
        stockThreshold: _stockThreshold,
        expiryDaysAhead: _expiryDaysAhead,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
        dailyReminderEnabled: _dailyReminderEnabled,
        dailyReminderHour: _dailyReminderHour,
      );

      setState(() => _isSaving = false);
      _showSuccessSnackBar('Settings saved successfully!');
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to save settings: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:00 $period';
  }

  Future<void> _testNotifications() async {
    try {
      await NotificationsService.forceBackgroundCheck();
      _showSuccessSnackBar('Test notification check completed!');
    } catch (e) {
      _showErrorSnackBar('Failed to test notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main toggle
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'General Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Notifications'),
                            subtitle: const Text('Turn on/off all background notifications'),
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timing settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Timing Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Check interval
                          ListTile(
                            title: const Text('Check Interval'),
                            subtitle: Text('Check for issues every ${_checkInterval} minutes'),
                            trailing: DropdownButton<int>(
                              value: _checkInterval,
                              items: _intervalOptions.map((interval) {
                                return DropdownMenuItem(
                                  value: interval,
                                  child: Text('${interval}min'),
                                );
                              }).toList(),
                              onChanged: _notificationsEnabled ? (value) {
                                if (value != null) {
                                  setState(() => _checkInterval = value);
                                }
                              } : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stock settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Stock Alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            title: const Text('Low Stock Threshold'),
                            subtitle: Text('Alert when stock reaches ${_stockThreshold} units or below'),
                            trailing: DropdownButton<int>(
                              value: _stockThreshold,
                              items: _stockThresholdOptions.map((threshold) {
                                return DropdownMenuItem(
                                  value: threshold,
                                  child: Text('${threshold} units'),
                                );
                              }).toList(),
                              onChanged: _notificationsEnabled ? (value) {
                                if (value != null) {
                                  setState(() => _stockThreshold = value);
                                }
                              } : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Expiry settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_busy,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Expiry Alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            title: const Text('Expiry Warning Period'),
                            subtitle: Text('Alert ${_expiryDaysAhead} days before expiry'),
                            trailing: DropdownButton<int>(
                              value: _expiryDaysAhead,
                              items: _expiryDaysOptions.map((days) {
                                return DropdownMenuItem(
                                  value: days,
                                  child: Text('${days} days'),
                                );
                              }).toList(),
                              onChanged: _notificationsEnabled ? (value) {
                                if (value != null) {
                                  setState(() => _expiryDaysAhead = value);
                                }
                              } : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quiet hours settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bedtime,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Quiet Hours',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Suppress non-urgent notifications during these hours',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: const Text('Start Time'),
                                  subtitle: Text(_formatHour(_quietHoursStart)),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: _notificationsEnabled ? () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: _quietHoursStart, minute: 0),
                                    );
                                    if (time != null) {
                                      setState(() => _quietHoursStart = time.hour);
                                    }
                                  } : null,
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: const Text('End Time'),
                                  subtitle: Text(_formatHour(_quietHoursEnd)),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: _notificationsEnabled ? () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: _quietHoursEnd, minute: 0),
                                    );
                                    if (time != null) {
                                      setState(() => _quietHoursEnd = time.hour);
                                    }
                                  } : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Daily reminder settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.today,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Daily Reminders',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          SwitchListTile(
                            title: const Text('Enable Daily Reminders'),
                            subtitle: const Text('Get daily inventory summaries'),
                            value: _dailyReminderEnabled,
                            onChanged: _notificationsEnabled ? (value) {
                              setState(() => _dailyReminderEnabled = value);
                            } : null,
                          ),

                          if (_dailyReminderEnabled)
                            ListTile(
                              title: const Text('Reminder Time'),
                              subtitle: Text('Daily reminder at ${_formatHour(_dailyReminderHour)}'),
                              trailing: const Icon(Icons.access_time),
                              onTap: _notificationsEnabled ? () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: _dailyReminderHour, minute: 0),
                                );
                                if (time != null) {
                                  setState(() => _dailyReminderHour = time.hour);
                                }
                              } : null,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Service status and test
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Service Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Icon(
                                NotificationsService.isBackgroundServiceRunning()
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: NotificationsService.isBackgroundServiceRunning()
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                NotificationsService.isBackgroundServiceRunning()
                                    ? 'Background service is running'
                                    : 'Background service is stopped',
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _testNotifications,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Test Notifications'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
