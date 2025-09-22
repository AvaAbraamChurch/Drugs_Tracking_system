import 'package:flutter/material.dart';
import 'package:pharmanow/core/styles/colors.dart';
import 'package:pharmanow/shared/widgets.dart';

import '../../core/utils/notifications_service.dart';
import '../notifications/notification_center_screen.dart';
import '../notifications/notification_settings_screen.dart';

class EndDrawer extends StatelessWidget {
  const EndDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage('assets/images/PHARMANOW.png'),
                ),
                SizedBox(height: 12),
                Text(
                  'PharmaNow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.notifications_active, color: primaryColor,),
            title: Text('Notifications'),
            onTap: () {
              navigateTo(context, NotificationCenterScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.notification_important, color: primaryColor,),
            title: Text('Test Notification'),
            onTap: () async {
              // Call the notification service to show a test notification
              // Replace with your actual notification service method
              try {
                await NotificationsService.showTestNotification();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to show notification: $e')));
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: primaryColor,),
            title: Text('Notifications Settings'),
            onTap: () {
              navigateTo(context, NotificationSettingsScreen());
            },
          ),
        ],
      ),
    );
  }
}
