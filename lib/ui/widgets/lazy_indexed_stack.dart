import 'package:flutter/widgets.dart';

typedef LazyWidgetBuilder = Widget Function();

/// Preserves visited tabs without initializing inactive tabs at first paint.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  }) : assert(index >= 0),
       assert(index < builders.length);

  final int index;
  final List<LazyWidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _loadedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _load(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load(widget.index);
  }

  void _load(int index) {
    _loadedIndexes.add(index);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: _loadedIndexes
        .map(
          (index) => Offstage(
            offstage: index != widget.index,
            child: TickerMode(
              enabled: index == widget.index,
              child: widget.builders[index](),
            ),
          ),
        )
        .toList(growable: false),
  );
}
