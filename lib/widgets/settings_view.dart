import 'package:flutter/material.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatefulWidget {
  final SettingsController controller;

  const SettingsView({
    required this.controller,
    super.key,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late double _fastPlaySpeed;
  late double _slowPlaybackSpeed;
  late double _defaultPlaybackSpeed;
  late int _leadInSeconds;
  late int _leadOutSeconds;

  @override
  void initState() {
    super.initState();
    _fastPlaySpeed = widget.controller.settings.fastPlaySpeed;
    _slowPlaybackSpeed = widget.controller.settings.slowPlaybackSpeed;
    _defaultPlaybackSpeed = widget.controller.settings.defaultPlaybackSpeed;
    _leadInSeconds = widget.controller.settings.leadIn.inSeconds;
    _leadOutSeconds = widget.controller.settings.leadOut.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        const Divider(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlaybackSection(),
                const SizedBox(height: 32),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Dialog(
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: content,
        ),
      );
    } else {
      return Scaffold(
        body: SafeArea(child: content),
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.settings, size: 28),
          const SizedBox(width: 12),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playback',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 16),
        _buildDefaultPlaybackSpeedControl(),
        const SizedBox(height: 24),
        _buildSlowPlaybackSpeedControl(),
        const SizedBox(height: 24),
        _buildFastPlaySpeedControl(),
        const SizedBox(height: 24),
        _buildLeadInControl(),
        const SizedBox(height: 24),
        _buildLeadOutControl(),
      ],
    );
  }

  Widget _buildDefaultPlaybackSpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Default playback speed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${_defaultPlaybackSpeed.toStringAsFixed(2)}x',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Initial playback speed when video loads (press 'D' key)",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _defaultPlaybackSpeed,
          min: 0.5,
          max: 3.0,
          divisions: 50,
          label: '${_defaultPlaybackSpeed.toStringAsFixed(2)}x',
          onChanged: (value) {
            setState(() {
              _defaultPlaybackSpeed = value;
            });
          },
          onChangeEnd: (value) {
            widget.controller.setDefaultPlaybackSpeed(value);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            _buildDefaultSpeedQuickPickButton(0.5),
            _buildDefaultSpeedQuickPickButton(0.75),
            _buildDefaultSpeedQuickPickButton(1.0),
            _buildDefaultSpeedQuickPickButton(1.5),
            _buildDefaultSpeedQuickPickButton(2.0),
            _buildDefaultSpeedQuickPickButton(3.0),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultSpeedQuickPickButton(double speed) {
    final isSelected = (_defaultPlaybackSpeed - speed).abs() < 0.01;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _defaultPlaybackSpeed = speed;
        });
        widget.controller.setDefaultPlaybackSpeed(speed);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade50 : null,
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Text('${speed.toStringAsFixed(2)}x'),
    );
  }

  Widget _buildSlowPlaybackSpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Slow playback speed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${_slowPlaybackSpeed.toStringAsFixed(2)}x',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Speed when pressing 'S' key",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _slowPlaybackSpeed,
          min: 0.25,
          max: 2.0,
          divisions: 70,
          label: '${_slowPlaybackSpeed.toStringAsFixed(2)}x',
          onChanged: (value) {
            setState(() {
              _slowPlaybackSpeed = value;
            });
          },
          onChangeEnd: (value) {
            widget.controller.setSlowPlaybackSpeed(value);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            _buildSlowSpeedQuickPickButton(0.25),
            _buildSlowSpeedQuickPickButton(0.33),
            _buildSlowSpeedQuickPickButton(0.5),
            _buildSlowSpeedQuickPickButton(0.75),
            _buildSlowSpeedQuickPickButton(1.0),
          ],
        ),
      ],
    );
  }

  Widget _buildSlowSpeedQuickPickButton(double speed) {
    final isSelected = (_slowPlaybackSpeed - speed).abs() < 0.01;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _slowPlaybackSpeed = speed;
        });
        widget.controller.setSlowPlaybackSpeed(speed);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade50 : null,
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Text('${speed.toStringAsFixed(2)}x'),
    );
  }

  Widget _buildFastPlaySpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Fast play speed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${_fastPlaySpeed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Speed when holding 'F' key",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _fastPlaySpeed,
          min: 1.5,
          max: 10.0,
          divisions: 17,
          label: '${_fastPlaySpeed.toStringAsFixed(1)}x',
          onChanged: (value) {
            setState(() {
              _fastPlaySpeed = value;
            });
          },
          onChangeEnd: (value) {
            widget.controller.setFastPlaySpeed(value);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            _buildQuickPickButton(2.0),
            _buildQuickPickButton(3.0),
            _buildQuickPickButton(5.0),
            _buildQuickPickButton(8.0),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPickButton(double speed) {
    final isSelected = (_fastPlaySpeed - speed).abs() < 0.01;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _fastPlaySpeed = speed;
        });
        widget.controller.setFastPlaySpeed(speed);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade50 : null,
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Text('${speed.toStringAsFixed(1)}x'),
    );
  }

  Widget _buildLeadInControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Lead-in (seconds)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${_leadInSeconds}s',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Jump before event timestamp when selecting',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _leadInSeconds.toDouble(),
          min: 0,
          max: 30,
          divisions: 30,
          label: '${_leadInSeconds}s',
          onChanged: (value) {
            setState(() {
              _leadInSeconds = value.round();
            });
          },
          onChangeEnd: (value) {
            widget.controller.setLeadIn(Duration(seconds: value.round()));
          },
        ),
      ],
    );
  }

  Widget _buildLeadOutControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Lead-out (seconds)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${_leadOutSeconds}s',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Reserved for future event playback mode',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _leadOutSeconds.toDouble(),
          min: 0,
          max: 30,
          divisions: 30,
          label: '${_leadOutSeconds}s',
          onChanged: (value) {
            setState(() {
              _leadOutSeconds = value.round();
            });
          },
          onChangeEnd: (value) {
            widget.controller.setLeadOut(Duration(seconds: value.round()));
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () async {
            await widget.controller.resetToDefaults();
            setState(() {
              _fastPlaySpeed = widget.controller.settings.fastPlaySpeed;
              _slowPlaybackSpeed = widget.controller.settings.slowPlaybackSpeed;
              _defaultPlaybackSpeed = widget.controller.settings.defaultPlaybackSpeed;
              _leadInSeconds = widget.controller.settings.leadIn.inSeconds;
              _leadOutSeconds = widget.controller.settings.leadOut.inSeconds;
            });
          },
          child: const Text('Reset to Defaults'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
