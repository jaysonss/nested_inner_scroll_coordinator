import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewDemo extends StatefulWidget {
  final ViewportOffset offset;
  final String url;

  const WebViewDemo({Key? key, required this.offset, required this.url})
      : super(key: key);

  @override
  _WebViewDemoState createState() => _WebViewDemoState();
}

class _WebViewDemoState extends State<WebViewDemo> {
  WebViewController? _controller;

  double _contentHeight = 0;

  @override
  Widget build(BuildContext context) {
    if (_contentHeight == 0) {
      return SizedBox(
        height: 1,
        child: WebView(
          initialUrl: widget.url,
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          javascriptMode: JavascriptMode.unrestricted,
          debuggingEnabled: true,
          onPageFinished: (some) async {
            if (_controller != null) {
              _contentHeight = double.tryParse(
                    await _controller!.evaluateJavascript(
                        "document.documentElement.scrollHeight;"),
                  ) ??
                  100;
              setState(() {});
            }
          },
        ),
      );
    }
    return WebViewPort(
      offset: widget.offset,
      clipBehavior: Clip.hardEdge,
      onScroll: _onScroll,
      child: SizedBox(
        height: _contentHeight / 3,
        child: WebView(
          initialUrl: widget.url,
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          javascriptMode: JavascriptMode.unrestricted,
          debuggingEnabled: true,
        ),
      ),
      contentHeight: _contentHeight,
    );
  }

  void _onScroll(Offset offset) {
    _controller
        ?.evaluateJavascript("window.scrollTo(0,${offset.dy.abs().ceil()})");
  }
}

/// This Class is used to wrap Webview.
///
/// It is modified base on SingleChildScrollView's Viewport
///
/// The Main modify entry is:
/// 1. maxScrollExtent
/// 2. paint
/// 3. hitTest
///
/// You can check them by search '[HOOK]' keyword
class WebViewPort extends SingleChildRenderObjectWidget {
  const WebViewPort({
    Key? key,
    this.axisDirection = AxisDirection.down,
    required this.offset,
    Widget? child,
    required this.clipBehavior,
    required this.onScroll,
    required this.contentHeight,
  })  : assert(axisDirection != null),
        assert(clipBehavior != null),
        super(key: key, child: child);

  final AxisDirection axisDirection;
  final ViewportOffset offset;
  final Clip clipBehavior;
  final ValueChanged<Offset> onScroll;
  final double contentHeight;

