import 'package:flutter/scheduler.dart';

/// Runs [update] now, or right after the current frame when it is called while
/// the frame is being built, laid out or painted.
///
/// A provider listener can fire in the middle of a build: another widget reads
/// a provider that was invalidated, the provider rebuilds and notifies every
/// listener at once. A `setState` there is not allowed, so it waits for the end
/// of the frame. [update] should check `mounted` itself.
void runOutsideBuild(VoidCallback update) {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    binding.addPostFrameCallback((_) => update());
  } else {
    update();
  }
}
