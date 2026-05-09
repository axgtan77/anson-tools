import '../db/database_helper.dart';
import 'one_rm.dart';

class AppSettings {
  static int defaultRestSeconds = 90;
}

Future<void> loadSettings() async {
  final db = DatabaseHelper.instance;
  final formula = await db.getSetting('one_rm_formula');
  FormulaSettings.current = oneRMFormulaFromString(formula);

  final rest = await db.getSetting('default_rest_seconds');
  if (rest != null) {
    AppSettings.defaultRestSeconds = int.tryParse(rest) ?? 90;
  }
}

Future<void> setFormula(OneRMFormula f) async {
  FormulaSettings.current = f;
  await DatabaseHelper.instance
      .setSetting('one_rm_formula', oneRMFormulaToString(f));
}

Future<void> setDefaultRest(int seconds) async {
  AppSettings.defaultRestSeconds = seconds;
  await DatabaseHelper.instance
      .setSetting('default_rest_seconds', seconds.toString());
}
