import 'package:flutter/material.dart';

class CityHub {
  final String name;
  final String nameRu;
  final double latitude;
  final double longitude;
  final IconData icon;
  final String region;

  const CityHub({
    required this.name,
    required this.nameRu,
    required this.latitude,
    required this.longitude,
    this.icon = Icons.location_city,
    this.region = '',
  });
}

/// Major Kyrgyzstan cities with hardcoded coordinates.
/// Zero API calls. Instant load. These coordinates never change.
const List<CityHub> kyrgyzstanHubs = [
  CityHub(name: 'Bishkek',    nameRu: 'Бишкек',     latitude: 42.8746, longitude: 74.5698, icon: Icons.apartment,          region: 'Chuy'),
  CityHub(name: 'Osh',        nameRu: 'Ош',         latitude: 40.5283, longitude: 72.7985, icon: Icons.mosque,             region: 'Osh'),
  CityHub(name: 'Jalal-Abad', nameRu: 'Жалал-Абад', latitude: 41.0285, longitude: 73.0014, icon: Icons.landscape,          region: 'Jalal-Abad'),
  CityHub(name: 'Karakol',    nameRu: 'Каракол',    latitude: 42.4907, longitude: 78.3936, icon: Icons.terrain,            region: 'Issyk-Kul'),
  CityHub(name: 'Tokmok',     nameRu: 'Токмок',     latitude: 42.7632, longitude: 75.2860, icon: Icons.location_city,      region: 'Chuy'),
  CityHub(name: 'Naryn',      nameRu: 'Нарын',      latitude: 41.4287, longitude: 75.9911, icon: Icons.terrain,            region: 'Naryn'),
  CityHub(name: 'Batken',     nameRu: 'Баткен',     latitude: 40.0627, longitude: 70.8193, icon: Icons.landscape,          region: 'Batken'),
  CityHub(name: 'Talas',      nameRu: 'Талас',      latitude: 42.5230, longitude: 72.2426, icon: Icons.landscape,          region: 'Talas'),
];
