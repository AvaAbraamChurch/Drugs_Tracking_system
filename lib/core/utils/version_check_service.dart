import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';

class VersionCheckService {
  static const String _githubApiUrl = 'https://api.github.com/repos';
  static const String _lastCheckedKey = 'last_version_check';
  static const String _skipVersionKey = 'skip_version_';

  // Use configuration from AppConfig
  static const String _githubUsername = AppConfig.githubUsername;
  static const String _repositoryName = AppConfig.repositoryName;

  /// Checks if the current app version is the latest available on GitHub
  static Future<bool> isLatestVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final latestVersion = await _getLatestVersionFromGitHub();
      if (latestVersion == null) {
        return true; // Assume latest if we can't check
      }

      return _compareVersions(currentVersion, latestVersion) >= 0;
    } catch (e) {
      print('Error checking version: $e');
      return true; // Assume latest if error occurs
    }
  }

  /// Gets the latest release version from GitHub API
  static Future<String?> _getLatestVersionFromGitHub() async {
    try {
      final url = '$_githubApiUrl/$_githubUsername/$_repositoryName/releases/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String tagName = (data['tag_name'] as String).trim();

        // Remove 'v' prefix if present (e.g., 'v1.0.0' -> '1.0.0')
        if (tagName.startsWith('v')) {
          tagName = tagName.substring(1);
        }

        return tagName;
      } else {
        print('Failed to fetch latest version: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching latest version: $e');
      return null;
    }
  }

  /// Compares two version strings
  /// Returns: 1 if version1 > version2, -1 if version1 < version2, 0 if equal
  static int _compareVersions(String version1, String version2) {
    List<int> parse(String v) {
      // Handle pre-release/build metadata e.g., 1.0.0-beta+001 by parsing leading digits of each part
      final parts = v.split('.');
      return parts.map((p) {
        final m = RegExp(r'^(\d+)').firstMatch(p.trim());
        return m != null ? int.parse(m.group(1)!) : 0;
      }).toList();
    }

    final v1Parts = parse(version1);
    final v2Parts = parse(version2);

    final maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }

    return 0;
  }

  /// Checks if we should show version update dialog
  static Future<bool> shouldCheckVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getInt(_lastCheckedKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check once per day (24 hours = 86400000 milliseconds)
    return now - lastChecked > 86400000;
  }

  /// Records that we've checked the version
  static Future<void> recordVersionCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Checks if user has chosen to skip this version
  static Future<bool> hasSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_skipVersionKey$version') ?? false;
  }

  /// Records that user wants to skip this version
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_skipVersionKey$version', true);
  }

  /// Shows update available dialog
  static Future<void> showUpdateDialog(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final latestVersion = await _getLatestVersionFromGitHub();

      if (latestVersion == null) return;

      final isLatest = _compareVersions(currentVersion, latestVersion) >= 0;
      if (isLatest) return;

      // Check if user has skipped this version
      if (await hasSkippedVersion(latestVersion)) return;

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Update Available'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A new version of PharmaNow is available!'),
                  const SizedBox(height: 8),
                  Text('Current version: $currentVersion'),
                  Text('Latest version: $latestVersion'),
                  const SizedBox(height: 16),
                  const Text('Please update to get the latest features and bug fixes.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await skipVersion(latestVersion);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Skip This Version'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Remind Me Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openGitHubReleases();
                  },
                  child: const Text('Update Now'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error showing update dialog: $e');
    }
  }

  /// Opens GitHub releases page in browser
  static void _openGitHubReleases() async {
    try {
      final url = Uri.parse('https://github.com/$_githubUsername/$_repositoryName/releases');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $url');
      }
    } catch (e) {
      print('Error opening GitHub releases: $e');
    }
  }

  /// Performs version check and shows dialog if needed
  static Future<void> performVersionCheck(BuildContext context) async {
    if (!(await shouldCheckVersion())) return;

    await recordVersionCheck();

    if (!(await isLatestVersion())) {
      await showUpdateDialog(context);
    }
  }
}
