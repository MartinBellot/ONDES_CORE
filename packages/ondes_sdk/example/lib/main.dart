import 'package:flutter/material.dart';
import 'package:ondes_sdk/ondes_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wait for the Ondes bridge to be ready
  try {
    await Ondes.ensureReady();
    print('✅ Ondes SDK ready!');
  } catch (e) {
    print('⚠️ Running outside Ondes Core host: $e');
  }

  runApp(const OndesExampleApp());
}

class OndesExampleApp extends StatelessWidget {
  const OndesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ondes SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Loading...';
  UserProfile? _profile;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!Ondes.isReady) {
      setState(() => _status = 'Not running in Ondes Core host');
      return;
    }

    // Configure app bar
    await Ondes.ui.configureAppBar(
      title: 'SDK Example',
      backgroundColor: '#2196F3',
      foregroundColor: '#FFFFFF',
    );

    // Get user profile
    final profile = await Ondes.user.getProfile();
    setState(() {
      _profile = profile;
      _status = profile != null ? 'Logged in as ${profile.username}' : 'Not logged in';
    });

    // Load feed
    if (await Ondes.user.isAuthenticated()) {
      final posts = await Ondes.social.getFeed(limit: 10);
      setState(() => _posts = posts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ondes SDK Example :)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_profile != null) ...[
                      const SizedBox(height: 8),
                      Text('Email: ${_profile!.email ?? 'N/A'}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // UI Demo section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UI Module',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showToast(ToastType.success),
                          icon: const Icon(Icons.check),
                          label: const Text('Success Toast'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showToast(ToastType.error),
                          icon: const Icon(Icons.error),
                          label: const Text('Error Toast'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAlert,
                          icon: const Icon(Icons.info),
                          label: const Text('Alert'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showConfirm,
                          icon: const Icon(Icons.help),
                          label: const Text('Confirm'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showBottomSheet,
                          icon: const Icon(Icons.menu),
                          label: const Text('Bottom Sheet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Device Demo section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Module',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _haptic(HapticStyle.light),
                          icon: const Icon(Icons.vibration),
                          label: const Text('Light Haptic'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _haptic(HapticStyle.heavy),
                          icon: const Icon(Icons.vibration),
                          label: const Text('Heavy Haptic'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _scanQR,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _getLocation,
                          icon: const Icon(Icons.location_on),
                          label: const Text('GPS'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _getDeviceInfo,
                          icon: const Icon(Icons.phone_android),
                          label: const Text('Device Info'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Storage Demo section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Module',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveData,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Data'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.download),
                          label: const Text('Load Data'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _clearStorage,
                          icon: const Icon(Icons.delete),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Feed section
            if (_posts.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feed (${_posts.length} posts)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      ..._posts.take(5).map((post) => ListTile(
                            leading: CircleAvatar(
                              child: Text(post.author.username[0].toUpperCase()),
                            ),
                            title: Text(post.author.username),
                            subtitle: Text(
                              post.content.length > 50
                                  ? '${post.content.substring(0, 50)}...'
                                  : post.content,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  post.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text('${post.likesCount}'),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // UI handlers
  Future<void> _showToast(ToastType type) async {
    if (!Ondes.isReady) return;
    await Ondes.ui.showToast(
      message: 'This is a ${type.name} toast!',
      type: type,
    );
  }

  Future<void> _showAlert() async {
    if (!Ondes.isReady) return;
    await Ondes.ui.showAlert(
      title: 'Information',
      message: 'This is an alert dialog from the Ondes SDK!',
      buttonText: 'Got it',
    );
  }

  Future<void> _showConfirm() async {
    if (!Ondes.isReady) return;
    final confirmed = await Ondes.ui.showConfirm(
      title: 'Confirmation',
      message: 'Do you want to proceed?',
      confirmText: 'Yes',
      cancelText: 'No',
    );
    await Ondes.ui.showToast(
      message: confirmed ? 'You confirmed!' : 'You cancelled',
      type: confirmed ? ToastType.success : ToastType.info,
    );
  }

  Future<void> _showBottomSheet() async {
    if (!Ondes.isReady) return;
    final result = await Ondes.ui.showBottomSheet(
      title: 'Choose an action',
      items: [
        const BottomSheetItem(label: 'Edit', value: 'edit', icon: 'edit'),
        const BottomSheetItem(label: 'Share', value: 'share', icon: 'share'),
        const BottomSheetItem(label: 'Delete', value: 'delete', icon: 'delete'),
      ],
    );
    if (result != null) {
      await Ondes.ui.showToast(message: 'Selected: $result');
    }
  }

  // Device handlers
  Future<void> _haptic(HapticStyle style) async {
    if (!Ondes.isReady) return;
    await Ondes.device.hapticFeedback(style);
  }

  Future<void> _scanQR() async {
    if (!Ondes.isReady) return;
    try {
      final code = await Ondes.device.scanQRCode();
      await Ondes.ui.showAlert(
        title: 'QR Code Scanned',
        message: code,
      );
    } catch (e) {
      await Ondes.ui.showToast(
        message: 'Scan cancelled or failed',
        type: ToastType.error,
      );
    }
  }

  Future<void> _getLocation() async {
    if (!Ondes.isReady) return;
    try {
      final pos = await Ondes.device.getGPSPosition();
      await Ondes.ui.showAlert(
        title: 'Location',
        message: 'Lat: ${pos.latitude.toStringAsFixed(4)}\n'
            'Lon: ${pos.longitude.toStringAsFixed(4)}\n'
            'Accuracy: ${pos.accuracy.toStringAsFixed(1)}m',
      );
    } catch (e) {
      await Ondes.ui.showToast(
        message: 'Could not get location: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _getDeviceInfo() async {
    if (!Ondes.isReady) return;
    final info = await Ondes.device.getInfo();
    await Ondes.ui.showAlert(
      title: 'Device Info',
      message: 'Platform: ${info.platform}\n'
          'Screen: ${info.screenWidth.toInt()}x${info.screenHeight.toInt()}\n'
          'Dark mode: ${info.isDarkMode}',
    );
  }

  // Storage handlers
  Future<void> _saveData() async {
    if (!Ondes.isReady) return;
    await Ondes.storage.set('demo_data', {
      'timestamp': DateTime.now().toIso8601String(),
      'message': 'Hello from Ondes SDK!',
    });
    await Ondes.ui.showToast(message: 'Data saved!', type: ToastType.success);
  }

  Future<void> _loadData() async {
    if (!Ondes.isReady) return;
    final data = await Ondes.storage.get<Map<String, dynamic>>('demo_data');
    if (data != null) {
      await Ondes.ui.showAlert(
        title: 'Stored Data',
        message: 'Message: ${data['message']}\nSaved: ${data['timestamp']}',
      );
    } else {
      await Ondes.ui.showToast(message: 'No data found', type: ToastType.warning);
    }
  }

  Future<void> _clearStorage() async {
    if (!Ondes.isReady) return;
    await Ondes.storage.clear();
    await Ondes.ui.showToast(message: 'Storage cleared!', type: ToastType.success);
  }
}
