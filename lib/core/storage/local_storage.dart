import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps non-sensitive (prefs) and sensitive (secure) storage.
class LocalStorage {
  LocalStorage(this.prefs, this.secure);

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
}
