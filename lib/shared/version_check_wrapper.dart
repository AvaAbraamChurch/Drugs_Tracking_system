import 'package:flutter/material.dart';
import '../core/utils/version_check_service.dart';

class VersionCheckWrapper extends StatefulWidget {
  final Widget child;

  const VersionCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  @override
  void initState() {
    super.initState();
    // Perform version check after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performVersionCheck();
    });
  }

  Future<void> _performVersionCheck() async {
    try {
      await VersionCheckService.performVersionCheck(context);
    } catch (e) {
      print('Error performing version check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
