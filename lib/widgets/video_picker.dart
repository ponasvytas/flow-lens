import 'package:flutter/material.dart';

/// Initial video loading screen with file picker and test video options
class VideoPicker extends StatelessWidget {
  final VoidCallback onPickVideo;
  final VoidCallback onLoadTestVideo;

  const VideoPicker({
    required this.onPickVideo,
    required this.onLoadTestVideo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onPickVideo,
            child: const Text("Select Game Video"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onLoadTestVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text("Load Test Video (URL)"),
          ),
        ],
      ),
    );
  }
}
