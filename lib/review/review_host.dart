import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'review_service.dart';

/// Counts the days the app is opened for the store review: once when the app
/// starts and again each time it comes back to the foreground (the day is
/// counted once, whatever the number of opens). Mounted once above the
/// router, it shows nothing and only wraps [child].
class ReviewHost extends ConsumerStatefulWidget {
  const ReviewHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReviewHost> createState() => _ReviewHostState();
}

class _ReviewHostState extends ConsumerState<ReviewHost> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _record);
    unawaited(_record());
  }

  Future<void> _record() => ref.read(reviewServiceProvider).recordOpen();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
