enum OneRMFormula { epley, brzycki, oConner }

String oneRMFormulaToString(OneRMFormula f) {
  switch (f) {
    case OneRMFormula.epley:
      return 'epley';
    case OneRMFormula.brzycki:
      return 'brzycki';
    case OneRMFormula.oConner:
      return 'oconner';
  }
}

OneRMFormula oneRMFormulaFromString(String? s) {
  switch (s) {
    case 'brzycki':
      return OneRMFormula.brzycki;
    case 'oconner':
      return OneRMFormula.oConner;
    case 'epley':
    default:
      return OneRMFormula.epley;
  }
}

class FormulaSettings {
  static OneRMFormula current = OneRMFormula.epley;
}

double estimate1RM(double weight, int reps, {OneRMFormula? formula}) {
  if (reps <= 0 || weight <= 0) return 0;
  if (reps == 1) return weight;
  final f = formula ?? FormulaSettings.current;
  switch (f) {
    case OneRMFormula.epley:
      return weight * (1 + reps / 30.0);
    case OneRMFormula.brzycki:
      return weight * 36 / (37 - reps);
    case OneRMFormula.oConner:
      return weight * (1 + 0.025 * reps);
  }
}
