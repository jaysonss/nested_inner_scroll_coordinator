import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class NestedInnerScrollChild extends StatelessWidget {
  final Widget child;

  final NestedInnerScrollCoordinator coordinator;

  const NestedInnerScrollChild(
      {Key? key, required this.coordinator, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      child: child,
      onPointerDown: _startScrollInner,
      onPointerCancel: _endInnerScroll,
      onPointerUp: _endInnerScroll,
    );
  }

  void _startScrollInner(_) {
    coordinator.innerTouching = true;
  }

  void _endInnerScroll(_) {
    coordinator.innerTouching = false;
  }
}

class _NestedScrollMetrics extends FixedScrollMetrics {
  _NestedScrollMetrics({
    required double minScrollExtent,
    required double maxScrollExtent,
    required double pixels,
    required double viewportDimension,
    required AxisDirection axisDirection,
    required this.minRange,
    required this.maxRange,
    required this.correctionOffset,
  }) : super(
          minScrollExtent: minScrollExtent,
          maxScrollExtent: maxScrollExtent,
          pixels: pixels,
          viewportDimension: viewportDimension,
          axisDirection: axisDirection,
        );

  @override
  _NestedScrollMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    double? minRange,
    double? maxRange,
    double? correctionOffset,
  }) {
    return _NestedScrollMetrics(
      minScrollExtent: minScrollExtent ?? this.minScrollExtent,
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
      pixels: pixels ?? this.pixels,
      viewportDimension: viewportDimension ?? this.viewportDimension,
      axisDirection: axisDirection ?? this.axisDirection,
      minRange: minRange ?? this.minRange,
      maxRange: maxRange ?? this.maxRange,
      correctionOffset: correctionOffset ?? this.correctionOffset,
    );
  }

  final double minRange;

  final double maxRange;

  final double correctionOffset;
}

typedef _NestedScrollActivityGetter = ScrollActivity Function(
    _NestedScrollPosition position);

