import 'package:example/inner_scroll_webview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nested_inner_scroll/nested_inner_scroll.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Demo"),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          FlatButton(
            onPressed: () {
              Navigator.of(context)
                  .push(CupertinoPageRoute(builder: (BuildContext context) {
                return const WebViewInnerScrollDemo();
              }));
            },
            child: const Text("WebView demo"),
          ),
          FlatButton(
            onPressed: () {
              Navigator.of(context)
                  .push(CupertinoPageRoute(builder: (BuildContext context) {
                return const NestedInnerScrollDemo();
              }));
            },
            child: const Text("NormalView demo"),
          ),
        ],
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // etc.
      };
}

class WebViewInnerScrollDemo extends StatefulWidget {
  const WebViewInnerScrollDemo({Key? key}) : super(key: key);

  @override
  _WebViewInnerScrollDemoState createState() => _WebViewInnerScrollDemoState();
}

class _WebViewInnerScrollDemoState extends State<WebViewInnerScrollDemo> {
  late NestedInnerScrollCoordinator _coordinator;

  final Key _webviewKey = const ValueKey("webview");

  @override
  void initState() {
    super.initState();
    _coordinator = NestedInnerScrollCoordinator(ScrollController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WebViewDemo"),
      ),
      body: CustomScrollView(
        controller: _coordinator.outerController,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              color: Colors.red,
              child: const Center(
                child: Text(
                  "header widget",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: NestedInnerScrollChild(
              scrollKey: _webviewKey,
              child: Scrollable(
                controller: _coordinator.innerController,
                viewportBuilder: (context, offset) {
                  return WebViewDemo(
                      offset: offset, url: "https://flutterchina.club/docs/");
                },
              ),
              coordinator: _coordinator,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 300,
              color: Colors.green,
              child: const Center(
                child: Text(
                  "footer widget",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NestedInnerScrollDemo extends StatefulWidget {
  const NestedInnerScrollDemo({Key? key}) : super(key: key);

  @override
  _NestedInnerScrollDemoState createState() => _NestedInnerScrollDemoState();
}

class _NestedInnerScrollDemoState extends State<NestedInnerScrollDemo> {
  late NestedInnerScrollCoordinator _coordinator;

  final Key _firstInnerKey = const ValueKey("first");

  final Key _secondInnerKey = const ValueKey("second");

  @override
  void initState() {
    super.initState();
    _coordinator = NestedInnerScrollCoordinator(ScrollController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NestedInnerScrollDemo"),
      ),
      floatingActionButton: GestureDetector(
        onTap: _jumpFirstScroll,
        onDoubleTap: _jumpSecondScroll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white,
          ),
          width: 60,
          height: 60,
          child: const Center(
            child: Text("jumpTo"),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _coordinator.outerController,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              color: Colors.red,
              child: const Center(
                child: Text(
                  "header widget",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: NestedInnerScrollChild(
                scrollKey: _firstInnerKey,
                child: ListView.separated(
                  controller: _coordinator.innerController,
                  itemBuilder: (_, idx) => Container(
                    height: 20,
                    child: Text(
                      "first scroll item id: ${idx + 1}",
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    alignment: Alignment.centerLeft,
                  ),
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xff9b9b9b),
                    height: 0.5,
                    indent: 10,
                  ),
                  itemCount: 100,
                ),
                coordinator: _coordinator,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 300,
              color: Colors.green,
              child: const Center(
                child: Text(
                  "footer widget",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: NestedInnerScrollChild(
                scrollKey: _secondInnerKey,
                coordinator: _coordinator,
                child: ListView.separated(
                  controller: _coordinator.innerController,
                  itemBuilder: (_, idx) => Container(
                    height: 20,
                    child: Text(
                      "second scroll item id: ${idx + 1}",
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    alignment: Alignment.centerLeft,
                  ),
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xff9b9b9b),
                    height: 0.5,
                    indent: 10,
                  ),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpFirstScroll() {
    _coordinator.getInnerPosition(_firstInnerKey)?.jumpTo(30);
  }

  void _jumpSecondScroll() {
    _coordinator.getInnerPosition(_secondInnerKey)?.jumpTo(100);
  }
}
