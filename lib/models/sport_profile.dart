import 'package:flutter/material.dart';

class SportProfile {
  final String id;
  final String name;
  final String displayName;
  final IconData iconData;
  final bool enabled;

  const SportProfile({
    required this.id,
    required this.name,
    required this.displayName,
    required this.iconData,
    required this.enabled,
  });

  static const List<SportProfile> availableProfiles = [
    SportProfile(
      id: 'hockey',
      name: 'hockey',
      displayName: 'Ice Hockey',
      iconData: Icons.sports_hockey,
      enabled: true,
    ),
    SportProfile(
      id: 'soccer',
      name: 'soccer',
      displayName: 'Soccer',
      iconData: Icons.sports_soccer,
      enabled: false,
    ),
    SportProfile(
      id: 'basketball',
      name: 'basketball',
      displayName: 'Basketball',
      iconData: Icons.sports_basketball,
      enabled: false,
    ),
    SportProfile(
      id: 'volleyball',
      name: 'volleyball',
      displayName: 'Volleyball',
      iconData: Icons.sports_volleyball,
      enabled: false,
    ),
  ];
}