class NestedInnerScrollCoordinator
    implements ScrollActivityDelegate, ScrollHoldController {
  NestedInnerScrollCoordinator(this._parent) {
    final double initialScrollOffset = _parent.initialScrollOffset;
    _outerController = NestedInnerScrollController(
      this,
      initialScrollOffset: initialScrollOffset,
      debugLabel: 'outer',
    );
    _innerController = NestedInnerScrollController(
      this,
      initialScrollOffset: 0.0,
      debugLabel: 'inner',
    );
  }

  ScrollController _parent;

  late NestedInnerScrollController _outerController;
  NestedInnerScrollController get outerController => _outerController;

  late NestedInnerScrollController _innerController;
  NestedInnerScrollController get innerController => _innerController;

  bool innerTouching = false;

  //[HOOK]return true when 1. user touch 2. fling
  bool get innerScroll {
    return innerTouching ||
        (_innerPositions.isNotEmpty &&
            _innerPositions.firstWhereOrNull(
                    (element) => element.isScroll() == true) !=
                null);
  }

  _NestedScrollPosition get _outerPosition {
    assert(_outerController.hasClients,
        "please ensure out scroll controller has clients");
    assert(_outerController.nestedPositions.length == 1,
        "outController has more than one client");
    return _outerController.position as _NestedScrollPosition;
  }

  Iterable<_NestedScrollPosition> get _innerPositions {
    return _innerController.nestedPositions;
  }

  ScrollDirection get userScrollDirection => _userScrollDirection;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  void updateUserScrollDirection(ScrollDirection value) {
    if (userScrollDirection == value) return;
    _userScrollDirection = value;
    _outerPosition.didUpdateScrollDirection(value);
    for (var element in _innerPositions) {
      element.didUpdateScrollDirection(value);
    }
  }

  ScrollDragController? _currentDrag;

  void beginActivity(ScrollActivity newOuterActivity,
      _NestedScrollActivityGetter innerActivityGetter) {
    _outerPosition.beginActivity(newOuterActivity);
    bool scrolling = newOuterActivity.isScrolling;

    //[HOOK]if we dont touch inner scrollview, disable it's activity consume
    if (innerScroll) {
      for (final _NestedScrollPosition position in _innerPositions) {
        final ScrollActivity newInnerActivity = innerActivityGetter(position);
        position.beginActivity(newInnerActivity);
        scrolling = newInnerActivity.isScrolling;
      }
    }
    _currentDrag?.dispose();
    _currentDrag = null;
    if (!scrolling) {
      updateUserScrollDirection(ScrollDirection.idle);
    }
  }

  @override
  AxisDirection get axisDirection => _outerPosition.axisDirection;

  static IdleScrollActivity _createIdleScrollActivity(
      _NestedScrollPosition position) {
    return IdleScrollActivity(position);
  }

  @override
  void goIdle() {
    beginActivity(
      _createIdleScrollActivity(_outerPosition),
      _createIdleScrollActivity,
    );
  }

  @override
  void goBallistic(double velocity) {
    beginActivity(
      createOuterBallisticScrollActivity(velocity),
      (_NestedScrollPosition position) =>
          createInnerBallisticScrollActivity(position, velocity),
    );
  }

  ScrollActivity createOuterBallisticScrollActivity(double velocity) {
    final _NestedScrollMetrics metrics = _getMetrics(_outerPosition, velocity);

    return _outerPosition.createBallisticScrollActivity(
      _outerPosition.physics.createBallisticSimulation(metrics, velocity),
      mode: _NestedBallisticScrollActivityMode.outer,
      metrics: metrics,
    );
  }

  @protected
  ScrollActivity createInnerBallisticScrollActivity(
      _NestedScrollPosition position, double velocity) {
    return position.createBallisticScrollActivity(
      position.physics.createBallisticSimulation(
        velocity == 0 ? position : _getMetrics(position, velocity),
        velocity,
      ),
      mode: _NestedBallisticScrollActivityMode.inner,
    );
  }

  _NestedScrollMetrics _getMetrics(
      _NestedScrollPosition position, double velocity) {
    return _NestedScrollMetrics(
      minScrollExtent: position.minScrollExtent,
      maxScrollExtent: position.maxScrollExtent,
      pixels: position.pixels,
      viewportDimension: position.viewportDimension,
      axisDirection: position.axisDirection,
      minRange: position.minScrollExtent,
      maxRange: position.maxScrollExtent,
      correctionOffset: 0,
    );
  }

  double unnestOffset(double value, _NestedScrollPosition source) {
    if (source == _outerPosition) {
      return value.clamp(
          _outerPosition.minScrollExtent, _outerPosition.maxScrollExtent);
    }

    if (value < source.minScrollExtent) {
      return value - source.minScrollExtent + _outerPosition.minScrollExtent;
    }
    return value - source.minScrollExtent + _outerPosition.maxScrollExtent;
  }

  double nestOffset(double value, _NestedScrollPosition target) {
    return value.clamp(target.minScrollExtent, target.maxScrollExtent);
  }

  @override
  double setPixels(double newPixels) {
    assert(false);
    return 0.0;
  }

  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    beginActivity(
      HoldScrollActivity(
          delegate: _outerPosition, onHoldCanceled: holdCancelCallback),
      (_NestedScrollPosition position) =>
          HoldScrollActivity(delegate: position),
    );
    return this;
  }

  @override
  void cancel() {
    goBallistic(0.0);
  }

  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final ScrollDragController drag = ScrollDragController(
      delegate: this,
      details: details,
      onDragCanceled: dragCancelCallback,
    );
    beginActivity(
      DragScrollActivity(_outerPosition, drag),
      (_NestedScrollPosition position) => DragScrollActivity(position, drag),
    );
    assert(_currentDrag == null);
    _currentDrag = drag;
    return drag;
  }

  @override
  void applyUserOffset(double delta) {
    updateUserScrollDirection(
        delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse);
    assert(delta != 0.0);
    final innerPositionList = _innerPositions.toList();

    if (!innerScroll || innerPositionList.isEmpty) {
      _outerPosition.applyFullDragUpdate(delta);
    } else {
      double remainDelta =
          innerPositionList.first.applyClampedDragUpdate(delta);

      //[HOOK] when innerscrollview overscroll, outscrollview continues
      if (remainDelta != 0.0) {
        _outerPosition.applyFullDragUpdate(remainDelta);
      }
    }
  }

  void updateCanDrag(_NestedScrollPosition position) {
    if (!position.haveDimensions) {
      return;
    }
    position.updateCanDrag(position.maxScrollExtent - position.minScrollExtent);
  }

  void setParent(ScrollController value) {
    _parent = value;
    updateParent();
  }

  void updateParent() {
    _outerPosition.setParent(_parent);
  }

  @mustCallSuper
  void dispose() {
    _currentDrag?.dispose();
    _currentDrag = null;
    _outerController.dispose();
    _innerController.dispose();
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NestedInnerScrollCoordinator')}(outer=$_outerController; inner=$_innerController)';
}

