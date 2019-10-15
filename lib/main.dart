import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

List<Page> pages;

void main() => runApp(YeruhamPhonebookApp());

const String appTitle = 'ספר הטלפונים של ירוחם';
const Locale hebrewLocale = Locale('he', 'IL');
const int searchResultsLimit = 40;
const Duration searchOverflowDuration = Duration(seconds: 2);
const TextStyle emptyListMessageStyle = TextStyle(fontSize: 22.0);

class Page {
  String name;
  String url;
  String title;
  String text;
  String html;
  bool dummyPage;

  static Page fromDynamic(dynamic page) {
    final Page result = Page();
    result.name = page['name'];
    result.url = page['url'];
    result.title = page['title'];
    result.text = page['text'];
    result.html = page['html'];
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
          disabledColor: Colors.grey,
          buttonTheme: ButtonThemeData(
            buttonColor: Colors.pink,
            textTheme: ButtonTextTheme.primary,
          )
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

Future<void> openUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

void openPage(Page page, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (BuildContext context) => PageView(page)),
  );
}

const String urlPattern = r'https?:/\/\\S+';
const String emailPattern = r'\S+@\S+';
const String phonePattern = r'[\d-]{9,}';
final RegExp linkRegExp = RegExp('($urlPattern)|($emailPattern)|($phonePattern)', caseSensitive: false);

WidgetSpan buildLinkComponent(String text, String linkToOpen) => WidgetSpan(
    child: InkWell(
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
      ),
      onTap: () => openUrl(linkToOpen),
    )
);

List<InlineSpan> linkify(String text) {
  final List<InlineSpan> list = <InlineSpan>[];
  final RegExpMatch match = linkRegExp.firstMatch(text);
  if (match == null) {
    list.add(TextSpan(text: text));
    return list;
  }

  if (match.start > 0) {
    list.add(TextSpan(text: text.substring(0, match.start)));
  }

  final String linkText = match.group(0);
  if (linkText.contains(RegExp(urlPattern, caseSensitive: false))) {
    list.add(buildLinkComponent(linkText, linkText));
  }
  else if (linkText.contains(RegExp(emailPattern, caseSensitive: false))) {
    list.add(buildLinkComponent(linkText, 'mailto:$linkText'));
  }
  else if (linkText.contains(RegExp(phonePattern, caseSensitive: false))) {
    list.add(buildLinkComponent(linkText, 'tel:$linkText'));
  } else {
    throw 'Unexpected match: $linkText';
  }

  list.addAll(linkify(text.substring(match.start + linkText.length)));

  return list;
}

class PageItem extends StatelessWidget {
  const PageItem({ Key key, this.page }) : super(key: key);

  final Page page;

  TextSpan buildLines() {
    final String text = page.text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    return TextSpan(children: linkify(text));
  }

  @override
  Widget build(BuildContext context) =>
      InkWell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              page.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 2.0)),
            Text.rich(
              buildLines(), maxLines: 5, overflow: TextOverflow.ellipsis,),
            const Padding(padding: EdgeInsets.only(bottom: 6.0)),
          ],
        ),
        onTap: () => openPage(page, context),
      );
}

class PageView extends StatelessWidget {
  const PageView(this.page);

  final Page page;

  String htmlToShow() {
    return page.html
        .replaceFirst('<table', '<table width="100%" style="font-size: 1.2em;"')
        .replaceAll('font-size:10pt', '')
        .replaceAllMapped(RegExp(r'([^>\d-])([\d-]{8,})'),
            (Match match) => match.group(1) +
            '<a href="tel:${match.group(2).replaceAll('-', '')}">'
                '${match.group(2)}'
                '</a>');
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(
          title: Text(page.title),
        ),
        body: WebView(
          initialUrl: Uri.dataFromString(
              htmlToShow(),
              mimeType: 'text/html',
              encoding: Encoding.getByName('UTF-8')).toString(),
          navigationDelegate: (NavigationRequest navigation) {
            final String pageUrlBase = RegExp(r'https:\/\/[^\/]+\/').firstMatch(page.url).group(0);
            if (navigation.url.startsWith(pageUrlBase)) {
              final Page page = pages.firstWhere((Page p) => p.url == navigation.url);
              if (page == null) {
                openUrl(navigation.url);
              } else {
                openPage(page, context);
              }
            } else {
              openUrl(navigation.url);
            }
            return NavigationDecision.prevent;
          },
        ),
      );
}

class _MainState extends State<Main> {
  SharedPreferences _prefs;
  List<Page> _searchResults;
  Timer _searchOverflowTimer;
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
        pages = parseData();
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  List<Page> parseData() {
    final String dataString = _prefs.getString('data');
    final dynamic jsonData = json.decode(dataString);
    final Iterable<dynamic> dynamicPages = jsonData['pages'];
    final Iterable<Page> pages = dynamicPages.map<Page>((dynamic page) =>
        Page.fromDynamic(page));
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
      return null;
    }

    if ((number.startsWith('05') || number.startsWith('07')) &&
        number.length < 10) {
      return null;
    }

    return pages.firstWhere((Page page) =>
        page.text.replaceAll(RegExp(r'[-\.]'), '').contains(number),
        orElse: () => null);
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

