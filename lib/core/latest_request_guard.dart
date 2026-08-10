class LatestRequestGuard {
  int _generation = 0;

  int begin() => ++_generation;

  int capture() => _generation;

  bool isCurrent(int generation) => generation == _generation;
}