class NestedInnerScrollController extends ScrollController {
  NestedInnerScrollController(
    this.coordinator, {
    double initialScrollOffset = 0.0,
    String debugLabel = "unknown",
  }) : super(initialScrollOffset: initialScrollOffset, debugLabel: debugLabel);

  final NestedInnerScrollCoordinator coordinator;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _NestedScrollPosition(
      coordinator: coordinator,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel!,
    );
  }

  //disable Notification pop up
  void jumpWithNoNotification(double value) {
    assert(nestedPositions.isNotEmpty);
    for (_NestedScrollPosition position in nestedPositions) {
      position.jumpWithNoNotification(value);
    }
  }

  @override
  void attach(ScrollPosition position) {
    assert(position is _NestedScrollPosition);
    super.attach(position);
    coordinator.updateParent();
    coordinator.updateCanDrag(position as _NestedScrollPosition);
    position.addListener(_scheduleUpdateShadow);
    _scheduleUpdateShadow();
  }

  @override
  void detach(ScrollPosition position) {
    assert(position is _NestedScrollPosition);
    position.removeListener(_scheduleUpdateShadow);
    super.detach(position);
    _scheduleUpdateShadow();
  }

  void _scheduleUpdateShadow() {
    // We do this asynchronously for attach() so that the new position has had
    // time to be initialized, and we do it asynchronously for detach() and from
    // the position change notifications because those happen synchronously
    // during a frame, at a time where it's too late to call setState. Since the
    // result is usually animated, the lag incurred is no big deal.
    // SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
    //    coordinator.updateShadow();
    // });
  }

  Iterable<_NestedScrollPosition> get nestedPositions sync* {
    // TODO(vegorov): use instance method version of castFrom when it is available.
    yield* Iterable.castFrom<ScrollPosition, _NestedScrollPosition>(positions);
  }
}

