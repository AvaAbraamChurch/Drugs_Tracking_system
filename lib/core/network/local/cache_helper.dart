// import 'package:shared_preferences/shared_preferences.dart';
//
// class CacheHelper {
//   static SharedPreferences? sharedPreferences;
//
//   static init() async {
//     sharedPreferences = await SharedPreferences.getInstance();
//   }
//
//   static Future<bool> putBoolean({
//     required String key,
//     required bool value,
//   }) async {
//     return await sharedPreferences!.setBool(key, value);
//   }
//
//   static bool? getBoolean({
//     required String key,
//   })  {
//     return sharedPreferences!.getBool(key);
//   }
//
//   static Future<bool> saveData(
//   {
//     required String key,
//     required dynamic value,
//   }) async {
//     if (value is String) return await sharedPreferences!.setString(key, value);
//     if (value is double) return await sharedPreferences!.setDouble(key, value);
//     if (value is int) return await sharedPreferences!.setInt(key, value);
//     return await sharedPreferences!.setBool(key, value);
//   }
//
//   static dynamic getData({
//     required String key,
//   }) {
//     return sharedPreferences!.get(key);
//   }
//
//   static Future<bool> removeData({
//     required String key,
//   }) async {
//     return await sharedPreferences!.remove(key);
//   }
//
//   static Future<bool> removeAllData() async {
//     return await sharedPreferences!.clear();
//   }
//
// }
