import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shorebird_downloader/shorebird_downloader.dart';

final _shorebirdCodePush = ShorebirdCodePush();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color.fromARGB(255, 31, 74, 175),
        appBar: AppBar(
            title: Text(
          'Timetable with Slider',
          style: TextStyle(color: Colors.red),
        )),
        body: Timetable(),
      ),
    );
  }
}

class Timetable extends StatefulWidget {
  @override
  _TimetableState createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  double _columnWidth = 100.0; // Chiều rộng của mỗi cột

  @override
  Widget build(BuildContext context) {
    final heading = _currentPatchVersion != null
        ? '$_currentPatchVersion'
        : 'No patch installed';
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              // Slider để điều chỉnh chiều rộng của tất cả các cột
              Slider(
                value: _columnWidth,
                min: 50.0,
                max: 200.0,
                divisions: 15,
                label: _columnWidth.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    _columnWidth = value;
                  });
                },
              ),
              Text('Column Width: ${_columnWidth.round()}'),
              // Scrollable Timetable
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: List.generate(10, (rowIndex) {
                        return Row(
                          children: List.generate(20, (columnIndex) {
                            return Container(
                              width: _columnWidth,
                              margin: EdgeInsets.all(4.0),
                              color: Colors.blue[(columnIndex % 9 + 1) * 100],
                              child: Center(
                                  child:
                                      Text('Row $rowIndex Col $columnIndex')),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("status: $status"),
            const Text('Current patch version:'),
            Text(
              heading,
            ),
            const SizedBox(height: 20),
            if (!_isShorebirdAvailable)
              Text(
                'Shorebird Engine not available.',
              ),
            if (_isShorebirdAvailable)
              ElevatedButton(
                onPressed: _isCheckingForUpdate ? null : _checkForUpdate,
                child: _isCheckingForUpdate
                    ? const _LoadingIndicator()
                    : const Text('Check for update'),
              ),
          ],
        )
      ],
    );
  }

  String status = "";
  void checkDownload() {
    ShorebirdCheckDownloader(
      appid: "29405dbb-46c4-4ac3-8954-6ba9c682f636",
      onDownloadStart: () {
        setState(() {
          status = "onDownloadStart";
        });
        print(status);
      },
      onDownloadProgress: (count, total) {
        setState(() {
          status = "onDownloadProgress $count/$total";
        });
        print("onDownloadProgress $count/$total");
      },
      onDownloadComplete: () {
        setState(() {
          status = "onDownloadComplete";
        });
        print("done");
      },
    ).checkPatch();
    final downloader =
        ShorebirdUrlDownloader(appid: '29405dbb-46c4-4ac3-8954-6ba9c682f636');
    downloader.downloadPatch(
        progressCallback: (size, totol) => print("$size/$totol"));
  }

  final _isShorebirdAvailable = _shorebirdCodePush.isShorebirdAvailable();
  int? _currentPatchVersion;
  bool _isCheckingForUpdate = false;

  @override
  void initState() {
    super.initState();
    checkDownload();
    // Request the current patch number.
    _shorebirdCodePush.currentPatchNumber().then((currentPatchVersion) {
      if (!mounted) return;
      setState(() {
        _currentPatchVersion = currentPatchVersion;
      });
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
    });

    // Ask the Shorebird servers if there is a new patch available.
    final isUpdateAvailable =
        await _shorebirdCodePush.isNewPatchAvailableForDownload();

    if (!mounted) return;

    setState(() {
      _isCheckingForUpdate = false;
    });

    if (isUpdateAvailable) {
      _showUpdateAvailableBanner();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No update available'),
        ),
      );
    }
  }

  void _showDownloadingBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text('Downloading...'),
        actions: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateAvailableBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('Update available'),
        actions: [
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              await _downloadUpdate();

              if (!mounted) return;
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showRestartBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text('A new patch is ready!'),
        actions: [
          TextButton(
            // Restart the app for the new patch to take effect.
            onPressed: Restart.restartApp,
            child: Text('Restart app'),
          ),
        ],
      ),
    );
  }

  void _showErrorBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('An error occurred while downloading the update.'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  // Note: this is only run if an update is reported as available.
  // [isNewPatchReadyToInstall] returning false does not always indicate an
  // error with the download.
  Future<void> _downloadUpdate() async {
    _showDownloadingBanner();

    await Future.wait([
      _shorebirdCodePush.downloadUpdateIfAvailable(),
      // Add an artificial delay so the banner has enough time to animate in.
      Future<void>.delayed(const Duration(milliseconds: 250)),
    ]);

    final isUpdateReadyToInstall =
        await _shorebirdCodePush.isNewPatchReadyToInstall();

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    if (isUpdateReadyToInstall) {
      _showRestartBanner();
    } else {
      _showErrorBanner();
    }
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 14,
      width: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
