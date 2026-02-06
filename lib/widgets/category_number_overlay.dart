import 'package:flutter/material.dart';

/// DEPRECATED: This widget is no longer used.
/// Number badges are now integrated directly into EventButtonsPanel.
/// Keeping this file for reference only.
class CategoryNumberOverlay extends StatelessWidget {
  final bool isVisible;
  final int categoryCount;
  
  const CategoryNumberOverlay({
    required this.isVisible,
    required this.categoryCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || categoryCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 75, // Match EventButtonsPanel position
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              categoryCount,
              (index) => Padding(
                padding: EdgeInsets.only(
                  right: index < categoryCount - 1 ? 8.0 : 0,
                ),
                child: _buildNumberBadge(index + 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberBadge(int number) {
    return Container(
      width: 60, // Match EventButtonsPanel button width
      height: 60, // Match EventButtonsPanel button height
      alignment: Alignment.topRight,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
