### Introduction
Flutter Scrollable Widgets like ListView,GridView or powerful CustomScrollView can't nest inner scrollview.
If Nested, inner scrollview will scroll dependently, that's not very good to user.

NestedScrollView give us another choice, but it's not very flexible. For example, We must provide "header+body" widgets.
So I make nested_inner_scroll library inpired by NestedScrollView,this library has features:

1. inner scroll and outer scroll is independent, when we scroll one,other's position will not be affected.
2. When inner scroll at it's edge, it can trigger out scroll view to scroll
3. Support nested fling effect, it's smooth when fling innerview or outview


### Usage
1. new NestedInnerScrollCoordinator instance, it needs one ScrollController as parent
2. give NestedInnerScrollCoordinator.outController to outview as ScrollController
3. prepare Key instance for every innerview as scrollKey property
4. give NestedInnerScrollCoordinator.innerController to innerView as ScrollController
5. wrap every innerview with NestedInnerScrollChild widget
that's all, then you can have nested inner scroll views
you can check example project main.dart for more information

### Other Tips
1. If you want to scroll inner view, you need to do it by ScrollPosition
`_coordinator.getInnerPosition(innerViewKey)?.jumpTo(0)`

2. If you want to have pull to refresh features, you can use 'pull_to_refresh_notification' library

3. Every inner scroll view should have fixed height

### Issues
If you have any problem in use, give issues to me but with template:

### description

### minim code example

### flutter doctor -v info
