import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const NotificationLoggerApp());
}

class NotificationLoggerApp extends StatelessWidget {
  const NotificationLoggerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Logger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NotificationLoggerHome(),
    );
  }
}

class NotificationLoggerHome extends StatefulWidget {
  const NotificationLoggerHome({Key? key}) : super(key: key);

  @override
  State<NotificationLoggerHome> createState() => _NotificationLoggerHomeState();
}

class _NotificationLoggerHomeState extends State<NotificationLoggerHome> {
  static const platform = MethodChannel('com.example.notification_logger/service');
  bool _serviceEnabled = false;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadNotifications();

    // Set up a timer to periodically refresh the notifications
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      final bool result = await platform.invokeMethod('isServiceEnabled');
      setState(() {
        _serviceEnabled = result;
      });
    } on PlatformException catch (e) {
      print("Failed to check service status: ${e.message}");
    }
  }

  Future<void> _toggleService() async {
    try {
      if (!_serviceEnabled) {
        await platform.invokeMethod('requestPermission');
      } else {
        await platform.invokeMethod('disableService');
      }
      await _checkServiceStatus();
    } on PlatformException catch (e) {
      print("Failed to toggle service: ${e.message}");
    }
  }

  Future<String> get _localPath async {
    try {
      // Try to get the app's files directory on Android
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print("Error getting local path: $e");
      return "";
    }
  }

  Future<File?> get _localFile async {
    try {
      final path = await _localPath;
      if (path.isEmpty) return null;

      // First try the app's documents directory
      File file = File('$path/notifications.json');
      if (await file.exists()) {
        return file;
      }

      // If that fails, try the Android-specific files directory
      if (Platform.isAndroid) {
        final directory = await getApplicationDocumentsDirectory();
        final androidFilesDir = directory.path.replaceFirst('app_flutter', 'files');
        file = File('$androidFilesDir/notifications.json');
        if (await file.exists()) {
          return file;
        }
      }

      // If all else fails, create the file in the documents directory
      return File('$path/notifications.json');
    } catch (e) {
      print("Error getting local file: $e");
      return null;
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
    });

    try {
      final file = await _localFile;
      if (file != null && await file.exists()) {
        final String contents = await file.readAsString();
        if (contents.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(contents);
          setState(() {
            _notifications = jsonList.cast<Map<String, dynamic>>();
            _loading = false;
          });
          return;
        }
      }

      // Also check Android native files directory
      if (Platform.isAndroid) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final String androidPath = directory.path.replaceFirst('app_flutter', 'files');
          final File androidFile = File('$androidPath/notifications.json');

          if (await androidFile.exists()) {
            final String contents = await androidFile.readAsString();
            if (contents.isNotEmpty) {
              final List<dynamic> jsonList = jsonDecode(contents);
              setState(() {
                _notifications = jsonList.cast<Map<String, dynamic>>();
                _loading = false;
              });
              return;
            }
          }
        } catch (e) {
          print("Error reading Android file: $e");
        }
      }

      setState(() {
        _notifications = [];
        _loading = false;
      });
    } catch (e) {
      print("Error loading notifications: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _clearNotifications() async {
    try {
      final file = await _localFile;
      if (file != null) {
        await file.writeAsString(jsonEncode([]));
      }

      // Also clear Android native files directory
      if (Platform.isAndroid) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final String androidPath = directory.path.replaceFirst('app_flutter', 'files');
          final File androidFile = File('$androidPath/notifications.json');

          if (await androidFile.exists()) {
            await androidFile.writeAsString(jsonEncode([]));
          }
        } catch (e) {
          print("Error clearing Android file: $e");
        }
      }

      await _loadNotifications();
    } catch (e) {
      print("Error clearing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Logger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh notifications',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearNotifications,
            tooltip: 'Clear all notifications',
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Notification Listener Service'),
            subtitle: Text(_serviceEnabled ? 'Enabled' : 'Disabled'),
            trailing: Switch(
              value: _serviceEnabled,
              onChanged: (value) => _toggleService(),
            ),
          ),
          const Divider(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(child: Text('No notifications logged yet'))
                  : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[_notifications.length - 1 - index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(notification['title'] ?? 'No title'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['text'] ?? 'No content'),
                          Text(
                            'App: ${notification['packageName']} • ${notification['timestamp']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}