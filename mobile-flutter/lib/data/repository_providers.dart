import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/service_providers.dart';
import 'repositories/activity_repository.dart';
import 'repositories/card_repository.dart';
import 'repositories/list_repository.dart';

final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository(ref.watch(mudbaseDataServiceProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(mudbaseDataServiceProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(mudbaseDataServiceProvider));
});
