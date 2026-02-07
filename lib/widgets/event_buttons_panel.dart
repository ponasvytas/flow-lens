import 'package:flutter/material.dart';
import '../models/sport_taxonomy.dart';

class EventButtonsPanel extends StatelessWidget {
  final Function(String categoryId) onEventTriggered;
  final SportTaxonomy? taxonomy;
  final bool showNumbers;

  const EventButtonsPanel({
    required this.onEventTriggered,
    this.taxonomy,
    this.showNumbers = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (taxonomy == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Loading categories...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final categories = taxonomy!.categories;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: index < categories.length - 1 ? 8 : 0),
              child: _buildButton(
                context,
                category.categoryId,
                category.getIcon(),
                category.name,
                category.getColor(),
                index + 1,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String categoryId,
    IconData icon,
    String label,
    Color color,
    int number,
  ) {
    return SizedBox(
      width: 80, // Slightly narrower to fit in one row
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main button
          SizedBox(
            width: 80,
            height: 60,
            child: ElevatedButton(
              onPressed: () => onEventTriggered(categoryId),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.8),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Number badge (only shown when showNumbers is true)
          if (showNumbers)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 24,
                height: 24,
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
            ),
        ],
      ),
    );
  }
}
