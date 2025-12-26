import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Needed for the Timer

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {

    print("Attempting to connect to Firebase...");
    
    const firebaseOptions = FirebaseOptions(
      apiKey: "AIzaSyCWQDxGE1QtPxwmsG6nbyAuEllqBc8b4DE", 
      appId: "1:568997659466:web:bad8dd030f093e3304b7b3", 
      messagingSenderId: "568997659466", 
      projectId: "clipboard-sync-bfe1d",
      storageBucket: "clipboard-sync-bfe1d.firebasestorage.app", 

      databaseURL: "https://clipboard-sync-bfe1d-default-rtdb.firebaseio.com",
    );

    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    
    print("Firebase Connection Successful!");
    runApp(const MyApp());
    
  } catch (e) {
    print("CRASH DURING STARTUP: $e");

    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Text(
                "STARTUP ERROR:\n\n$e", 
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, 
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ClipboardHomePage(),
    );
  }
}

class ClipboardHomePage extends StatefulWidget {
  const ClipboardHomePage({super.key});

  @override
  State<ClipboardHomePage> createState() => _ClipboardHomePageState();
}

class _ClipboardHomePageState extends State<ClipboardHomePage> {

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("current_clipboard");
  
  String _localContent = "Waiting for sync...";
  bool _isSyncingFromCloud = false; // Prevents infinite loops
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    

    _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkLocalClipboard();
    });

    _listenToCloud();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  void _checkLocalClipboard() async {
    try {
      if (_isSyncingFromCloud) return; 

      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

      if (data != null && data.text != null && data.text != _localContent) {
        setState(() {
          _localContent = data.text!;
        });


        await _dbRef.set({
          "text": data.text,
          "device": "Unknown Device",
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cloud Synced! ☁️"), duration: Duration(milliseconds: 500)),
          );
        }
      }
    } catch (e) {
      print("Error checking clipboard: $e");
    }
  }

  void _listenToCloud() {
    try {
      _dbRef.onValue.listen((event) async {
        final data = event.snapshot.value as Map?;
        if (data == null) return;

        String cloudText = data['text'];

        ClipboardData? localData = await Clipboard.getData(Clipboard.kTextPlain);

        if (localData?.text != cloudText) {
          _isSyncingFromCloud = true; 
          
          await Clipboard.setData(ClipboardData(text: cloudText));
          
          setState(() {
            _localContent = cloudText;
          });

          await Future.delayed(const Duration(seconds: 3)); 
          _isSyncingFromCloud = false;
        }
      }, onError: (error) {
         print("Firebase Listen Error: $error");
      });
    } catch (e) {
      print("Error setting up listener: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("⚡ Clipboard Sync")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.copy_all, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "Current Clipboard:",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3))
                ),
                child: Text(
                  _localContent,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Keep this app OPEN to sync.",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}