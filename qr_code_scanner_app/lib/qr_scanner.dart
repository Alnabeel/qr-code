import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRScannerPage extends StatefulWidget {
  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: (result != null)
                  ? Text(
                      'Barcode Type: ${result!.format}   Data: ${result!.code}')
                  : Text('Scan a code'),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
      });

      // Parse the QR code data
      final data = jsonDecode(result!.code!);
      final email = data['email'];
      final id = data['id'];

      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latitude = position.latitude;
      final longitude = position.longitude;

      // Get location name using OpenCage
      String locationName = await _getLocationName(latitude, longitude);

      // Create a document in Appwrite
      await _createDocument(email, id, latitude, longitude, locationName);
    });
  }

  Future<String> _getLocationName(double latitude, double longitude) async {
    const String apiKey =
        '7478b02988a84ccd93340551d11a755c'; // Replace with your OpenCage API key
    final String url =
        'https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final components = data['results'][0]['components'];
      final locationName = components['city'] ??
          components['town'] ??
          components['village'] ??
          'Unknown Location';

      return locationName;
    } else {
      throw Exception('Failed to get location name');
    }
  }

  Future<void> _createDocument(String email, String id, double latitude,
      double longitude, String locationName) async {
    Client client = Client()
        .setEndpoint(
            'https://cloud.appwrite.io/v1') // Replace with your Appwrite endpoint
        .setProject('66d2bfe6002a8bb432b3'); // Replace with your project ID

    // Corrected: Use 'Databases' instead of 'Database'
    Databases databases = Databases(client);

    final data = {
      'status': "present",
      'check_in': DateTime.now().toIso8601String(),
      'location': locationName,
      "employee": id
    };

    try {
      await databases.createDocument(
        databaseId: '66d2c2610028fa44c5aa', // Replace with your database ID
        collectionId: '66d2d1fb00154ceaa29b', // Replace with your collection ID
        documentId: ID.unique(), // unique id
        data: data,
      );
      print('Document created successfully!');
    } catch (e) {
      print('Failed to create document: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
