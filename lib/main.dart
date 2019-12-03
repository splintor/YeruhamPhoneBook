import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart' as contacts_plugin;
import 'package:native_contact_dialog/native_contact_dialog.dart';
import 'package:intl/intl.dart';
import 'package:package_info/package_info.dart';
import 'package:share/share.dart';

List<Page> pages;
final List<PageViewState> openPageViews = <PageViewState>[];

bool contactPermissionWasGranted = false;
Set<String> contactPhones;

void main() => runApp(YeruhamPhonebookApp());

const String appTitle = 'ספר הטלפונים של ירוחם';
const Locale hebrewLocale = Locale('he', 'IL');
const int searchResultsLimit = 40;
const Duration searchOverflowDuration = Duration(seconds: 2);
const TextStyle emptyListMessageStyle = TextStyle(fontSize: 20);
const double searchResultFontSize = 15;
const String newPagesKeyword = '#חדשים';

class Page {
  Page();
  Page.fromMap(this.page) :
    name = page['name'],
    url = page['url'],
    title = page['title'],
    text = page['text'],
    html = page['html'],
    isDeleted = page['isDeleted'],
    dummyPage = page['dummyPage'];

  dynamic toJson() => page;

  Map<String, dynamic> page;
  String name;
  String url;
  String title;
  String text;
  String html;
  bool isDeleted;
  bool dummyPage;
}

class YeruhamPhonebookApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(primarySwatch: Colors.purple),
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

String formatNumberWithCommas(int number) => NumberFormat.decimalPattern().format(number);

Future<Page> getAboutPage() async {
  final Future<PackageInfo> packageInfoPromise = PackageInfo.fromPlatform();
  int mails = 0;
  int phones = 0;
  for (Page page in pages.where((Page p) => p.isDeleted != true)) {
    mails += RegExp(r'\S+@\S+')
        .allMatches(page.text)
        .length;
    phones += RegExp(r'[^>=\/\d-][\d-]{8,}')
        .allMatches(page.text)
        .length;
  }

  PackageInfo packageInfo;

  try {
    packageInfo = await packageInfoPromise;
  } catch (e) {
    packageInfo = PackageInfo(version: 'N/A', buildNumber: '?');
  }

  return Page()
    ..title = 'אפליקצית ספר הטלפונים של ירוחם'
    ..dummyPage = true
    ..html = '''<table width="100%" style="font-size: 1.2em;"><tbody><tr><td><div dir='rtl'>
        האפליקציה נכתבה ב<a href="https://github.com/splintor/YeruhamPhoneBook">קוד פתוח</a>
         על-ידי שמוליק פלינט
        (<a href="mailto:splintor@gmail.com">splintor@gmail.com</a>)
       בעזרת 
        <a href="https://flutter.dev/">Flutter</a>.<br><br>
        זוהי גרסה <b>${packageInfo.version}+${packageInfo.buildNumber}</b><br><br>
        ספר הטלפונים כולל
        <b>${formatNumberWithCommas(pages.length)}</b>
        דפים.<br><br>
        מספרי טלפון: ${formatNumberWithCommas(phones)}<br><br>
        כתובות מייל: ${formatNumberWithCommas(mails)}<br><br>
        </div></td></tr></tbody>''';
}