// The _NestedScrollPosition is used by both the inner and outer viewports of a
// NestedScrollView. It tracks the offset to use for those viewports, and knows
// about the NestedInnerScrollCoordinator, so that when activities are triggered on
// this class, they can defer, or be influenced by, the coordinator.
class _NestedScrollPosition extends ScrollPosition
    implements ScrollActivityDelegate {
  _NestedScrollPosition({
    required ScrollPhysics physics,
    required ScrollContext context,
    double? initialPixels,
    ScrollPosition? oldPosition,
    String debugLabel = "unknown",
    required this.coordinator,
  }) : super(
          physics: physics,
          context: context,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        ) {
    if (hasPixels == false && initialPixels != null) {
      correctPixels(initialPixels);
    }

    if (activity == null) goIdle();
    assert(activity != null);
    saveScrollOffset(); // in case we didn't restore but could, so that we don't restore it later
  }

  final NestedInnerScrollCoordinator coordinator;

  bool get isInner => debugLabel == "inner";

  TickerProvider get vsync => context.vsync;

  ScrollController? _parent;

  bool isScroll() {
    return activity?.isScrolling == true;
  }

  @override
  bool applyContentDimensions(
      double? minScrollExtent, double? maxScrollExtent) {
    return super.applyContentDimensions(minScrollExtent!, maxScrollExtent!);
  }

  void setParent(ScrollController value) {
    _parent?.detach(this);
    _parent = value;
    _parent!.attach(this);
  }

  @override
  AxisDirection get axisDirection => context.axisDirection;

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    activity?.updateDelegate(this);
  }

  // Returns the amount of delta that was not used.
  //
  // Positive delta means going down (exposing stuff above), negative delta
  // going up (exposing stuff below).
  double applyClampedDragUpdate(double delta) {
    assert(delta != 0.0);
    // If we are going towards the maxScrollExtent (negative scroll offset),
    // then the furthest we can be in the minScrollExtent direction is negative
    // infinity. For example, if we are already overscrolled, then scrolling to
    // reduce the overscroll should not disallow the overscroll.
    //
    // If we are going towards the minScrollExtent (positive scroll offset),
    // then the furthest we can be in the minScrollExtent direction is wherever
    // we are now, if we are already overscrolled (in which case pixels is less
    // than the minScrollExtent), or the minScrollExtent if we are not.
    //
    // In other words, we cannot, via applyClampedDragUpdate, _enter_ an
    // overscroll situation.
    //
    // An overscroll situation might be nonetheless entered via several means.
    // One is if the physics allow it, via applyFullDragUpdate (see below). An
    // overscroll situation can also be forced, e.g. if the scroll position is
    // artificially set using the scroll controller.
    final double min =
        delta < 0.0 ? -double.infinity : math.min(minScrollExtent, pixels);
    // The logic for max is equivalent but on the other side.

    final double max =
        delta > 0.0 ? double.infinity : math.max(maxScrollExtent, pixels);
    final double oldPixels = pixels;
    final double newPixels = (pixels - delta).clamp(min, max);
    final double clampedDelta = newPixels - pixels;
    if (clampedDelta == 0.0) return delta;
    final double overscroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overscroll;
    final double offset = actualNewPixels - oldPixels;
    if (offset != 0.0) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(offset);
    }
    return delta + offset;
  }

  // Returns the overscroll.
  double applyFullDragUpdate(double delta) {
    assert(delta != 0.0);
    final double oldPixels = pixels;
    // Apply friction:
    final double newPixels =
        pixels - physics.applyPhysicsToUserOffset(this, delta);
    if (oldPixels == newPixels) {
      return 0.0; // delta must have been so small we dropped it during floating point addition
    }
    // Check for overscroll:
    final double overscroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overscroll;
    if (actualNewPixels != oldPixels) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(actualNewPixels - oldPixels);
    }
    if (overscroll != 0.0) {
      didOverscrollBy(overscroll);
      return overscroll;
    }
    return 0.0;
  }

  @override
  ScrollDirection get userScrollDirection => coordinator.userScrollDirection;

  DrivenScrollActivity createDrivenScrollActivity(
      double to, Duration duration, Curve curve) {
    return DrivenScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: vsync,
    );
  }

  @override
  void applyUserOffset(double delta) {
    // do nothing, won't be called
  }

  // This is called by activities when they finish their work.
  @override
  void goIdle() {
    beginActivity(IdleScrollActivity(this));
  }

  // This is called by activities when they finish their work and want to go ballistic.
  @override
  void goBallistic(double velocity) {
    Simulation? simulation;
    if (velocity != 0.0 || outOfRange) {
      simulation = physics.createBallisticSimulation(this, velocity);
    }
    beginActivity(createBallisticScrollActivity(
      simulation,
      mode: _NestedBallisticScrollActivityMode.independent,
    ));
  }

  ScrollActivity createBallisticScrollActivity(
    Simulation? simulation, {
    required _NestedBallisticScrollActivityMode mode,
    _NestedScrollMetrics? metrics,
  }) {
    if (simulation == null) return IdleScrollActivity(this);

    switch (mode) {
      case _NestedBallisticScrollActivityMode.outer:
        assert(metrics != null);
        if (metrics!.minRange == metrics.maxRange) {
          return IdleScrollActivity(this);
        }
        return _NestedOuterBallisticScrollActivity(
            coordinator, this, metrics, simulation, context.vsync);
      case _NestedBallisticScrollActivityMode.inner:
        return _NestedInnerBallisticScrollActivity(
            coordinator, this, simulation, context.vsync);
      case _NestedBallisticScrollActivityMode.independent:
        return BallisticScrollActivity(this, simulation, context.vsync);
      default:
        throw Exception("unsupport mode");
    }
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    if (nearEqual(to, pixels, physics.tolerance.distance)) {
      // Skip the animation, go straight to the position as we are already close.
      jumpTo(to);
      return Future<void>.value();
    }

    final DrivenScrollActivity activity = DrivenScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: context.vsync,
    );
    beginActivity(activity);
    return activity.done;
  }

  @override
  void jumpTo(double value) {
    goIdle();
    localJumpTo(value);
    goBallistic(0.0);
  }

  @override
  void jumpToWithoutSettling(double value) {
    assert(false);
  }

  void localJumpTo(double value) {
    if (pixels != value) {
      final double oldPixels = pixels;
      forcePixels(value);
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
  }

  void jumpWithNoNotification(double value) {
    if (pixels != value) {
      forcePixels(value);
    }
  }

  @override
  void applyNewDimensions() {
    super.applyNewDimensions();
    coordinator.updateCanDrag(this);
  }

  void updateCanDrag(double totalExtent) {
    context.setCanDrag(totalExtent > (viewportDimension - maxScrollExtent) ||
        minScrollExtent != maxScrollExtent);
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    return coordinator.hold(holdCancelCallback);
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    return coordinator.drag(details, dragCancelCallback);
  }

  @override
  void dispose() {
    _parent?.detach(this);
    super.dispose();
  }

  @override
  void pointerScroll(double delta) {
    // TODO: implement pointerScroll
  }
}

