String fmtKg(double v) {
  final one = v.toStringAsFixed(1);
  return double.parse(one) == v ? one : v.toStringAsFixed(2);
}
