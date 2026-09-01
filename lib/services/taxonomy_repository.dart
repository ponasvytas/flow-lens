import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/sport_taxonomy.dart';

abstract interface class TaxonomyRepository {
  Future<SportTaxonomy> loadSportTaxonomy(String sportId);

  SportTaxonomy? getCachedTaxonomy(String sportId);

  void clearCache();
}

/// Loads the immutable taxonomies bundled with the application.
class BundledTaxonomyRepository implements TaxonomyRepository {
  final Map<String, SportTaxonomy> _cache = {};

  @override
  Future<SportTaxonomy> loadSportTaxonomy(String sportId) async {
    if (_cache.containsKey(sportId)) {
      return _cache[sportId]!;
    }

    try {
      final jsonString = await rootBundle.loadString(
        'assets/sports/$sportId.json',
      );
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final taxonomy = SportTaxonomy.fromJson(jsonData);

      taxonomy.validate();

      _cache[sportId] = taxonomy;
      return taxonomy;
    } catch (e) {
      throw Exception('Failed to load taxonomy for sport: $sportId. Error: $e');
    }
  }

  @override
  SportTaxonomy? getCachedTaxonomy(String sportId) {
    return _cache[sportId];
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}