Page getErrorPage(String title, Object error) {
  return Page()
    ..title = title
    ..html = '''
    <table><tbody><tr><td>
      <code style="color: red;">${error.toString()}</code>
    </td></tr></tbody>
    ''';
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
          fontSize: searchResultFontSize,
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
    return TextSpan(
      children: linkify(text.length > 350 ? text.substring(0, 350) : text),
      style: const TextStyle(fontSize: searchResultFontSize),
    );
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
                fontSize: 18,
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

class PageDataValue {
  PageDataValue(RegExpMatch match)
      : label = match.group(1).trim(),
        htmlValue = match.group(2),
        innerText = RegExp(r'>([^<]+)<').firstMatch(match.group(2))?.group(1)?.trim() ?? match.group(2).trim();

  String label;
  String htmlValue;
  String innerText;

  bool isPhoneValue() => innerText.contains(RegExp(r'^[\d+-]{8,}$'));
  String phoneValue() => isPhoneValue() ? innerText.replaceAll(RegExp(r'[\s-+=]'), '') : null;
  String toUrlPart() => isPhoneValue() ? phoneValue() : innerText;
}

class PageHTMLProcessor {
  PageHTMLProcessor(this.page)
      : html = page.dummyPage == true ? page.html : page.html
      .replaceFirst('<table', '<table width="100%" style="font-size: 1.4em;"')
      .replaceAll('font-size:10pt', '')
      .replaceAll('background-color:transparent', '')
      .replaceAll(RegExp(r" ?style=';*'"), '')
      .replaceAll(RegExp(r'[\u2000-\u2BFF]'), '')
      .replaceAllMapped(
      RegExp(r'<span>([^<]*)</span>'), (Match match) => match.group(1))
      .replaceAll(RegExp(r"<img src='[^']*twitter[^']*'"),
      "<img width='36' height='36' src='https://icon-library.net/images/twitter-social-media-icon/twitter-social-media-icon-19.jpg'")
      .replaceAll(RegExp(r"<img src='[^']*facebook[^']*'"),
      "<img width='40' height='40' src='https://icon-library.net/images/official-facebook-icon/official-facebook-icon-16.jpg'")
      .replaceAll(RegExp(r"alt='https:\/\/www.facebook.com[^']*'"), '')
      .replaceAllMapped(RegExp(r'([\d-+]{8,})([^"])'),
          (Match match) => '<a href="tel:${match.group(1).replaceAll(
          RegExp(r'[-+]+'), '')}">${match.group(1)}</a>${match.group(2)}') {
    dataValues = RegExp(r'<div[^>]*>([^<:]*):\s*(((?!</div>).)+)')
        .allMatches(html.replaceAll('<br/>', '</div><div>'))
        .map((RegExpMatch match) => PageDataValue(match))
        .toList(growable: false);

    phoneValues = dataValues.where((PageDataValue v) =>
        v.isPhoneValue()).toList(growable: false);
    mailValues = dataValues.where((PageDataValue v) =>
        v.label.contains(RegExp(r'(mail|מייל)'))).toList(growable: false);

    final PageDataValue homeValue = getValueForLabel(
        'טלפון', mustBePhone: true);
    for (PageDataValue v in phoneValues) {
      if (!inContact(v.phoneValue())) {
        appendAddContactLink(v,
            givenName: v.label.contains(RegExp(r'^(טלפון|נייד|בית)$'))
                ? null
                : v.label, homePhone: homeValue);
      }
    }

    html = html.replaceAllMapped(RegExp(r'<a href="tel:05[^>]*>([^<]+)</a>'), (Match match) =>
        '${match.group(0)} <a href="whatsapp://send?phone=${match.group(1).replaceAll('-', '')}">'
            '<img width="30" height="26" style="top: 6px; position: relative;" src="https://icon-library.net//images/whatsapp-icon-android/whatsapp-icon-android-28.jpg"></a>');
  }

  Page page;
  String html;
  List<PageDataValue> dataValues;
  List<PageDataValue> phoneValues;
  List<PageDataValue> mailValues;

  bool hasLabel(String label) =>
      dataValues.any((PageDataValue v) => v.label == label);

  PageDataValue getValueForLabel(String label, { bool mustBePhone = false }) {
    final PageDataValue dataValue = dataValues.firstWhere((PageDataValue v) =>
    v.label == label, orElse: () => null);
    if (mustBePhone && dataValue != null && !dataValue.isPhoneValue()) {
      print('Unexpected phone value: ${dataValue.innerText}');
    }

    return dataValue;
  }

  bool inContact(String phoneNumber) =>
      contactPhones != null && contactPhones.contains(phoneNumber);

  void appendAddContactLink(PageDataValue dataValue,
      {String givenName, String familyName, PageDataValue homePhone}) {
    givenName ??= getPageGivenName();
    familyName ??= getPageFamilyName();
    String phones = dataValue.toUrlPart();
    if (homePhone != null && homePhone != dataValue &&
        !inContact(homePhone.phoneValue())) {
      phones += ',' + homePhone.toUrlPart();
    }

    String url = 'action:addUser?givenName=$givenName&familyName=$familyName&phones=$phones';
    final List<PageDataValue> addressValues = dataValues.where((
        PageDataValue v) => v.label == 'כתובת').toList(growable: false);
    if (addressValues.isNotEmpty) {
      if (addressValues.length > 1) {
        throw 'More than one address in ${page.title}';
      }

      url += '&address=${addressValues[0].htmlValue}';
    }

    if (mailValues.isNotEmpty) {
      String emails;
      if (mailValues.length == 1 || phoneValues.length == 1 ||
          (phoneValues.length == 2 && homePhone != null)) {
        emails = mailValues.map((PageDataValue v) => v.toUrlPart()).join(',');
      } else {
        final int index = phoneValues.indexOf(dataValue);
        emails =
        index < mailValues.length ? mailValues[index].toUrlPart() : null;
      }

      if (emails != null) {
        url += '&emails=$emails';
      }
    }

    final String htmlValue = dataValue.htmlValue.replaceFirst(RegExp(r'<div>\s*$'), '');

    html = html.replaceFirst(htmlValue, htmlValue + '''
                <a href="$url" style="position: relative; top: 9px; right: 7px; text-decoration: none; color: purple;">
                  <svg width="32px" height="32px" viewBox="0 0 24 24" version="1.1" xmlns="http://www.w3.org/2000/svg">
                    <g stroke="none" stroke-width="1" fill="purple">
                      <path d="M17,17 L17,20 L16,20 L16,17 L13,17 L13,16 L16,16 L16,13 L17,13 L17,16 L20,16 L20,17 L17,17 Z M12,20 L7,20 C6.44771525,20 6,19.5522847 6,19 L6,17 C6,14.4353804 7.60905341,12.2465753 9.87270435,11.3880407 C8.74765126,10.68015 8,9.42738667 8,8 C8,5.790861 9.790861,4 12,4 C14.209139,4 16,5.790861 16,8 C16,9.42738667 15.2523487,10.68015 14.1272957,11.3880407 C13.8392195,11.573004 13.4634542,11.7769904 13,12 L13,10.829 C14.165,10.417 15,9.307 15,8 C15,6.343 13.657,5 12,5 C10.343,5 9,6.343 9,8 C9,9.307 9.835,10.417 11,10.829 L11,12.1 C8.718,12.564 7,14.581 7,17 L7,19 L12,19 L12,20 Z"></path>
                    </g>'
                  </svg>
                </a>
                ''');
  }

  String getPageFamilyName() =>
      page.title
          .split(RegExp(r'\s'))
          .last;

  String getPageGivenName() =>
      page.title.substring(0, page.title.length - getPageFamilyName().length)
          .trim();
}

