import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() => runApp(YeruhamPhonebookApp());

const String appTitle = 'ספר הטלפונים של ירוחם';
const Locale hebrewLocale = Locale('he', 'IL');

class Page {
  String name;
  String title;
  String text;
  bool dummyPage;

  static Page fromDynamic(dynamic page) {
    final Page result = Page();
    result.name = page['name'];
    result.title = page['title'];
    result.text = page['text'];
    result.dummyPage = page['dummyPage'];
    return result;
  }
}

class YeruhamPhonebookApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.pink,
          buttonColor: Colors.pink,
          disabledColor: Colors.grey,
      ),
      home: const Main(),
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
  const Main({Key key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  SharedPreferences _prefs;
  List<Page> _pages;
  bool _isUserVerified = false;
  final TextEditingController _phoneNumberController = TextEditingController();
  String _phoneNumber = '';
  final TextEditingController _searchTextController = TextEditingController();
  String _searchString = '';

  final String getAllDataUrl =
      'https://script.google.com/macros/s/AKfycbwk3WW_pyJyJugmrj5ZN61382UabkclrJNxXzEsTDKrkD_vtEc/exec?UpdatedAfter=1970-01-01T00:00:00.000Z';
  Future<void> fetchData() async {
    final http.Response response = await http.get(getAllDataUrl);

    if (response.statusCode == 200) {
      _prefs.setString('data', response.body);
      setState(() {
        _pages = parseData();
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  List<Page> parseData() {
    final String dataString = _prefs.getString('data');
    final dynamic jsonData = json.decode(dataString);
    final Iterable<dynamic> dynamicPages = jsonData['pages'];
    final Iterable<Page> pages = dynamicPages.map<Page>((dynamic page) => Page.fromDynamic(page));
    return pages.toList(growable: false);
  }

  String normalizedNumber(String number) {
    return number.replaceAll(RegExp(r'\D'), '');
  }

  Page getNumberPage(String number) {
    if (number?.isEmpty ?? true) {
      return null;
    }

    number = normalizedNumber(number);

    if (number.length < 9) {
      print('Validation number is too short:' + number);
      return null;
    }

    if ((number.startsWith('05') || number.startsWith('07')) && number.length < 10) {
      print('Validation cellular number is too short:' + number);
      return null;
    }

    return _pages.firstWhere((Page page) => page.text.replaceAll(RegExp(r'[-\.]'), '').contains(number), orElse: () => null);
  }

  RaisedButton buildRoundedButton({String title, VoidCallback onPressed}) {
    return RaisedButton(
        onPressed: onPressed,
        child: Text(title),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16));
  }

  @override
  void initState() {
    super.initState();

    _phoneNumberController.addListener(() {
      setState(() {
        _phoneNumber = _phoneNumberController.text;
      });
    });

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        _prefs = prefs;
        _phoneNumber = _prefs.getString('validationNumber') ?? '';
        if (_phoneNumber?.isEmpty ?? true) {
          prefs.remove('data');
          fetchData();
        } else {
          _pages = parseData();
          _isUserVerified = true;
          _searchTextController = TextEditingController();
          _searchTextController.addListener(() {
            handleSearchChanged(_searchTextController.text);
          });
        }
      });
    });
  }

  Future<void> checkPhoneNumber() async {
    final Page page = getNumberPage(_phoneNumber);
    if (page != null) {
      _prefs.setString('validationNumber', normalizedNumber(_phoneNumber));
      _prefs.setString('validationName', page.name);

      setState(() {
        _isUserVerified = true;
      });
    }
  }

  List<String> parseToWords(String s) {
    return s.split(' ');
  }

  void handleSearchChanged(String searchString) {
    setState(() {
      _searchString = searchString;
      if (_searchString == '___resetValidationNumber') {
        _prefs.remove('validationNumber');
        _prefs.remove('validationName');
        setState(() {
          _searchTextController.clear();
          _isUserVerified = false;
        });
      }
      // TODO(sflint): search text in pages
    });
  }

  void sendFeedback() {
    // TODO(sflint): implement sendFeedback
  }

  void checkForUpdates() {
    // TODO(sflint): implement checkForUpdates
  }

  @override
  Widget build(BuildContext context) {
    Widget mainWidget;
    if (_prefs == null || _pages == null) {
      mainWidget = Center(child: const Text('טוען...'));
    } else if (_isUserVerified) {
      mainWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextField(
              controller: _searchTextController,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchString.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchTextController.clear();
                        }),
                border: OutlineInputBorder(
                    borderSide: BorderSide(width: 1),
                    borderRadius: BorderRadius.circular(32.0)),
              ),
            ),
            Image.asset(
              './assets/round_irus.png',
              scale: .8,
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  buildRoundedButton(
                      onPressed: checkForUpdates, title: 'בדוק אם יש עדכונים'),
                  buildRoundedButton(
                      onPressed: sendFeedback, title: 'שלח משוב'),
                ]),
          ],
        ),
      );
    } else {
      mainWidget =
          Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'האפליקציה מיועדת לתושבי ירוחם.\n\nבכדי לוודא התאמה, יש להכניס את מספר הטלפון שלך:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            )),
        Container(
          child: TextField(
              controller: _phoneNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: _phoneNumber.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _phoneNumberController.clear();
                        }),
              )),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        ),
        Container(
          child: buildRoundedButton(
              onPressed: getNumberPage(_phoneNumber) == null ? null : () => checkPhoneNumber(),
              title: 'המשך'),
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
