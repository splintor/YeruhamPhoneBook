import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

const String appTitle = 'ספר הטלפונים של ירוחם';
const Locale hebrewLocale = Locale('he', 'IL');

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: Main(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        hebrewLocale,
      ],
      locale: hebrewLocale,
    );
  }
}

class Main extends StatefulWidget {
  Main({Key key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  SharedPreferences _prefs;
  dynamic _pages;
  bool _isUserVerified = false;
  TextEditingController _phoneNumberConroller;
  String _phoneNumber = '';

  final String getAllDataUrl =
      'https://script.google.com/macros/s/AKfycbwk3WW_pyJyJugmrj5ZN61382UabkclrJNxXzEsTDKrkD_vtEc/exec?UpdatedAfter=1970-01-01T00:00:00.000Z';
  Future<dynamic> fetchData(SharedPreferences prefs) async {
    final http.Response response = await http.get(getAllDataUrl);

    if (response.statusCode == 200) {
      // If the call to the server was successful, parse the JSON.
      prefs.setString('data', response.body);
      setState(() {
        _pages = parseData();
      });
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load data');
    }
  }

  dynamic parseData() {
    final String dataString = _prefs.getString('data');
    final dynamic jsonData = json.decode(dataString);
    return jsonData['pages'];
  }

  bool isNumberValid(String number) {
    if (number?.isEmpty ?? true) {
      return false;
    }

    number = number.replaceAll(RegExp(r'\D'), '');

    if (number.length < 8) {
      print('Validation number is too short:' + number);
      return false;
    }

    for (final dynamic page in _pages) {
      final String pageText = page['text'].replaceAll(RegExp(r'[-\.]'), '');
      if (pageText.contains(number)) {
        _prefs.setString('validationNumber', number);
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      if (!prefs.containsKey('data')) {
        fetchData(prefs);
      }
      setState(() {
        _prefs = prefs;
        _pages = parseData();
        _phoneNumber = _prefs.getString('phone-number') ?? '';
        if (_phoneNumber?.isEmpty ?? true) {
          _phoneNumberConroller = TextEditingController();
          _phoneNumberConroller.addListener(() {
            setState(() {
              _phoneNumber = _phoneNumberConroller.text;
            });
          });
        } else {
          _isUserVerified = true;
        }
      });
    });
  }

  Future<void> checkPhoneNumber() async {
    if (isNumberValid(_phoneNumber)) {
      await _prefs.setString('phone-number', _phoneNumber);

      setState(() {
        // TO DO: implement real search, including fetching the data on not found
        _isUserVerified = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainWidget;
    if (_prefs == null || _pages == null) {
      mainWidget = Center(child: const Text('טוען...'));
    } else if (_isUserVerified) {
      mainWidget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'כאן יש להכניס את הדף הראשי',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      );
    } else {
      mainWidget =
          Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'האפליקציה מיועדת לתושבי ירוחם.\n\nבכדי לוודא התאמה, יש להכניס את מספר הטלפון שלך:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            )),
        Container(
          child: TextField(
              controller: _phoneNumberConroller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: _phoneNumber.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _phoneNumberConroller.clear();
                        }),
              )),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        ),
        Container(
          child: RaisedButton(
              onPressed: _phoneNumber.isEmpty ? null : () => checkPhoneNumber(),
              child: const Text('המשך')),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(appTitle),
      ),
      body: mainWidget,
    );
  }
}
