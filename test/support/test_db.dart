import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tide/data/db/app_database.dart';

AppDatabase testDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
