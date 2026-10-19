import 'package:flutter/foundation.dart';

import '../data/property_repository.dart';
import '../models/caretaker_property.dart';
import 'api_client.dart';
import 'preferences.dart';

/// The properties the caretaker looks after, and the one being worked on.
/// Every tab works on the selected property; the choice is remembered.
class PropertiesController extends ChangeNotifier {
  PropertiesController({required this.repository, required this.preferences});

  final PropertyRepository repository;
  final AppPreferences preferences;

  List<CaretakerProperty>? properties;
  String? error;
  bool loading = false;

  /// Looked up by ID without searching the list each time.
  Map<String, CaretakerProperty> _byId = const {};

  CaretakerProperty? get selected {
    final list = properties;

    if (list == null || list.isEmpty) return null;

    return _byId[preferences.selectedPropertyId] ?? list.first;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final list = await repository.myProperties();

      properties = list;
      _byId = {for (final property in list) property.id: property};
    } on ApiException catch (failure) {
      error = failure.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> select(CaretakerProperty property) async {
    await preferences.setSelectedProperty(property.id);
    notifyListeners();
  }

  /// Forgets everything on sign-out, so the next person starts clean.
  void clear() {
    properties = null;
    _byId = const {};
    error = null;
    notifyListeners();
  }
}
