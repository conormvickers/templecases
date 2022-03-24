import 'dart:async';
import 'dart:convert';
// import 'dart:html';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyBk5DL4lAaQJmICPoTCXYIdggcVLuI7PSY",
          authDomain: "templecases.firebaseapp.com",
          projectId: "templecases",
          databaseURL: "https://templecases-default-rtdb.firebaseio.com",
          storageBucket: "templecases.appspot.com",
          messagingSenderId: "634631322520",
          appId: "1:634631322520:web:5ed158e651eaf0b8b389ed",
          measurementId: "G-NZP88GJ70M"));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temple Dermatology Viewer',
      scrollBehavior: MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown
        },
      ),
      theme: ThemeData(
        primarySwatch: Colors.red,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

TransformationController recieved_controller = TransformationController();

int current_index = 0;

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _controllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    updateDrawer();
    slideController = TransformationController();

    _image = Image.network(
      "assets/t.jpeg",
      fit: BoxFit.contain,
    );
    _loading = false;

    if (status == "linked") {
      start_listener();
    }
    asyncSetup();

    database.ref("ok").onValue.listen((event) {
      final a = event.snapshot.value as Map ?? {"ok": false};

      if (name != "Conor") {
        if (a["ok"]) {
        } else {
          stop_driving();
        }
      }
    });
  }

  asyncSetup() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString("name") ?? "?";
    askName();
  }

  askName() {
    showDialog(
        context: context,
        builder: (context) {
          TextEditingController j = TextEditingController(text: name);
          j.selection =
              TextSelection(baseOffset: 0, extentOffset: j.text.length);
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("who dis?"),
                TextField(
                  controller: j,
                  autofocus: true,
                  onSubmitted: (text) {
                    done_with_name(j.text);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                      onPressed: (() {
                        done_with_name(j.text);
                      }),
                      child: Text("done")),
                )
              ],
            ),
          );
        });
  }

  done_with_name(String j) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("name", j);
    Navigator.of(context).pop();
    setState(() {
      name = j;
    });
  }

  String driver_name = "?";

  final TransformationController _transformationController =
      TransformationController();
  Animation<Matrix4> _animationReset;
  AnimationController _controllerReset;

  void _onAnimateReset() {
    _transformationController.value = _animationReset.value;
    if (!_controllerReset.isAnimating) {
      _animationReset.removeListener(_onAnimateReset);
      _animationReset = null;
      _controllerReset.reset();
    }
  }

  void _animateResetInitialize() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(_controllerReset);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  Matrix4 last_recieved = Matrix4.identity();
  void animateToRecievedPoint() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: last_recieved,
    ).animate(_controllerReset);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