class PageView extends StatefulWidget {
  const PageView(this.page) : super();

  final Page page;

  @override
  PageViewState createState() => PageViewState(page);
}

class PageViewState extends State<PageView> {
  PageViewState(this.page): html = PageHTMLProcessor(page).html {
    openPageViews.add(this);
  }

  @override
  void dispose() {
    super.dispose();
    openPageViews.remove(this);
  }

  final Page page;
  String html;
  WebViewController webViewController;

  void checkForHtmlChanges() {
    final String newHtml = PageHTMLProcessor(page).html;
    if (html != newHtml) {
      html = newHtml;
      webViewController.loadUrl(getDataUrlForHtml());
    }
  }

  void onMenuSelected(String itemValue) {
    switch (itemValue) {
      case 'copyPageUrl':
        Clipboard.setData(ClipboardData(text: page.url));
        return;

      case 'openPageInBrowser':
        openUrl(page.url);
        return;
    }
  }

  String getDataUrlForHtml() =>
      Uri.dataFromString(html, mimeType: 'text/html', encoding: Encoding.getByName('UTF-8')).toString();

  void onWebViewCreated(WebViewController controller) => webViewController = controller;

  NavigationDecision onWebViewNavigation(NavigationRequest navigation, BuildContext context) {
    final String pageUrlBase = RegExp(r'https:\/\/[^\/]+\/').firstMatch(
        page.url ?? '')?.group(0);
    if (pageUrlBase != null && navigation.url.startsWith(pageUrlBase)) {
      final Page page = pages.firstWhere((Page p) =>
      p.url == navigation.url);
      if (page == null) {
        openUrl(navigation.url);
      } else {
        openPage(page, context);
      }
    } else if (navigation.url.startsWith('action:addUser?')) {
      addContact(navigation.url);
    } else {
      openUrl(navigation.url);
    }

    return NavigationDecision.prevent;
  }

