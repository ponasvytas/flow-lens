import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/sport_taxonomy.dart';

class TaxonomyRepository {
  final Map<String, SportTaxonomy> _cache = {};

  Future<SportTaxonomy> loadSportTaxonomy(String sportId) async {
    if (_cache.containsKey(sportId)) {
      return _cache[sportId]!;
    }

    try {
      final jsonString =
          await rootBundle.loadString('assets/sports/$sportId.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final taxonomy = SportTaxonomy.fromJson(jsonData);

      taxonomy.validate();

      _cache[sportId] = taxonomy;
      return taxonomy;
    } catch (e) {
      throw Exception('Failed to load taxonomy for sport: $sportId. Error: $e');
    }
  }

  SportTaxonomy? getCachedTaxonomy(String sportId) {
    return _cache[sportId];
  }

  void clearCache() {
    _cache.clear();
  }
}