  @override
  _RenderSingleChildViewport createRenderObject(BuildContext context) {
    return _RenderSingleChildViewport(
      axisDirection: axisDirection,
      offset: offset,
      clipBehavior: clipBehavior,
      onScroll: onScroll,
      contentHeight: contentHeight,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSingleChildViewport renderObject) {
    // Order dependency: The offset setter reads the axis direction.
    renderObject
      ..axisDirection = axisDirection
      ..offset = offset
      ..contentHeight = contentHeight
      ..clipBehavior = clipBehavior;
  }
}

class _RenderSingleChildViewport extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>
    implements RenderAbstractViewport {
  _RenderSingleChildViewport({
    AxisDirection axisDirection = AxisDirection.down,
    required ViewportOffset offset,
    double cacheExtent = RenderAbstractViewport.defaultCacheExtent,
    RenderBox? child,
    required Clip clipBehavior,
    required this.onScroll,
    required this.contentHeight,
  })  : assert(axisDirection != null),
        assert(offset != null),
        assert(cacheExtent != null),
        assert(clipBehavior != null),
        _axisDirection = axisDirection,
        _offset = offset,
        _cacheExtent = cacheExtent,
        _clipBehavior = clipBehavior {
    this.child = child;
  }

  final ValueChanged<Offset> onScroll;
  double contentHeight;

  AxisDirection get axisDirection => _axisDirection;
  AxisDirection _axisDirection;
  set axisDirection(AxisDirection value) {
    assert(value != null);
    if (value == _axisDirection) return;
    _axisDirection = value;
    markNeedsLayout();
  }

  Axis get axis => axisDirectionToAxis(axisDirection);

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    assert(value != null);
    if (value == _offset) return;
    if (attached) _offset.removeListener(_hasScrolled);
    _offset = value;
    if (attached) _offset.addListener(_hasScrolled);
    markNeedsLayout();
  }

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  double get cacheExtent => _cacheExtent;
  double _cacheExtent;
  set cacheExtent(double value) {
    assert(value != null);
    if (value == _cacheExtent) return;
    _cacheExtent = value;
    markNeedsLayout();
  }

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.none], and must not be null.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.none;
  set clipBehavior(Clip value) {
    assert(value != null);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _hasScrolled() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderObject child) {
    // We don't actually use the offset argument in BoxParentData, so let's
    // avoid allocating it at all.
    if (child.parentData is! ParentData) child.parentData = ParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_hasScrolled);
  }

  @override
  void detach() {
    _offset.removeListener(_hasScrolled);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  double get _viewportExtent {
    assert(hasSize);
    switch (axis) {
      case Axis.horizontal:
        return size.width;
      case Axis.vertical:
        return size.height;
    }
  }

  double get _minScrollExtent {
    assert(hasSize);
    return 0.0;
  }

  double get _maxScrollExtent {
    assert(hasSize);
    if (child == null) return 0.0;
    switch (axis) {
      case Axis.horizontal:
        return math.max(0.0, child!.size.width - size.width);
      case Axis.vertical:

        ///[HOOK maxScrollExtent]
        return math.max(0.0, contentHeight - size.height);
      // return math.max(0.0, child!.size.height - size.height);
    }
  }

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    switch (axis) {
      case Axis.horizontal:
        return constraints.heightConstraints();
      case Axis.vertical:
        return constraints.widthConstraints();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child != null) return child!.getMinIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child != null) return child!.getMaxIntrinsicWidth(height);
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child != null) return child!.getMinIntrinsicHeight(width);
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child != null) return child!.getMaxIntrinsicHeight(width);
    return 0.0;
  }

  // We don't override computeDistanceToActualBaseline(), because we
  // want the default behavior (returning null). Otherwise, as you
  // scroll, it would shift in its parent if the parent was baseline-aligned,
  // which makes no sense.

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) {
      return constraints.smallest;
    }
    final Size childSize =
        child!.getDryLayout(_getInnerConstraints(constraints));
    return constraints.constrain(childSize);
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    if (child == null) {
      size = constraints.smallest;
    } else {
      child!.layout(_getInnerConstraints(constraints), parentUsesSize: true);
      size = constraints.constrain(child!.size);
    }

    offset.applyViewportDimension(_viewportExtent);
    offset.applyContentDimensions(_minScrollExtent, _maxScrollExtent);
  }

  Offset get _paintOffset => _paintOffsetForPosition(offset.pixels);

  Offset _paintOffsetForPosition(double position) {
    assert(axisDirection != null);
    switch (axisDirection) {
      case AxisDirection.up:
        return Offset(0.0, position - child!.size.height + size.height);
      case AxisDirection.down:
        return Offset(0.0, -position);
      case AxisDirection.left:
        return Offset(position - child!.size.width + size.width, 0.0);
      case AxisDirection.right:
        return Offset(-position, 0.0);
    }
  }

  bool _shouldClipAtPaintOffset(Offset paintOffset) {
    assert(child != null);
    return paintOffset.dx < 0 ||
        paintOffset.dy < 0 ||
        paintOffset.dx + child!.size.width > size.width ||
        paintOffset.dy + child!.size.height > size.height;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final Offset paintOffset = _paintOffset;

      ///[HOOK]
      onScroll.call(paintOffset);

      void paintContents(PaintingContext context, Offset offset) {
        ///[HOOK]
        context.paintChild(child!, offset);
      }

      if (_shouldClipAtPaintOffset(paintOffset) && clipBehavior != Clip.none) {
        _clipRectLayer.layer = context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          paintContents,
          clipBehavior: clipBehavior,
          oldLayer: _clipRectLayer.layer,
        );
      } else {
        _clipRectLayer.layer = null;
        paintContents(context, offset);
      }
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset paintOffset = _paintOffset;
    transform.translate(paintOffset.dx, paintOffset.dy);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject? child) {
    if (child != null && _shouldClipAtPaintOffset(_paintOffset))
      return Offset.zero & size;
    return null;
  }

  ///[HOOK]
  // @override
  // bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
  //   if (child != null) {
  //     return result.addWithPaintOffset(
  //       offset: _paintOffset,
  //       position: position,
  //       hitTest: (BoxHitTestResult result, Offset? transformed) {
  //         assert(transformed == position + -_paintOffset);
  //         return child!.hitTest(result, position: transformed!);
  //       },
  //     );
  //   }
  //   return false;
  // }

  ///[HOOK]
  @override
  bool hitTest(BoxHitTestResult result, {Offset? position}) {
    if (position != null && size.contains(position)) {
      _addPositionToChild(child!, result, position - _paintOffset);
      return true;
    }
    return false;
  }

  ///[HOOK]
  void _addPositionToChild(
      RenderObject obj, BoxHitTestResult result, Offset position) {
    if (obj is RenderAndroidView || obj is RenderUiKitView) {
      result.add(BoxHitTestEntry(obj as RenderBox, position));
      return;
    }
    obj.visitChildren((child) {
      _addPositionToChild(child, result, position);
    });
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment,
      {Rect? rect}) {
    rect ??= target.paintBounds;
    if (target is! RenderBox)
      return RevealedOffset(offset: offset.pixels, rect: rect);

    final RenderBox targetBox = target;
    final Matrix4 transform = targetBox.getTransformTo(child);
    final Rect bounds = MatrixUtils.transformRect(transform, rect);
    final Size contentSize = child!.size;

    final double leadingScrollOffset;
    final double targetMainAxisExtent;
    final double mainAxisExtent;

    assert(axisDirection != null);
    switch (axisDirection) {
      case AxisDirection.up:
        mainAxisExtent = size.height;
        leadingScrollOffset = contentSize.height - bounds.bottom;
        targetMainAxisExtent = bounds.height;
        break;
      case AxisDirection.right:
        mainAxisExtent = size.width;
        leadingScrollOffset = bounds.left;
        targetMainAxisExtent = bounds.width;
        break;
      case AxisDirection.down:
        mainAxisExtent = size.height;
        leadingScrollOffset = bounds.top;
        targetMainAxisExtent = bounds.height;
        break;
      case AxisDirection.left:
        mainAxisExtent = size.width;
        leadingScrollOffset = contentSize.width - bounds.right;
        targetMainAxisExtent = bounds.width;
        break;
    }

    final double targetOffset = leadingScrollOffset -
        (mainAxisExtent - targetMainAxisExtent) * alignment;
    final Rect targetRect = bounds.shift(_paintOffsetForPosition(targetOffset));
    return RevealedOffset(offset: targetOffset, rect: targetRect);
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!offset.allowImplicitScrolling) {
      return super.showOnScreen(
        descendant: descendant,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }

    final Rect? newRect = RenderViewportBase.showInViewport(
      descendant: descendant,
      viewport: this,
      offset: offset,
      rect: rect,
      duration: duration,
      curve: curve,
    );
    super.showOnScreen(
      rect: newRect,
      duration: duration,
      curve: curve,
    );
  }

  @override
  Rect describeSemanticsClip(RenderObject child) {
    assert(axis != null);
    switch (axis) {
      case Axis.vertical:
        return Rect.fromLTRB(
          semanticBounds.left,
          semanticBounds.top - cacheExtent,
          semanticBounds.right,
          semanticBounds.bottom + cacheExtent,
        );
      case Axis.horizontal:
        return Rect.fromLTRB(
          semanticBounds.left - cacheExtent,
          semanticBounds.top,
          semanticBounds.right + cacheExtent,
          semanticBounds.bottom,
        );
    }
  }
}
