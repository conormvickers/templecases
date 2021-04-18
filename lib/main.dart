import 'dart:convert';
import 'dart:html';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  @override
  void initState() {

    super.initState();
    _controllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    updateDrawer();
    slideController = TransformationController();

    _image = Image.network("assets/t.jpeg",

    );
    _loading = false;
  }


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
  String url;
  firebase_storage.Reference ref;
  String status;
  double progress = 0;

  initApp() async {
    await Firebase.initializeApp();
    updateDrawer();
  }
  initImage(String fullPath, [bool firebase = true]) async {

    setState(() {
      fetchResult = 'Initialized App';
      updateDrawer();
    });

    if (firebase) {
      ref = storage.ref('/').child(fullPath);
      print(fullPath);
      url = await ref.getDownloadURL();
    }else{
      url = fullPath;
    }


    print('got download url' + url);



    _image = Image.network(url,
      fit: BoxFit.contain,
    );


    _image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
            (info, call) {
          print('Networkimage is fully loaded and saved' );
            setState(() {
              _loading = false;

            });
        },
      ),
    );
  }



  List<Widget> drawerItems = [
  ];

  updateDrawer() {
    drawerItems = [];
    var listRef = storage.ref().child('/temple/');
    listRef
        .listAll()
        .then((res) => {
              res.prefixes.forEach((folderRef) => {
                    print(folderRef),
                  }),
              res.items.forEach((itemRef) => {
                    // All the items under listRef.
                    print(itemRef),
                    drawerItems.add(ListTile(
                      title: Text(itemRef.name.substring(0,itemRef.name.indexOf('.'))),
                      onTap: () => {
                        setState(() => {
                              _loading = true,
                            }),
                        Navigator.pop(context),
                        initImage(itemRef.fullPath)
                      },
                    ))
                  }),
            })
        .onError((error, stackTrace) => null);

    setState(() {});
  }
  IconData infoIcon = Icons.info;
  String info = "This is a bunch of text data.\n"
      "This is a line break to see if it works\n\n\n"
      "Should work even if multiple lines\nScroll\nDown\nIf\nneeded";

  _showInfo() {
    setState(() {
      showInformation = !showInformation;
      if (showInformation) {
        infoIcon = Icons.download_outlined;
      }else{
        infoIcon = Icons.info;
      }
    });
  }

  Widget loadingWidget =  Container(
    alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitCubeGrid(
            color: Colors.red,
          ),

          Text('Loading...'),
        ],
      ),
    );


  bool showInformation = false;
  Widget bottomField() {
    if (showInformation) {
      return Container(height: 100, color: Colors.black26,

      child: Row(
        children: [Expanded(child: Container()),
          SingleChildScrollView(
            child: Container(
                padding: EdgeInsets.symmetric(horizontal: 50),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15)
                ),
                child: Text( 'Case Information:\n\n' + info, style: TextStyle(color: Colors.black),)

            ),
          ),
          Expanded(child: Container())
        ],
      ),);
    }

    return Container(height: 0,);
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("Temple Philly Derm"),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200),
              child: Column(
                children: [
                  Expanded(child: Container(child: Image.asset('tt.png', fit: BoxFit.contain,))),
                  Text('Today''s Cases')
                ],
              ),
            ) ,),
            ...drawerItems],
        ),
      ),
      bottomNavigationBar: bottomField(),
      body:
      _loading
          ? loadingWidget
          :
      InteractiveViewer(
        panEnabled: true, // Set it to false to prevent panning.
        boundaryMargin: EdgeInsets.all(80),
        minScale: 0.5,
        maxScale: 4,
        constrained: true,
        clipBehavior: Clip.none,
        transformationController: _transformationController,
        child:
        Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: _image,
        ),
      ),

      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => {_showInfo()},
            tooltip: 'Information',
            child: Icon(infoIcon),
          ),
          Container(width: 10, height: 0,),
          FloatingActionButton(
            onPressed: () => {_animateResetInitialize()},
            tooltip: 'Reset Zoom',
            child: Icon(Icons.fullscreen),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