    _searchTextController.addListener(() {
      handleSearchChanged(_searchTextController.text);
    });

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        _prefs = prefs;
        _phoneNumber = _prefs.getString('validationNumber') ?? '';
        if (_phoneNumber?.isEmpty ?? true) {
          prefs.remove('data');
          fetchData();
        } else {
          pages = parseData();
          _isUserVerified = true;
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
    final int pos = s.indexOf('"');
    if (pos == -1) {
      return s.split(' ');
    }

    final int nextPos = s.indexOf('"', pos + 1);
    if (nextPos == -1) {
      return parseToWords(s.replaceFirst('"', ''));
    }

    return parseToWords(s.substring(0, pos))
      ..add(s.substring(pos + 1, nextPos - pos - 1))
      ..addAll(parseToWords(s.substring(nextPos + 1)));
  }

  bool isPageMatchWord(Page page, String word) {
    if (page.dummyPage == true) {
      return false;
    }

    if (word.startsWith('##')) {
      final RegExp re = RegExp(word.substring(2));
      return page.title.contains(re) || page.text.contains(re) ||
          page.text.replaceAll('-', '').contains(re);
    }

    return page.title.toLowerCase().contains(word) ||
        page.text.toLowerCase().contains(word) ||
        (word.contains(RegExp(r'^[\d-]*$')) &&
            page.text.replaceAll('-', '').contains(word.replaceAll('-', '')));
  }

  int compareSearchIndexes(String s1, String s2) {
    final int index1 = s1.indexOf(_searchString);
    final int index2 = s2.indexOf(_searchString);

    if (index1 == index2) {
      return 0;
    }
    
    if (index1 == -1) {
      return 1;
    }

    if (index2 == -1) {
      return -1;
    }

    return index1.compareTo(index2);
  }

  void handleSearchChanged(String searchString) {
    setState(() => _searchString = searchString);
    if (_searchString == '___resetValidationNumber') {
      _prefs.remove('validationNumber');
      _prefs.remove('validationName');
      setState(() {
        _searchTextController.clear();
        _isUserVerified = false;
      });
    }

    final List<String> searchWords = parseToWords(_searchString.toLowerCase())
        .map((String s) => s.trim())
        .where((String w) => w.isNotEmpty)
        .toList(growable: false);
    final List<Page> result = pages.where((Page page) =>
        searchWords.every((String word) => isPageMatchWord(page, word))).toList(
        growable: false);

    result.sort((Page a, Page b) {
      final int titleCompare = compareSearchIndexes(a.title, b.title);
      if (titleCompare != 0) {
        return titleCompare;
      }

      final int textCompare = compareSearchIndexes(a.text, b.text);
      if (textCompare != 0) {
        return textCompare;
      }

      return a.title.compareTo(b.title);
    });

    if (result.length > searchResultsLimit) {
      if (_searchOverflowTimer != null || _searchResults == null ||
          _searchResults.length <= searchResultsLimit) {
        setState(() {
          if (_searchOverflowTimer != null) {
            _searchOverflowTimer.cancel();
          }

          _searchOverflowTimer = Timer(
            searchOverflowDuration, () => setState(() => _searchOverflowTimer = null),
          );
        });
      }
    }

    setState(() => _searchResults = result);
  }

  Future<void> sendFeedback() async {
    const String url = 'mailto:splintor@gmail.com?subject=ספר הטלפונים של ירוחם';
    await openUrl(url);
  }

  void checkForUpdates() {
    // TODO(sflint): implement checkForUpdates
  }

  TextField buildSearchField() {
    return TextField(
      controller: _searchTextController,
      maxLines: 1,
      autofocus: true,
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
    );
  }

  Widget buildSearchContent() {
    if (_searchString.isEmpty || _searchResults == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
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
      );
    } else if (_searchResults.length > searchResultsLimit) {
      if (_searchOverflowTimer == null) {
        return Align(
          alignment: Alignment.topRight,
          child: Text.rich(
              TextSpan(
                  style: emptyListMessageStyle,
                  children: <TextSpan>[
                    const TextSpan(text: 'נמצאו '),
                    TextSpan(
                      text: _searchResults.length.toString(),
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                    const TextSpan(
                        text: ' תוצאות מתאימות. יש לצמצם את התוצאות ע"י הוספת עוד מילות חיפוש.'),
                  ]
              )
          ),
        );
      } else {
        return null;
      }
    } else if (_searchResults.isEmpty) {
      return Align(
        alignment: Alignment.topRight,
        child: Text.rich(
            TextSpan(
                style: emptyListMessageStyle,
                children: <TextSpan>[
                  const TextSpan(text: 'לא נמצאו תוצאות מתאימות לחיפוש '),
                  TextSpan(
                    text: _searchString,
                    style: const TextStyle(color: Colors.blueAccent),
                  ),
                ]
            )
        ),
      );
    } else {
      return ListView(
        children: _searchResults.map<PageItem>((Page page) => PageItem(page: page)).toList(growable: false),
      );
    }
  }

  Widget buildSearchView() {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) =>
            SingleChildScrollView(
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 10.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                buildSearchField(),
                                const Padding(padding: EdgeInsets.only(bottom: 10.0)),
                                Expanded(
                                    child: Container(
                                        height: 20.0,
                                        child: buildSearchContent()
                                    )
                                )
                              ],
                            )
                        )
                    )
                )
            )
    );
  }

  Widget buildValidationView() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
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
            onPressed: getNumberPage(_phoneNumber) == null ? null : () =>
                checkPhoneNumber(),
            title: 'המשך'),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      ),
    ]);
  }

  Widget buildMainWidget() {
    if (_prefs == null || pages == null) {
      return Center(child: const Text('טוען...'));
    } else if (_isUserVerified) {
      return buildSearchView();
    } else {
      return buildValidationView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appTitle),
      ),
      body: buildMainWidget(),
    );
  }
}
