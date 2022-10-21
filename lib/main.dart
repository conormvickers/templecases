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

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.web,
  );
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
    current_image = fullPath;
    setState(() {
      _loading = true;
      images = [];
      images_progress = 0;
    });
    // current_index = int.parse(fullPath);
    ref = storage.ref(fullPath);

    start_sending();

    // final all = await ref.listAll();
    // images_total = all.items.length.toDouble();
    setState(() {});

    String url = "";

    try {
      url = await ref.getDownloadURL();
    } on Exception catch (e) {
      print(e);
      return;
    }
    if (url == null) {
      return;
    }
    _image = Image.network(url, fit: BoxFit.contain, errorBuilder:
        (context, error, stackTrace) {
      print("!!!!!" + error.toString());
      return Text(error.toString());
    }, loadingBuilder:
        (BuildContext context, Widget child, ImageChunkEvent loadingProgress) {
      if (loadingProgress != null) {
        print(
            ref.name + ' ' + loadingProgress.cumulativeBytesLoaded.toString());
        double percent = loadingProgress.cumulativeBytesLoaded /
            loadingProgress.expectedTotalBytes;
        return Container(
          child: LinearProgressIndicator(value: percent),
          width: 100,
        );
      }
      return child;
    });

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
  List<firebase_storage.Reference> tosort = [];
  List<String> allImageNames = [];

  updateDrawer() {
    print("updating drawer");

    var listRef = storage.ref('/');
    List<String> d = [];

    listRef.listAll().then((res) {
      // if (res.items.length < 1) {
      //   return;
      // }

      tosort = res.items;

      tosort.sort((a, b) {
        int aind = a.name.lastIndexOf(".");
        if (aind > 4) {
          aind = 4;
        }

        int bind = b.name.lastIndexOf(".");
        if (bind > 4) {
          bind = 4;
        }
        return double.parse(a.name.substring(0, aind))
            .compareTo(double.parse(b.name.substring(0, bind)));
      });

      tosort.forEach((itemRef) => {
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

      allImageNames = [];
      d.forEach(((element) {
        allImageNames.add(element);
        drawerItems.add(ListTile(
          title: Text(
            element,
            style: TextStyle(color: Colors.black),
          ),
          onTap: () {
            // current_index = int.parse(element);

            Navigator.pop(context);
            initImage(element);
          },
        ));
      }));

      setState(() {});
    }).onError((error, stackTrace) {
      print(error);
    });
  }

  IconData infoIcon = Icons.info;
  String current_image = "";
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
          Text('Loading ' + current_image.toString()),
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
    if (status != "driver") {
      return;
    }
    if (sending) {
      return;
    }
    // String b = printMarker();

    if (b != last_set) {
      print("sending update");
      sending = true;
      last_set = b;
      // goToMarker(b);

      // trans
      //     .doc("1")
      //     .set({"a": b})
      //     .then((value) => print("User Added"))
      //     .catchError((error) => print("Failed to add user: $error"));

      await database.ref("trans").set({"a": b});

      Future.delayed(Duration(seconds: 1), (() {
        sending = false;
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
      if (event.snapshot.value != null && status != "driver") {
        final e = event.snapshot.value as Map;
        String stra = e["a"];
        goToMarker(stra);
      }
    });

    driver_info_subscription = database.ref("driver").onValue.listen((event) {
      print(event.snapshot.value);
      if (event.snapshot.value != null && status != "driver") {
        final e = event.snapshot.value as Map;
        driver_name = e["driver"];
        showInformation = e["show_info"] ?? false;
        showAnswer = e["show_answer"] ?? false;
        setState(() {});
      }
    });

    penSubscription = database.ref("draw").onValue.listen((event) {
      if (event.snapshot.value != null && status != "driver") {
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
        points.add([]);
        if (points.length > 10) {
          points.removeAt(0);
        }
        xs.asMap().forEach((key, value) {
          points.last.add(Offset(value, ys[key]));
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

  List<Widget> pointWidget() {
    List<Widget> toret = [];
    points.asMap().forEach((key, value) {
      if (value.length > 1) {
        toret.add(AnimatedOpacity(
          duration: Duration(seconds: 3),
          opacity: key == points.length - 1 ? 1 : 0,
          child: CustomPaint(
            size: Size(4000, 3000),
            child: Container(
              width: 4000,
              height: 3000,
            ),
            painter: penPainter(key),
          ),
        ));
      }
    });
    return toret;
  }

  GlobalKey view_key = GlobalKey();
  GlobalKey test_key = GlobalKey();
  String name = "?";
  bool debuglines = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: status == "driver"
          ? AppBar(
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
            )
          : null,
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
            ...drawerItems,
            ListTile(
                title: Container(
                    color: Colors.red,
                    child: Row(children: [
                      Expanded(child: Text("Debugging lines")),
                      Switch(
                        value: debuglines,
                        onChanged: (value) {
                          debuglines = value;
                          setState(() {});
                        },
                      )
                    ])))
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
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey, width: 1)),
                            child: InteractiveViewer(
                                key: view_key,
                                scaleEnabled: !pen_enabled,
                                panEnabled:
                                    !pen_enabled, // Set it to false to prevent panning.
                                boundaryMargin: EdgeInsets.all(80000),
                                minScale: 0.5,
                                maxScale: 8,
                                constrained: true,
                                clipBehavior: Clip.none,
                                onInteractionEnd: (details) {
                                  start_sending();
                                },
                                transformationController:
                                    _transformationController,
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                            Expanded(
                                              child: FittedBox(
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      height: 3000,
                                                      width: 4000,
                                                      child: _image,
                                                    ),
                                                    ...pointWidget(),
                                                    IgnorePointer(
                                                      ignoring: !pen_enabled,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                            border: Border.all(
                                                                color: Colors
                                                                    .black)),
                                                        height: 3000,
                                                        width: 4000,
                                                        child: pen_enabled
                                                            ? GestureDetector(
                                                                onPanStart:
                                                                    (details) {
                                                                  print("tap!");
                                                                  points
                                                                      .add([]);
                                                                  if (points
                                                                          .length >
                                                                      10) {
                                                                    points
                                                                        .removeAt(
                                                                            0);
                                                                  }
                                                                  add_point(details
                                                                      .localPosition);
                                                                },
                                                                onPanUpdate:
                                                                    (details) {
                                                                  add_point(details
                                                                      .localPosition);
                                                                },
                                                                onPanEnd:
                                                                    (details) async {
                                                                  final point_storex = points
                                                                      .last
                                                                      .map((e) =>
                                                                          e.dx)
                                                                      .toList();
                                                                  final point_storey = points
                                                                      .last
                                                                      .map((e) =>
                                                                          e.dy)
                                                                      .toList();
                                                                  await database
                                                                      .ref(
                                                                          "draw")
                                                                      .child(
                                                                          "dx")
                                                                      .set(
                                                                          point_storex);
                                                                  await database
                                                                      .ref(
                                                                          "draw")
                                                                      .child(
                                                                          "dy")
                                                                      .set(
                                                                          point_storey);
                                                                },
                                                              )
                                                            : Container(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ]))
                                    ])),
                          ),
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
                                  backgroundColor:
                                      MaterialStateProperty.all(Colors.white)),
                              onPressed: () {
                                start_sending();
                                _animateResetInitialize();
                              },
                              child: Icon(
                                FlutterIcons.fullscreen_mco,
                              ),
                            ),
                            Container(
                              height: 50,
                            ),
                          ],
                        ),
                      ),
                      debuglines
                          ? IgnorePointer(
                              ignoring: true,
                              child: Center(
                                child: FittedBox(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 4000,
                                            height: 3000,
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    width: 20,
                                                    color: Colors
                                                        .lightBlueAccent)),
                                          ),
                                          Container(
                                            width: 4000,
                                            height: 3000,
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    width: 20,
                                                    color: Colors
                                                        .lightBlueAccent)),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 4000,
                                            height: 3000,
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    width: 20,
                                                    color: Colors
                                                        .lightBlueAccent)),
                                          ),
                                          Container(
                                            width: 4000,
                                            height: 3000,
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    width: 20,
                                                    color: Colors
                                                        .lightBlueAccent)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container()
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
                                  if (allImageNames.indexOf(current_image) - 1 <
                                      0) {
                                    return;
                                  }
                                  initImage(allImageNames[
                                      allImageNames.indexOf(current_image) -
                                          1]);
                                  start_sending();
                                  _animateResetInitialize();
                                },
                                child: Icon(
                                  FlutterIcons.left_ant,
                                  color: Colors.red,
                                )),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: OutlinedButton(
                                style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        Colors.white)),
                                onPressed: () {
                                  if (allImageNames.indexOf(current_image) +
                                          1 >=
                                      allImageNames.length - 1) {
                                    return;
                                  }
                                  initImage(allImageNames[
                                      allImageNames.indexOf(current_image) +
                                          1]);
                                  start_sending();
                                  _animateResetInitialize();
                                },
                                child: Icon(
                                  FlutterIcons.right_ant,
                                  color: Colors.red,
                                )),
                          ),
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

  bool pen_enabled = false;
  double top = 0;
  double left = 0;

  add_point(Offset localPosition) {
    if (points.last.length > 0) {
      final last_point = points.last.last;
      if ((localPosition - last_point).distance.abs() > 20) {
        points.last.add(localPosition);

        setState(() {});
      }
    } else {
      if (points.last.length < 1) {
        points.last.add(localPosition);

        setState(() {});
      }
    }
  }

  clear_pen() async {
    points.add([]);
    setState(() {});

    await database.ref("draw").child("dx").set([0]);
    await database.ref("draw").child("dy").set([0]);
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
    double zoom = _transformationController.value[0];
    double xcomp = 0;
    double ycomp = 0;
    double xful = 0;
    double yful = 0;
    if (w * 3 < h * 4) {
      xful = w;

      yful = w * 3 / 4;
      ycomp = ((yful - h) / 2) * (1 - zoom);
    } else {
      xful = h * 4 / 3;
      xcomp = ((xful - w) / 2) * (1 - zoom);
      // yful = h;
    }

    double x = ((_transformationController.value[12] + xcomp) / zoom) / xful;
    double y = ((_transformationController.value[13] + ycomp) / zoom) / xful;

    String j = current_image.toString() +
        "," +
        zoom.toString() +
        ',' +
        x.toString() +
        "," +
        y.toString();
    print(j);
    print(ycomp);
    print(ycomp / y);
    return j;
  }

  goToMarker(String where) {
    List<String> whereSplit = where.split(',');

    String targetImageName = whereSplit[0];

    print("recieved " + targetImageName);
    if (current_image != targetImageName) {
      print("changing index to: " + (targetImageName));
      setState(() {
        _loading = true;
      });
      initImage(targetImageName);
    } else {
      print("already at this image: " + targetImageName);

      setState(() {});
    }

    double zoom = double.parse(whereSplit[1]);
    double x = double.parse(whereSplit[2]);
    double y = double.parse(whereSplit[3]);

    if (view_key.currentContext == null) {
      print("error wit getting view_key context");
      return;
    }

    try {
      double w = 1;
      double h = 1;
      if (view_key.currentContext != null) {
        w = view_key.currentContext.size.width;
        h = view_key.currentContext.size.height;
      }

      double xful = 0;
      double xcomp = 0;
      double ycomp = 0;
      double yful = 0;
      if (w * 3 < h * 4) {
        xful = w;

        yful = w * 3 / 4;
        ycomp = ((yful - h) / 2) * (1 - zoom);
      } else {
        xful = h * 4 / 3;
        xcomp = ((xful - w) / 2) * (1 - zoom);
        // yful = h;
      }
      print("moving to " +
          zoom.toString() +
          " " +
          x.toString() +
          " " +
          y.toString());

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

        //xcomp, 0,

        zoom * x * (xful) - xcomp,
        zoom * y * (xful) - ycomp,
        0,
        1
      ]);
      animateToRecievedPoint();
    } on Exception catch (e) {
      print(e);
    }
  }
}

List<List<Offset>> points = [];

class penPainter extends CustomPainter {
  penPainter(this.index);
  int index;
  //         <-- CustomPainter class
  @override
  void paint(Canvas canvas, Size size) {
    final pointMode = ui.PointMode.polygon;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(pointMode, points[index], paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}