enum _NestedBallisticScrollActivityMode { outer, inner, independent }

class _NestedInnerBallisticScrollActivity extends BallisticScrollActivity {
  _NestedInnerBallisticScrollActivity(
    this.coordinator,
    _NestedScrollPosition position,
    Simulation simulation,
    TickerProvider vsync,
  ) : super(position, simulation, vsync);

  final NestedInnerScrollCoordinator coordinator;

  @override
  _NestedScrollPosition get delegate => super.delegate as _NestedScrollPosition;

  @override
  void resetActivity() {
    delegate.beginActivity(
        coordinator.createInnerBallisticScrollActivity(delegate, velocity));
  }

  @override
  void applyNewDimensions() {
    delegate.beginActivity(
        coordinator.createInnerBallisticScrollActivity(delegate, velocity));
  }

  @override
  bool applyMoveTo(double value) {
    return super.applyMoveTo(coordinator.nestOffset(value, delegate));
  }
}

class _NestedOuterBallisticScrollActivity extends BallisticScrollActivity {
  _NestedOuterBallisticScrollActivity(
    this.coordinator,
    _NestedScrollPosition position,
    this.metrics,
    Simulation simulation,
    TickerProvider vsync,
  )   : assert(metrics.minRange != metrics.maxRange),
        assert(metrics.maxRange > metrics.minRange),
        super(position, simulation, vsync);

  final NestedInnerScrollCoordinator coordinator;
  final _NestedScrollMetrics metrics;

  @override
  _NestedScrollPosition get delegate => super.delegate as _NestedScrollPosition;

  @override
  void resetActivity() {
    delegate.beginActivity(
        coordinator.createOuterBallisticScrollActivity(velocity));
  }

  @override
  void applyNewDimensions() {
    delegate.beginActivity(
        coordinator.createOuterBallisticScrollActivity(velocity));
  }

  @override
  bool applyMoveTo(double value) {
    if (coordinator.innerScroll) {
      ///[HOOK]if fling inner scrollview at it's edge, enable out scrollview's fling effect
      bool bottomOverscroll = velocity > 0 &&
          coordinator.innerController.position.pixels >=
              coordinator.innerController.position.maxScrollExtent;
      bool topOverScroll = velocity < 0 &&
          coordinator.innerController.position.pixels <=
              coordinator.innerController.position.minScrollExtent;

      if (!bottomOverscroll && !topOverScroll) {
        return false;
      } else {
        //enable out scrollview fling
      }
    }
    bool done = false;
    if (velocity > 0.0) {
      if (value < metrics.minRange) return true;
      if (value > metrics.maxRange) {
        value = metrics.maxRange;
        done = true;
      }
    } else if (velocity < 0.0) {
      if (value > metrics.maxRange) return true;
      if (value < metrics.minRange) {
        value = metrics.minRange;
        done = true;
      }
    } else {
      value = value.clamp(metrics.minRange, metrics.maxRange);
      done = true;
    }
    final bool result = super.applyMoveTo(value + metrics.correctionOffset);
    assert(
        result); // since we tried to pass an in-range value, it shouldn't ever overflow
    return !done;
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, '_NestedOuterBallisticScrollActivity')}(${metrics.minRange} .. ${metrics.maxRange}; correcting by ${metrics.correctionOffset})';
  }
}
