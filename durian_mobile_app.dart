import 'package:flutter/material.dart';

void main() {
  runApp(DurianSmartFarmApp());
}

class DurianSmartFarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Durian Smart Farm',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DurianSmartFarmHome(),
    );
  }
}

class DurianSmartFarmHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Durian Smart Farm'),
      ),
      body: Center(
        child: Text('Welcome to the Durian Smart Farm App!'),
      ),
    );
  }
}

