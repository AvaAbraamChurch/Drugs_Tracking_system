import 'dart:io';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pharmanow/core/Blocs/home%20cubit/home_cubit.dart';
import 'package:pharmanow/core/styles/theme.dart';
import 'package:pharmanow/modules/home/home_screen.dart';
import 'package:pharmanow/modules/notifications/notification_center_screen.dart';
import 'package:pharmanow/modules/notifications/notification_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/bloc_observer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/utils/notifications_service.dart';
import 'core/services/supabase_image_service.dart';
import 'package:path_provider/path_provider.dart';
import 'shared/version_check_wrapper.dart';


// Use the navigator key from NotificationsService
final GlobalKey<NavigatorState> navigatorKey = NotificationsService.navigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Access environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseKey = dotenv.env['SUPABASE_KEY']!;

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // Initialize NotificationsService with WorkManager for background processing
  try {
    await NotificationsService.initialize();

    print('✅ NotificationsService initialized successfully');
  } catch (e) {
    print('❌ Error initializing NotificationsService: $e');
  }

  // Initialize Supabase image service
  await SupabaseImageService.initialize();


  // await Hive.initFlutter();

  await clearOldCache();

  Bloc.observer = MyBlocObserver();

  Widget widget;

  widget = HomeScreen();

  //
  // if (uId.isNotEmpty || isLoggedIn) {
  //   widget = MainLayout();
  // }else{
  //   widget = LoginScreen();
  // }

  runApp(MyApp(
    startWidget: widget,
  ));

}

class MyApp extends StatelessWidget {


  final Widget startWidget;

  const MyApp({super.key, required this.startWidget});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => HomeCubit()..getDrugs(),
      child: MaterialApp(
        navigatorKey: navigatorKey, // This now uses the NotificationsService navigator key
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'),
        ],
        debugShowCheckedModeBanner: false,

        theme: theme,
        routes: {
          '/notification-center': (context) {
            final payload = ModalRoute.of(context)?.settings.arguments as String?;
            return NotificationCenterScreen(notificationPayload: payload);
          },
          '/notification-settings': (context) => const NotificationSettingsScreen(),
        },
        home: AnimatedSplashScreen(
          splash: Image.asset('assets/images/PharmaNow.webp',width: 500,height: 500,),
          duration: 3000,
          splashTransition: SplashTransition.scaleTransition,
          backgroundColor: Colors.white,
          nextScreen: VersionCheckWrapper(child: startWidget),
        ),
      ),
    );
  }
}

Future<void> clearOldCache() async {
  try {
    final dir = await getTemporaryDirectory();
    final size = await _getFolderSize(dir);

    if (size > 10 * 1024 * 1024) { // 10MB threshold
      final files = dir.listSync();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        } else if (file is Directory) {
          await file.delete(recursive: true);
        }
      }
      print('Cache cleared successfully');
    }
  } catch (e) {
    print('Error clearing cache: $e');
  }
}

// Helper function to calculate folder size
Future<int> _getFolderSize(Directory dir) async {
  var size = 0;
  try {
    final files = dir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        size += await file.length();
      }
    }
  } catch (e) {
    print('Error calculating folder size: $e');
  }
  return size;
}
