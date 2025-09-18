import 'package:flutter/material.dart';

import 'colors.dart';

ThemeData theme = ThemeData(
  colorSchemeSeed: primaryColor,
  scaffoldBackgroundColor: backgroundColor,
  fontFamily: 'Alexandria',
  appBarTheme: AppBarTheme(
    titleSpacing: 20.0,
    backgroundColor: primaryColor,
    elevation: 0.0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      fontFamily: 'Alexandria',
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    selectedItemColor: secondaryColor,
    unselectedItemColor: Colors.grey,
    backgroundColor: secondaryBackgroundColor,
    elevation: 20.0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: secondaryBackgroundColor,
    shape: CircleBorder(),
  ),
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
  ),
);