import 'package:flutter/services.dart';

import '../domain/destination_catalog.dart';

class DestinationCatalogLoader {
  const DestinationCatalogLoader();

  Future<DestinationCatalog> load() async {
    final source = await rootBundle.loadString(
      'assets/destination_catalog.json',
    );
    return DestinationCatalog.fromJsonString(source);
  }
}