  void addContact(String url) {
    final String queryString = Uri.decodeQueryComponent(
        url.split('?')[1]);
    final Contact contact = Contact();
    for (List<String> keyValue in queryString.split('&').map((
        String v) => v.split('='))) {
      final String value = keyValue[1];
      switch (keyValue[0]) {
        case 'givenName':
          contact.givenName = value;
          break;

        case 'familyName':
          contact.familyName = value;
          break;

        case 'address':
          contact.postalAddresses =
          <PostalAddress>[PostalAddress(label: 'בית', street: value)];
          break;

        case 'phones':
          contact.phones = value.split(',').map((String v) => Item(
              label: v.startsWith('05') ? 'mobile' : 'home',
              value: v));
          break;

        case 'emails':
          contact.emails = value.split(',').map((String v) =>
              Item(label: 'home', value: v));
          break;
      }
    }

    NativeContactDialog.addContact(contact);
  }

  String getPageInnerText() => page.html
      .replaceAll(RegExp(r'<(div|br)[^>]*>'), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'(\s*\n)+'), '\n')
      .trim();

  FloatingActionButton getShareButton() {
    return FloatingActionButton.extended(
        onPressed: () => Share.share('${page.title}\n${getPageInnerText()}', subject: page.title),
        label: const Text('שתף'),
        icon: Icon(Icons.share),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(
          title: Text(page.title),
          actions: page.url == null ? null : <Widget>[
            PopupMenuButton<String>(
                onSelected: onMenuSelected,
                itemBuilder: (BuildContext context) =>
                <PopupMenuItem<String>>[
                  PopupMenuItem<String>(
                    value: 'copyPageUrl',
                    child: const Text('העתק את כתובת הדף'),
                  ),
                  PopupMenuItem<String>(
                    value: 'openPageInBrowser',
                    child: const Text('פתח דף בדפדפן'),
                  ),
                ]),
          ],
        ),
        body: WebView(
          initialUrl: getDataUrlForHtml(),
          onWebViewCreated: onWebViewCreated,
          navigationDelegate: (NavigationRequest navigation) => onWebViewNavigation(navigation, context),
        ),
        floatingActionButton: getShareButton(),
      );
}

