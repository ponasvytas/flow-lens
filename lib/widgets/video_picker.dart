import 'package:flutter/material.dart';
import '../models/sport_profile.dart';
import 'sport_profile_selector.dart';

/// Initial video loading screen with sport selection and file picker
class VideoPicker extends StatefulWidget {
  final VoidCallback onPickVideo;
  final VoidCallback onLoadTestVideo;
  final ValueChanged<String> onLoadUrl;
  final ValueChanged<SportProfile> onSportSelected;

  const VideoPicker({
    required this.onPickVideo,
    required this.onLoadTestVideo,
    required this.onLoadUrl,
    required this.onSportSelected,
    super.key,
  });

  @override
  State<VideoPicker> createState() => _VideoPickerState();
}

class _VideoPickerState extends State<VideoPicker> {
  final TextEditingController _urlController = TextEditingController();
  SportProfile? _selectedSport;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onSportSelected(SportProfile profile) {
    setState(() {
      _selectedSport = profile;
    });
    widget.onSportSelected(profile);
  }

  void _onBackToSportSelection() {
    setState(() {
      _selectedSport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSport == null) {
      return SportProfileSelector(
        onProfileSelected: _onSportSelected,
      );
    }

    return _buildVideoSelector(context);
  }

  Widget _buildVideoSelector(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _onBackToSportSelection,
                  tooltip: 'Change sport',
                ),
                const SizedBox(width: 8),
                Icon(
                  _selectedSport!.iconData,
                  color: const Color(0xFF753b8f),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedSport!.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onPickVideo,
              icon: const Icon(Icons.file_upload),
              label: const Text("Select Game Video"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onLoadTestVideo,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text("Load Demo Video"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "OR",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Video URL',
                hintText: 'https://example.com/video.mp4',
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: () {
                    if (_urlController.text.isNotEmpty) {
                      widget.onLoadUrl(_urlController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  widget.onLoadUrl(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
