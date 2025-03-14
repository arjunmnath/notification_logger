import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  bool _loading = false; // Start as not loading
  Timer? _refreshTimer;
  String __path__ = "not initialized";

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadNotifications(); // Initial load

    // Set up a timer to periodically refresh the notifications
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_loading) { // Only refresh if not already loading
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkServiceStatus() async {
    try {
      final bool result = await platform.invokeMethod('isServiceEnabled');
      if (mounted) {
        setState(() {
          _serviceEnabled = result;
        });
      }
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
        try {
          final directory = await getApplicationDocumentsDirectory();
          final androidFilesDir = directory.path.replaceFirst('app_flutter', 'files');
          file = File('$androidFilesDir/notifications.json');
          if (await file.exists()) {
            return file;
          }
        } catch (e) {
          print("Error checking Android file: $e");
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
    // Set loading flag and check if widget is still mounted
    if (_loading || !mounted) return;

    setState(() {
      _loading = true;
    });
    if (Platform.isAndroid) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String androidPath = directory.path.replaceFirst('app_flutter', 'files');
        __path__ = androidPath;
        final File androidFile = File('$androidPath/notifications.json');
        if (await androidFile.exists()) {
          final String contents = await androidFile.readAsString();
          if (contents.isNotEmpty) {
            try {
              final List<dynamic> jsonList = jsonDecode(contents);
              if (mounted) {
                setState(() {
                  _notifications = jsonList.cast<Map<String, dynamic>>();
                  _loading = false;
                });
              }
              return;
            } catch (e) {
              print("Error parsing Android JSON: $e");
            }
          }
        }
      } catch (e) {
        print("Error reading Android file: $e");
      }
    }

    try {
      final file = await _localFile;
      if (file != null && await file.exists()) {
        final String contents = await file.readAsString();
        if (contents.isNotEmpty) {
          try {
            final List<dynamic> jsonList = jsonDecode(contents);
            if (mounted) {
              setState(() {
                _notifications = jsonList.cast<Map<String, dynamic>>();
                _loading = false;
              });
            }
            return;
          } catch (e) {
            print("Error parsing JSON: $e");
          }
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      print("Error loading notifications: $e");
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

      if (mounted) {
        setState(() {
          _notifications = [];
        });
      }
    } catch (e) {
      print("Error clearing notifications: $e");
    }
  }

  Future<void> _exportNotifications() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final file = File('${directory.path}/notifications_export.json');
        await file.writeAsString(jsonEncode(_notifications));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to ${file.path}')),
          );
        }
      }
    } catch (e) {
      print("Error exporting notifications: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export notifications')),
        );
      }
    }
  }

  void _copyToClipboard(Map<String, dynamic> notification) {
    final text = '''
Title: ${notification['title'] ?? 'No title'}
Content: ${notification['text'] ?? 'No content'}
Expanded: ${notification['expandedText'] ?? 'None'}
App: ${notification['packageName']}
Time: ${notification['timestamp']}
''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Logger'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadNotifications,
            tooltip: 'Refresh notifications',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _notifications.isEmpty ? null : _exportNotifications,
            tooltip: 'Export notifications',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _notifications.isEmpty ? null : _clearNotifications,
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
          Text(__path__),
          Expanded(
            child: _notifications.isEmpty
                ? const Center(child: Text('No notifications logged yet'))
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[_notifications.length - 1 - index];

                final bool hasExpandedContent =
                    notification['hasExpandedContent'] == true ||
                        (notification['expandedText']?.toString().isNotEmpty == true &&
                            notification['expandedText'] != notification['text']);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    title: Text(
                      notification['title'] ?? 'No title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['text'] ?? 'No content'),
                        Text(
                          'App: ${notification['packageName']} • ${notification['timestamp']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (hasExpandedContent)
                          Text(
                            'Expanded content available',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    children: [
                      if (notification['expandedText']?.toString().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expanded Content:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification['expandedText'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.content_copy),
                              label: const Text('Copy'),
                              onPressed: () => _copyToClipboard(notification),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              onPressed: () {
                                // Implement share functionality if needed
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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