class _MainState extends State<Main> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SharedPreferences _prefs;
  List<Page> _searchResults;
  Timer _searchOverflowTimer;
  bool _isUserVerified = false;
  final TextEditingController _phoneNumberController = TextEditingController();
  String _phoneNumber = '';
  final TextEditingController _searchTextController = TextEditingController();
  String _searchString = '';

  Future<void> fetchData() async {
    try {
      final http.Response response = await http.get(getDataUrl());

      if (response.statusCode == 200) {
        _prefs.setString('data', response.body);
        final dynamic jsonData = json.decode(response.body);
        setState(() {
          pages = parseData(jsonData, growable: false);
          setLastUpdateDate(jsonData);
        });
      } else {
        throw 'Server returned an error: ${response.statusCode} ${response.body}';
      }
    } catch (e) {
      showError('טעינת הנתונים נכשלה.', e);
    }
  }

  List<Page> parseData(dynamic jsonData, {@required bool growable}) {
    final List<Map<String, dynamic>> dynamicPages = jsonData['pages'].cast<
        Map<String, dynamic>>();
    return dynamicPages.map((Map<String, dynamic> page) => Page.fromMap(page))
        .toList(growable: growable);
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
        page.isDeleted != true && page.text.replaceAll(RegExp(r'[-\.]'), '').contains(number),
        orElse: () => null);
  }

  @override
  void initState() {
    super.initState();

    _phoneNumberController.addListener(() =>
        setState(() => _phoneNumber = _phoneNumberController.text)
    );

    _searchTextController.addListener(() =>
        handleSearchChanged(_searchTextController.text));

    PermissionHandler().requestPermissions(
        <PermissionGroup>[PermissionGroup.contacts])
        .then((Map<PermissionGroup, PermissionStatus> permissionsMap) async {
      if (permissionsMap[PermissionGroup.contacts] ==
          PermissionStatus.granted) {
        contactPermissionWasGranted = true;
        loadPhoneContacts();
      }
    });

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        _prefs = prefs;
        _phoneNumber = _prefs.getString('validationNumber') ?? '';
        if (_phoneNumber?.isEmpty ?? true) {
          prefs.remove('data');
          fetchData();
        } else {
          final String dataString = _prefs.getString('data');
          pages = parseData(json.decode(dataString), growable: true);
          _isUserVerified = true;
          checkForUpdates(forceUpdate: false);
        }
      });
    });

    WidgetsBinding.instance.addObserver(
        LifecycleEventHandler(() => loadPhoneContacts()));
  }

  Future<void> loadPhoneContacts() async {
    if (!contactPermissionWasGranted) {
      return;
    }

    final Iterable<contacts_plugin.Contact> contacts =
        await contacts_plugin.ContactsService.getContacts(withThumbnails: false);

    contactPhones = Set<String>.from(contacts.expand<String>(
            (contacts_plugin.Contact contact) =>
            contact.phones.map(
                    (contacts_plugin.Item item) =>
                    item.value
                        .replaceAll(RegExp(r'[- ()]'), '')
                        .replaceAll('+972', '0')
            )));

    updateAllPageViews();
  }

  void updateAllPageViews() {
    for (PageViewState pageView in openPageViews) {
      pageView.checkForHtmlChanges();
    }
  }

  void checkPhoneNumber() {
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
        page.isDeleted != true && searchWords.every((String word) => isPageMatchWord(page, word))).toList(
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
            searchOverflowDuration, () =>
              setState(() => _searchOverflowTimer = null),
          );
        });
      }
    }

    setState(() => _searchResults = result);
  }

  FloatingActionButton getFeedbackButton() {
    return _searchString.isEmpty || _searchResults == null ? FloatingActionButton.extended(
      onPressed: () async {
        const String url = 'mailto:splintor@gmail.com?subject=ספר הטלפונים של ירוחם';
        await openUrl(url);
      },
      label: const Text('משוב'),
      icon: Icon(Icons.send),
    ) : null;
  }

  int getLastUpdateDate() {
    try {
      return _prefs.getInt('lastUpdateDate');
    } catch(e) {
      return 0;
    }
  }

  String getDataUrl({int lastUpdateDate = 0}) {
    return 'https://script.google.com/macros/s/AKfycbwk3WW_pyJyJugmrj5ZN61382UabkclrJNxXzEsTDKrkD_vtEc/exec?UpdatedAfter=' +
        DateTime.fromMillisecondsSinceEpoch(lastUpdateDate).toIso8601String();
  }

  void setLastUpdateDate(dynamic jsonData) => _prefs.setInt('lastUpdateDate', jsonData['maxDate']);

  String getUpdateStatus(int updatedPagesCount) {
    switch(updatedPagesCount) {
      case 0: return 'לא נמצאו עדכונים.';
      case 1: return 'דף אחד עודכן.';
      default: return '$updatedPagesCount דפים עודכנו.';
    }
  }

  Future<void> checkForUpdates({bool forceUpdate = true}) async {
    showInSnackBar('בודק אם יש עדכונים...');
    try {
      final http.Response response = await http.get(
          getDataUrl(lastUpdateDate: getLastUpdateDate())
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        final List<Page> receivedPages = parseData(jsonData, growable: false);
        final List<Page> updatedPages = <Page>[];

        setState(() {
          for (Page updatedPage in receivedPages) {
            pages.removeWhere((Page p) => p.url == updatedPage.url);
            if (updatedPage.isDeleted != true) {
              pages.add(updatedPage);
              updatedPages.add(updatedPage);
            }
          }
          setLastUpdateDate(jsonData);
          if (forceUpdate || updatedPages.isNotEmpty) {
            showInSnackBar(getUpdateStatus(updatedPages.length),
                actionLabel: updatedPages.isEmpty ? null : 'הצג',
                actionHandler: updatedPages.isEmpty ? null : () =>
                    setState(() {
                      _searchTextController.text = newPagesKeyword;
                      _searchString = newPagesKeyword;
                      _searchResults = updatedPages;
                    }));
          }
        });

        if (updatedPages.isNotEmpty) {
          final Map<String, List<Page>> updatedData = <String, List<Page>>{
            'pages': pages
          };
          _prefs.setString('data', jsonEncode(updatedData));
        }
      } else {
        showError('טעינת העדכון נכשלה.', 'Status Code is ${response.statusCode}');
      }
    } catch (e) {
      showError('טעינת העדכון נכשלה', e);
    }
  }

  TextField buildSearchField() {
    return TextField(
      controller: _searchTextController,
      maxLines: 1,
      autofocus: true,
      style: const TextStyle(
        fontSize: 20,
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
      return Image.asset('./assets/round_irus.png');
    } else if (_searchResults.length > searchResultsLimit && _searchString != newPagesKeyword) {
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
            onEditingComplete: checkPhoneNumber,
            onSubmitted: (String value) => checkPhoneNumber(),
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
        child: RaisedButton(
            onPressed: getNumberPage(_phoneNumber) == null ? null : () =>checkPhoneNumber(),
            color: Colors.deepPurpleAccent,
            child: const Text('המשך'),
            textTheme: ButtonTextTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16)),
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

  Future<void> onMenuSelected(String itemValue) async {
    switch(itemValue) {
      case 'about':
        openPage(await getAboutPage(), context);
        return;

      case 'openInBrowser':
        openUrl('https://sites.google.com/site/yeruchamphonebook/');
        return;

      case 'checkForUpdates':
        checkForUpdates();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(appTitle),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: onMenuSelected,
              itemBuilder: (BuildContext context) =>
              <PopupMenuItem<String>>[
                PopupMenuItem<String>(
                  value: 'about',
                  child: const Text('אודות'),
                ),
                PopupMenuItem<String>(
                  value: 'openInBrowser',
                  child: const Text('פתח בדפדפן'),
                ),
                PopupMenuItem<String>(
                  value: 'checkForUpdates',
                  child: const Text('בדוק אם יש עדכונים'),
                ),
              ]),
        ],
      ),
      body: buildMainWidget(),
      floatingActionButton: getFeedbackButton(),
    );
  }

  void showError(String title, Object error) {
    showInSnackBar(title, isWarning: true, actionLabel: 'פרטים', actionHandler: () => openPage(getErrorPage(title, error), context));
  }

  void showInSnackBar(String value, { bool isWarning = false, String actionLabel, Function actionHandler }) {
    final SnackBarAction action = actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: actionHandler);
    final Text content = Text(value, style: TextStyle(color: isWarning ? Colors.red : null));
    _scaffoldKey.currentState.showSnackBar(SnackBar(action: action, content: content));
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  LifecycleEventHandler(this.resumeCallBack);

  final Function resumeCallBack;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeCallBack();
    }
  }
}
