import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdrezka_tv/core/api/hdrezka_api_lib.dart';

final sessionProvider = Provider<HdRezkaSession>((ref) {
  return HdRezkaSession(origin: 'https://hdrezka.ag');
}, name: 'sessionProvider');
