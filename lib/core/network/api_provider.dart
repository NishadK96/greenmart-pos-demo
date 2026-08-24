import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apis/api.dart';
import 'http_client.dart';

final apiProvider = Provider<Api>((ref) => Api(client: createHttpClient()));
