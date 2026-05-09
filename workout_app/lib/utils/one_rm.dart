enum OneRMFormula { epley, brzycki, oConner }

const OneRMFormula kDefaultFormula = OneRMFormula.epley;

double estimate1RM(double weight, int reps,
    {OneRMFormula formula = kDefaultFormula}) {
  if (reps <= 0 || weight <= 0) return 0;
  if (reps == 1) return weight;
  switch (formula) {
    case OneRMFormula.epley:
      return weight * (1 + reps / 30.0);
    case OneRMFormula.brzycki:
      return weight * 36 / (37 - reps);
    case OneRMFormula.oConner:
      return weight * (1 + 0.025 * reps);
  }
}