// Stop a running reset to home transform animation.
  void _animateResetStop() {
    _controllerReset.stop();
    _animationReset?.removeListener(_onAnimateReset);
    _animationReset = null;
    _controllerReset.reset();
  }

  @override
  void dispose() {
    _controllerReset.dispose();
    super.dispose();
  }

  TransformationController slideController;
  Image _image;
  bool _loading = true;
  String fetchResult = '';

  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;

  firebase_storage.Reference ref;

  double progress = 0;
  List<Image> images = [];
  double images_progress = 0;
  double images_total = 0;

  initImage(String fullPath) async {
    setState(() {
      _loading = true;
      images = [];
      images_progress = 0;
    });
    current_index = int.parse(fullPath);
    ref = storage.ref('/').child(fullPath + "/");
    if (status == "driver") {
      start_sending();
    }

    final all = await ref.listAll();
    images_total = all.items.length.toDouble();
    setState(() {});

    for (final element in all.items) {
      if (element.name.endsWith(".jpeg")) {
        String url = await element.getDownloadURL();
        images_progress++;
        setState(() {});
        images.add(Image.network(url, fit: BoxFit.contain, loadingBuilder:
            (BuildContext context, Widget child,
                ImageChunkEvent loadingProgress) {
          if (loadingProgress != null) {
            print(element.name +
                ' ' +
                loadingProgress.cumulativeBytesLoaded.toString());
            double percent = loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes;
            return Container(
              child: LinearProgressIndicator(value: percent),
              width: 100,
            );
          }
          return child;
        }));
      } else if (element.name.endsWith(".txt")) {
        Uint8List downloadedData = await element.getData();
        rawInfo = utf8.decode(downloadedData);
      }
    }

    _image = images[current_image];

    _image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (info, call) {
          print('Networkimage is fully loaded and saved');

          setState(() {
            _loading = false;
          });
        },
      ),
    );
  }

  String rawInfo;
  List<String> caseSections;

  List<Widget> drawerItems = [];

  updateDrawer() {
    print("updating drawer");

    var listRef = storage.ref('/');
    List<String> d = [];

    listRef.listAll().then((res) {
      res.prefixes.forEach((itemRef) => {
            // All the items under listRef.

            d.add(itemRef.name),
            // if (itemRef.fullPath.endsWith('.txt'))
            //   {
            //     updateInfo(itemRef),
            //   }
            // else
            //   {

            // }
          });
      d.sort((a, b) {
        return int.parse(a).compareTo(int.parse(b));
      });
      d.forEach(((element) {
        drawerItems.add(ListTile(
          title: Text(element),
          onTap: () {
            current_index = int.parse(element);
            current_image = 0;
            Navigator.pop(context);
            initImage(element);
          },
        ));
      }));
      setState(() {});
    }).onError((error, stackTrace) => null);
  }

  IconData infoIcon = Icons.info;
  int current_image = 0;
  List<String> info = [
    "No information for this case",
    "Click on another case for more information!"
  ];

  double infoHeight = 0;
  Color infoColor = Colors.transparent;

  Widget loadingWidget() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitCubeGrid(
            color: Colors.red,
          ),
          Text('Loading #' + current_index.toString()),
          images.length > 0
              ? Container(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: images_progress / images_total,
                  ),
                )
              : Container()
        ],
      ),
    );
  }

  bool showInformation = false;
  bool showAnswer = false;

  List<Container> infoTiles = [];

  CollectionReference trans =
      FirebaseFirestore.instance.collection('transposition');
  FirebaseDatabase database = FirebaseDatabase.instance;

  String status = "linked";

  String last_set = "";
  bool sending = false;
  start_sending() async {
    String b = printMarker();

    if (b != last_set) {
      print("sending update");
      last_set = b;
      // goToMarker(b);

      // trans
      //     .doc("1")
      //     .set({"a": b})
      //     .then((value) => print("User Added"))
      //     .catchError((error) => print("Failed to add user: $error"));

      await database.ref("trans").set({"a": b});

      Future.delayed(Duration(seconds: 1), (() {
        start_sending();
      }));
    } else {
      sending = false;
    }
  }

  StreamSubscription<DatabaseEvent> subscription;
  StreamSubscription<DatabaseEvent> driver_info_subscription;
  StreamSubscription<DatabaseEvent> penSubscription;

  start_listener() {
    subscription = database.ref("trans").onValue.listen((event) {
      print(event.snapshot.value);
      final e = event.snapshot.value as Map;
      String stra = e["a"];
      goToMarker(stra);
    });

    driver_info_subscription = database.ref("driver").onValue.listen((event) {
      print(event.snapshot.value);
      if (event.snapshot.value != null) {
        final e = event.snapshot.value as Map;
        driver_name = e["driver"];
        showInformation = e["show_info"] ?? false;
        showAnswer = e["show_answer"] ?? false;
        setState(() {});
      }
    });

    penSubscription = database.ref("draw").onValue.listen((event) {
      if (event.snapshot.value != null) {
        final e = event.snapshot.value as Map;

        final xs = e["dx"];
        final ys = e["dy"];
        if (xs == null || ys == null) {
          points = [];
          return;
        }
        if (xs.asMap().length != ys.asMap().length) {
          return;
        }
        points = [];
        xs.asMap().forEach((key, value) {
          points.add(Offset(value, ys[key]));
        });
        setState(() {});
      }
    });
  }

  stop_listener() {
    print("subs cancelled");
    subscription.cancel();
    driver_info_subscription.cancel();
    penSubscription.cancel();
  }

  GlobalKey view_key = GlobalKey();
  GlobalKey test_key = GlobalKey();
  String name = "?";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: [
          Center(
            child: Text(
              "Case #" + current_index.toString() + "  ",
              style: TextStyle(fontSize: 22),
            ),
          )
        ],
        title: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                    onPressed: (() {
                      askName();
                    }),
                    child: Text(
                      name,
                      style: TextStyle(color: Colors.white),
                    )),
                Text(
                  "name",
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            Container(
              width: 10,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                    child: Text(
                  status,
                  style: TextStyle(color: Colors.white),
                )),
                Text(
                  "status",
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            Container(
              width: 10,
            ),
            status == "disconnected"
                ? Icon(FlutterIcons.unlink_faw)
                : Icon(FlutterIcons.cloud_check_mco),
            Container(
              width: 10,
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 200),
                child: Column(
                  children: [
                    Expanded(
                        child: Container(
                            child: Image.asset(
                      'tt.png',
                      fit: BoxFit.contain,
                    ))),
                  ],
                ),
              ),
            ),
            ...drawerItems
          ],
        ),
      ),
      body: Container(
        color: status == "driver" ? Colors.red.withAlpha(100) : Colors.white,
        child: Stack(
          children: [
            _loading
                ? loadingWidget()
                : Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey, width: 1)),
                                    child: InteractiveViewer(
                                      key: view_key,
                                      scaleEnabled: !pen_enabled,
                                      panEnabled:
                                          !pen_enabled, // Set it to false to prevent panning.
                                      boundaryMargin: EdgeInsets.all(80),

                                      minScale: 0.5,
                                      maxScale: 8,
                                      constrained: true,
                                      clipBehavior: Clip.none,

                                      onInteractionEnd: (details) {
                                        if (status == "driver") {
                                          if (!sending) {
                                            sending = true;
                                            start_sending();
                                          } else {
                                            print("sending bool is off");
                                          }
                                        }
                                      },
                                      transformationController:
                                          _transformationController,
                                      child: FittedBox(
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 1000,
                                              width: 1000,
                                              child: FittedBox(child: _image),
                                            ),
                                            points.length > 2
                                                ? FittedBox(
                                                    child: CustomPaint(
                                                      size: Size(1000, 1000),
                                                      painter: penPainter(),
                                                    ),
                                                  )
                                                : Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IgnorePointer(
                                  ignoring: !pen_enabled,
                                  child: Center(
                                    child: FittedBox(
                                      child: Container(
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.black)),
                                        height: 1000,
                                        width: 1000,
                                        child: pen_enabled
                                            ? GestureDetector(
                                                onPanStart: (details) {
                                                  print("tap!");
                                                  points = [];
                                                  add_point(
                                                      details.localPosition);
                                                },
                                                onPanUpdate: (details) {
                                                  add_point(
                                                      details.localPosition);
                                                },
                                                onPanEnd: (details) async {
                                                  last_point = Offset(0, 0);
                                                  final point_storex = points
                                                      .map((e) => e.dx)
                                                      .toList();
                                                  final point_storey = points
                                                      .map((e) => e.dy)
                                                      .toList();
                                                  await database
                                                      .ref("draw")
                                                      .child("dx")
                                                      .set(point_storex);
                                                  await database
                                                      .ref("draw")
                                                      .child("dy")
                                                      .set(point_storey);
                                                },
                                              )
                                            : Container(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          showInformation ? Divider() : Container(),
                          showInformation
                              ? Expanded(
                                  child: Container(
                                  color: Colors.white,
                                  child: Stack(
                                    children: [
                                      SingleChildScrollView(
                                          controller: ScrollController(),
                                          child: Column(
                                            children: [
                                              Container(
                                                height: 20,
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(content()),
                                              ),
                                              Container(
                                                height: 40,
                                              ),
                                            ],
                                          )),
                                      Positioned(
                                        right: 10,
                                        child: ElevatedButton(
                                            onPressed: () async {
                                              showAnswer = !showAnswer;
                                              if (status == "driver") {
                                                await database
                                                    .ref("driver")
                                                    .set({
                                                  "driver": name,
                                                  "show_info": showInformation,
                                                  "show_answer": showAnswer,
                                                });
                                              }

                                              setState(() {});
                                            },
                                            child: Text(showAnswer
                                                ? "hide answer"
                                                : "show answer")),
                                      ),
                                    ],
                                  ),
                                ))
                              : Container()
                        ],
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              style: ButtonStyle(
                                  backgroundColor: showInformation
                                      ? MaterialStateProperty.all(Colors.red)
                                      : MaterialStateProperty.all(
                                          Colors.white)),
                              onPressed: () async {
                                showInformation = !showInformation;
                                if (status == "driver") {
                                  await database.ref("driver").set({
                                    "driver": name,
                                    "show_info": showInformation,
                                    "show_answer": showAnswer,
                                  });
                                }
                                setState(() {});
                              },
                              child: Icon(
                                FlutterIcons.text_mco,
                                color:
                                    showInformation ? Colors.white : Colors.red,
                              ),
                            ),
                            Container(
                              height: 10,
                            ),
                            OutlinedButton(
                              style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all(Colors.white)),
                              onPressed: () => {_animateResetInitialize()},
                              child: Icon(
                                FlutterIcons.zoom_out_mdi,
                              ),
                            ),
                            Container(
                              height: 50,
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: images.length > 1
                            ? Column(
                                children: [
                                  Expanded(child: Container()),
                                  FittedBox(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        OutlinedButton(
                                            style: ButtonStyle(
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white)),
                                            child: Icon(Icons.swipe_left_alt),
                                            onPressed: current_image > 0
                                                ? () {
                                                    current_image--;
                                                    _image =
                                                        images[current_image];
                                                    _animateResetInitialize();
                                                    setState(() {});
                                                    if (status == "driver") {
                                                      sending = true;
                                                      start_sending();
                                                      clear_pen();
                                                    }
                                                  }
                                                : null),
                                        DotsIndicator(
                                          dotsCount: images.length,
                                          position: current_image.toDouble(),
                                          decorator: DotsDecorator(
                                            size: const Size.square(9.0),
                                            activeSize: const Size(18.0, 9.0),
                                            activeShape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5.0)),
                                          ),
                                        ),
                                        OutlinedButton(
                                            style: ButtonStyle(
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white)),
                                            child: Icon(Icons.swipe_right_alt),
                                            onPressed: current_image <
                                                    images.length - 1
                                                ? () {
                                                    current_image++;
                                                    _image =
                                                        images[current_image];
                                                    _animateResetInitialize();
                                                    setState(() {});
                                                    if (status == "driver") {
                                                      sending = true;
                                                      start_sending();
                                                      clear_pen();
                                                    }
                                                  }
                                                : null),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 10,
                                  )
                                ],
                              )
                            : Container(),
                      ),
                    ],
                  ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    status == "linked"
                        ? Text(
                            driver_name + " is driving",
                            style: TextStyle(fontSize: 10),
                          )
                        : Container(),
                    status == "driver"
                        ? Container(
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(15)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 12,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      "You are driving  ",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: OutlinedButton(
                                        onPressed: () {
                                          stop_driving();
                                        },
                                        style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                                    Colors.white)),
                                        child: Text("STOP")),
                                  ),
                                ]),
                          )
                        : Container(),
                    Container(
                      width: 8,
                    ),
                    OutlinedButton(
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.white)),
                        onPressed: status == "driver"
                            ? () {
                                stop_driving();
                              }
                            : () {
                                try_driving();

                                // start_listener();
                              },
                        child: Icon(FlutterIcons.ship_wheel_mco)),
                    Container(
                      width: 10,
                      height: 0,
                    ),
                  ],
                ),
                status == "driver"
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: OutlinedButton(
                                style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        Colors.white)),
                                onPressed: () {
                                  clear_pen();
                                },
                                child: Icon(
                                  FlutterIcons.eraser_ent,
                                  color: Colors.red,
                                )),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: OutlinedButton(
                                style: ButtonStyle(
                                    backgroundColor: pen_enabled
                                        ? MaterialStateProperty.all(Colors.red)
                                        : MaterialStateProperty.all(
                                            Colors.white)),
                                onPressed: () {
                                  pen_enabled = !pen_enabled;
                                  setState(() {});
                                },
                                child: Icon(
                                  FlutterIcons.marker_faw5s,
                                  color:
                                      pen_enabled ? Colors.white : Colors.red,
                                )),
                          ),
                        ],
                      )
                    : Container(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String content() {
    if (showAnswer) {
      return rawInfo;
    }
    final split = rawInfo.split("\n");
    final f = split.where((element) => !element.contains("%")).toList();
    final a = f
        .join("\n")
        .substring(0, f.join("\n").toUpperCase().indexOf("CATEGORY"));
    return a;
  }

  bool pen_enabled = false;
  double top = 0;
  double left = 0;
  Offset last_point = Offset(0, 0);

  add_point(Offset localPosition) {
    double zoom = _transformationController.value[0];

    double w = view_key.currentContext.size.width;
    double h = view_key.currentContext.size.height;
    double min = math.min(w, h);
    print(w.toString() + " " + h.toString());

    double x = -1 * (_transformationController.value[12] / zoom) / min;
    double y = -1 * (_transformationController.value[13] / zoom) / min;
    double per_top = (localPosition.dy / 1000 / zoom) + y;
    double per_left = (localPosition.dx / 1000 / zoom) + x;
    print(localPosition.toString() + x.toString() + ' ' + y.toString());

    top = 1000 * per_top;
    left = 1000 * per_left;

    final now = Offset(left, top);
    if ((now - last_point).distance.abs() > 10) {
      points.add(now);
      last_point = now;
      setState(() {});
    }
  }

  clear_pen() async {
    points = [];
    setState(() {});
    final point_storex = points.map((e) => e.dx).toList();
    final point_storey = points.map((e) => e.dy).toList();
    await database.ref("draw").child("dx").set(point_storex);
    await database.ref("draw").child("dy").set(point_storey);
  }

  stop_driving() async {
    sending = false;
    pen_enabled = false;
    setState(() {
      status = "linked";
    });
    start_listener();
    if (name == "Conor") {
      database.ref("ok").set({"ok": true});
    }
    await database.ref("driver").set({
      "driver": "no one",
      "show_info": showInformation,
      "show_answer": showAnswer
    });
  }

  try_driving() async {
    bool ok = false;
    if (name == "Conor") {
      database.ref("ok").set({"ok": false});
      ok = true;
    } else {
      final respon = await database.ref("ok").get();
      print(respon.value);
      final temp = respon.value as Map;
      ok = temp["ok"];
    }

    if (ok) {
      setState(() {
        status = "driver";
      });
      stop_listener();
      await database.ref("driver").set({
        "driver": name,
        "show_info": showInformation,
        "show_answer": showAnswer
      });
    }
  }

  String printMarker() {
    double w = 1;
    double h = 1;
    if (view_key.currentContext != null) {
      w = view_key.currentContext.size.width;
      h = view_key.currentContext.size.height;
    }

    double min = 0;
    if (w > h) {
      min = w;
    } else {
      min = h;
    }
    double zoom = _transformationController.value[0];
    double x = -1 * (_transformationController.value[12] / zoom) / min;
    double y = -1 * (_transformationController.value[13] / zoom) / min;
    print(current_index.toString() +
        '*' +
        zoom.toStringAsFixed(2) +
        ',' +
        x.toStringAsFixed(2) +
        ',' +
        y.toStringAsFixed(2) +
        '***');
    String j = current_index.toString() +
        "_" +
        current_image.toString() +
        "," +
        zoom.toString() +
        ',' +
        x.toString() +
        "," +
        y.toString();
    return j;
  }

  goToMarker(String where) {
    List<String> whereSplit = where.split(',');

    String targetImageName = whereSplit[0];
    String indd = targetImageName.split('_')[0];
    String indi = targetImageName.split('_')[1];
    print("recieved " + indd + ":" + indi);
    if (current_index != int.parse(indd)) {
      print("changing index to: " + (indd));
      setState(() {
        _loading = true;
      });
      initImage(indd);
    } else if (current_image != int.parse(indi)) {
      print("changing picture to: " + indi);
      current_image = int.parse(indi);
      if (current_image < images.length) {
        _image = images[current_image];
        setState(() {});
      }
    }

    double zoom = double.parse(whereSplit[1]);
    double x = double.parse(whereSplit[2]);
    double y = double.parse(whereSplit[3]);

    print("moving to");

    if (view_key.currentContext == null) {
      print("error wit getting view_key context");
      return;
    }
    double w = view_key.currentContext.size.width;
    double h = view_key.currentContext.size.height;
    double min = 0;
    if (w > h) {
      min = w;
    } else {
      min = h;
    }

    last_recieved = Matrix4.fromList([
      zoom,
      0,
      0,
      0,
      0,
      zoom,
      0,
      0,
      0,
      0,
      zoom,
      0,
      -zoom * x * (min),
      -zoom * y * (min),
      0,
      1
    ]);
    animateToRecievedPoint();
  }
}

List<Offset> points = [];

class penPainter extends CustomPainter {
  //         <-- CustomPainter class
  @override
  void paint(Canvas canvas, Size size) {
    final pointMode = ui.PointMode.polygon;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(pointMode, points, paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}
