import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contacts_service/contacts_service.dart' as contacts_plugin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:native_contact_dialog/native_contact_dialog.dart';
import 'package:package_info/package_info.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yeruhamphonebook/tags.dart';

import 'httpsCertificates.dart';
import 'icons.dart';
import 'secret.dart';

List<Page> pages;
List<String> tags;
const String siteDomain = 'yeruham-phone-book.vercel.app';
const String siteUrl = 'https://$siteDomain';
final List<PageViewState> openPageViews = <PageViewState>[];
const int previewMaxLines = 8;
const int patchLevel = 1;
final int startOfTime = DateTime(1900, 12, 1).millisecondsSinceEpoch;

bool contactPermissionWasGranted = false;
Set<String> contactPhones;

void main(){
  HttpOverrides.global = AcceptAllHttpOverrides();
  runApp(YeruhamPhonebookApp());
}

const String appTitle = 'ספר הטלפונים של ירוחם';
const Locale hebrewLocale = Locale('he', 'IL');
const int searchResultsLimit = 40;
const Duration searchOverflowDuration = Duration(seconds: 2);
const TextStyle emptyListMessageStyle = TextStyle(fontSize: 20);
const TextStyle tagTitleStyle = TextStyle(fontSize: 22);
const double searchResultFontSize = 20;
const double whatsAppImageSize = 28;
const String newPagesKeyword = '#חדשים';

// https://stackoverflow.com/a/67241469/46635
String stripHtmlTags(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;', multiLine: true), '');
}

class Page {
  Page();

  Page.fromMap(this.page)
      : url = 'https://$siteDomain/${page['title'].replaceAll(' ', '_')}'.replaceAll('"', '%22'),
        title = page['title'],
        text = stripHtmlTags(page['html']),
        tags = (page['tags'] as List<dynamic>)
            ?.map((dynamic tag) => tag as String)
            ?.toList(),
        html = page['html'],
        isDeleted = page['isDeleted'],
        dummyPage = page['dummyPage'];

  dynamic toJson() => page;

  Map<String, dynamic> page;
  String url;
  String title;
  String text;
  List<String> tags;
  String html;
  bool isDeleted;
  bool dummyPage;
}

bool isPageSearchable(Page page) =>
    page.isDeleted != true && page.text.isNotEmpty;

class YeruhamPhonebookApp extends StatelessWidget {
  static const int _primaryColor = 0xFF5F1B68;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData(
          primarySwatch: const MaterialColor(
        _primaryColor,
        <int, Color>{
          50: Color(0xFFF3E5F5),
          100: Color(0xFFE1BEE7),
          200: Color(0xFFCE93D8),
          300: Color(0xFFBA68C8),
          400: Color(0xFFAB47BC),
          500: Color(_primaryColor),
          600: Color(0xFF8E24AA),
          700: Color(0xFF7B1FA2),
          800: Color(0xFF6A1B9A),
          900: Color(0xFF4A148C),
        },
      )),
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
  const Main({Key key, this.openedTag}) : super(key: key);

  final String openedTag;

  @override
  _MainState createState() => _MainState(openedTag);
}

Future<void> openUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

Future<void> openUrlOrPage(
    String url, String phoneNumber, BuildContext context) async {
  String urlToUse = url.contains('%') ? Uri.decodeFull(url) : url;
  urlToUse =
      urlToUse.replaceAll(' ', '_').replaceAll('"', '%22').replaceAll(RegExp(r'^/'), '$siteUrl/');
  final Page page =
      context == null ? null : pages.firstWhere((Page p) => p.url == urlToUse, orElse: () => null);
  if (page == null) {
    openUrl(url);
  } else {
    openPage(page, phoneNumber, context);
  }
}

void openPage(Page page, String phoneNumber, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
        builder: (BuildContext context) => PageView(page, phoneNumber)),
  );
}

void openTag(String tag, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
        builder: (BuildContext context) => Main(openedTag: tag)),
  );
}

String formatNumberWithCommas(int number) =>
    NumberFormat.decimalPattern().format(number);

String replaceEmail(String s) => s.replaceAll(RegExp(r'email\s*:\s*'), 'דוא"ל: ');
String replacePToDiv(String s) => s.replaceAll('<p>', '<div>').replaceAll('</p>', '</div>');

String whatsappUrl(String phone) =>
    'whatsapp://send?phone=${phone.replaceAll('-', '').replaceFirst('0', '+972')}';

String whatsAppLink(String phone) =>
    '<a href="${whatsappUrl(phone)}"><img width="$whatsAppImageSize" height="$whatsAppImageSize" style="top: 8px; position: relative;" src="data:image/jpeg;base64,$whatsappImageData"></a>';

Future<Page> getAboutPage() async {
  final Future<PackageInfo> packageInfoPromise = PackageInfo.fromPlatform();
  int mails = 0;
  int phones = 0;
  for (Page page in pages.where(isPageSearchable)) {
    mails += RegExp(r'\S+@\S+').allMatches(page.text).length;
    phones += RegExp(r'[^>=\/\d-][\d-]{8,}').allMatches(page.text).length;
  }

  PackageInfo packageInfo;

  try {
    packageInfo = await packageInfoPromise;
  } catch (e) {
    packageInfo = PackageInfo(
      appName: 'Unknown',
      packageName: 'Unknown',
      version: 'Unknown',
      buildNumber: 'Unknown',
    );
  }

  const String helpUrl = '$siteUrl/help';

  return Page()
    ..title = 'אפליקצית ספר הטלפונים של ירוחם'
    ..dummyPage = true
    ..html =
        '''<table width="100%" style="font-size: 1.2em;"><tbody><tr><td><div dir='rtl'>
        האפליקציה נכתבה ב<a href="https://github.com/splintor/YeruhamPhoneBook">קוד פתוח</a>
         על-ידי שמוליק פלינט
        (<a href="mailto:splintor@gmail.com">splintor@gmail.com</a>&nbsp;${whatsAppLink('0523843115')})
       בעזרת
        <a href="https://flutter.dev/">Flutter</a>.<br><br>
        זוהי גרסה <b>${packageInfo.version}</b><br><br>
        ספר הטלפונים כולל
        <b>${formatNumberWithCommas(pages.length)}</b> דפים, ${formatNumberWithCommas(phones)} מספרי טלפון ו-${formatNumberWithCommas(mails)} כתובות דוא"ל.
        <br><br>
        הנתונים באפליקצית ספר הטלפונים לקוחים מ<a href="$siteUrl">אתר ספר הטלפונים הישובי</a>.
        <br><br>
        האתר פתוח לכלל תושבי ירוחם. התושבים יכולים (ואף מוזמנים!) להכנס לאתר ולתקן נתונים שגויים, או להוסיף פרטים חדשים. הסבר ניתן למצוא <a href="$helpUrl">כאן</a>.
        <br><br>
        <b>קרדיט על צילום הלוגו של האתר והאפליקציה: ליאור אלמגור – <a href="https://www.fromycamera.com">www.fromycamera.com</a></b>
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

const String anchorPattern =
    '<a [^>]*href=["\']([^"\']+)["\'][^>]*>([^<]*)</a>';
final RegExp anchorPatternRE = RegExp(anchorPattern, caseSensitive: false);
const String urlPattern = 'http[^\'">]+';
final RegExp urlPatternRE = RegExp(urlPattern, caseSensitive: false);
const String emailPattern = r'\S+@\S+';
final RegExp emailPatternRE = RegExp(emailPattern, caseSensitive: false);
const String phonePattern = r'(0[\d-]{8,})|(\*\d{3,})|(\d{3,}\*)';
final RegExp phonePatternRE = RegExp(phonePattern, caseSensitive: false);
final RegExp linkRegExp = RegExp(
    '($anchorPattern)|($urlPattern)|($emailPattern)|$phonePattern',
    caseSensitive: false);
final Image whatsAppImage = Image.memory(base64Decode(whatsappImageData),
    height: whatsAppImageSize, width: whatsAppImageSize);

WidgetSpan buildLinkComponent(String text, String linkToOpen,
        String phoneNumber, BuildContext context) =>
    WidgetSpan(
        child: InkWell(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
          fontSize: searchResultFontSize,
        ),
      ),
      onTap: () => openUrlOrPage(linkToOpen, phoneNumber, context),
    ));

List<InlineSpan> linkify(
    String text, String phoneNumber, BuildContext context) {
  final List<InlineSpan> list = <InlineSpan>[];
  final List<String> lines = text.split('\n');
  if (lines.length > previewMaxLines) {
    text = lines.sublist(0, previewMaxLines - 1).join('\n');
  }
  final RegExpMatch match = linkRegExp.firstMatch(text);
  if (match == null) {
    text = text.trim();
    if (text.isNotEmpty && !text.contains('מילות חיפוש')) {
      list.add(TextSpan(text: text));
    }

    return list;
  }

  if (match.start > 0) {
    list.add(TextSpan(text: text.substring(0, match.start)));
  }

  final String linkText = match.group(0);
  final RegExpMatch anchorMatch = anchorPatternRE.firstMatch(linkText);
  if (anchorMatch != null) {
    if (anchorMatch.group(2).trim().isNotEmpty) {
      list.add(buildLinkComponent(
          anchorMatch.group(2), anchorMatch.group(1), phoneNumber, context));
    }
  } else if (linkText.contains(urlPatternRE)) {
    list.add(buildLinkComponent(linkText, linkText, phoneNumber, null));
  } else if (linkText.contains(emailPatternRE)) {
    list.add(
        buildLinkComponent(linkText, 'mailto:$linkText', phoneNumber, null));
  } else if (linkText.contains(phonePatternRE)) {
    if (linkText.startsWith('05')) {
      list.add(WidgetSpan(
          child: InkWell(
        child: whatsAppImage,
        onTap: () => openUrl(whatsappUrl(linkText)),
      )));
    }
    list.add(buildLinkComponent(
        linkText, phoneNumberUrl(linkText), phoneNumber, null));
  } else {
    throw 'Unexpected match: $linkText';
  }

  list.addAll(linkify(
      text.substring(match.start + linkText.length), phoneNumber, context));

  return list;
}

class PageItem extends StatelessWidget {
  const PageItem({Key key, this.page, this.phoneNumber}) : super(key: key);

  final Page page;
  final String phoneNumber;

  TextSpan buildLines(BuildContext context) {
    final String text = getPageInnerText(page, leaveAnchors: true);
    final List<InlineSpan> lines = linkify(text, phoneNumber, context);

    if (lines.isNotEmpty && lines[lines.length - 1] is TextSpan) {
      final TextSpan textSpan = lines[lines.length - 1];
      if (textSpan.text.trim().isEmpty) {
        lines.removeLast();
      }
    }

    return TextSpan(
      children: lines,
      style: const TextStyle(fontSize: searchResultFontSize, height: 1.6),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              page.title,
              maxLines: 20,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
                decoration: TextDecoration.underline,
              ),
            ),
            tagsList(page.tags,
                filled: false, openTag: openTag, context: context),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 20),
              child: Text.rich(buildLines(context),
                  maxLines: previewMaxLines, overflow: TextOverflow.ellipsis),
            )
          ],
        ),
        onTap: () => openPage(page, phoneNumber, context),
      );
}

class PageDataValue {
  PageDataValue(RegExpMatch match)
      : label = match.group(1).trim(),
        htmlValue = match.group(2),
        innerText =
            RegExp(r'>([^<]+)<').firstMatch(match.group(2))?.group(1)?.trim() ??
                match.group(2).trim();

  String label;
  String htmlValue;
  String innerText;

  bool isPhoneValue() => innerText.contains(RegExp(r'^\*?[\d+-]{8,}\*?$'));

  String phoneValue() =>
      isPhoneValue() ? innerText.replaceAll(RegExp(r'[\s-+=]'), '') : null;

  String toUrlPart() => isPhoneValue() ? phoneValue() : innerText;
}

final RegExp newLineTagsRE = RegExp(r'<(div|br|p)(\s+[^>]+)*/?>');
final RegExp bulletsTagsRE = RegExp(r'<li[^>]*>');
final RegExp anyTagRE = RegExp(r'<[^>]*>');
final RegExp anyTagButAnchorRE = RegExp(r'<[^aA/][^>]*>|</[^aA][^>]*>');
final RegExp multipleNewLinesRE = RegExp(r'(\s*\n)+');

String getPageInnerText(Page page, {bool leaveAnchors}) =>
    replaceEmail(page.html
        .replaceAll(RegExp(r'\n\s*'), ' ')
        .replaceAll(newLineTagsRE, '\n')
        .replaceAll(bulletsTagsRE, '\n* ')
        .replaceAll(leaveAnchors ? anyTagButAnchorRE : anyTagRE, ' ')
        .replaceAll(multipleNewLinesRE, '\n')
        .trim());

final RegExp styleURLRE = RegExp(r" ?style=';*'");
final RegExp specialCharsRE = RegExp(r'[\u2000-\u2BFF]');
final RegExp spanElementRE = RegExp(r'<span>([^<]*)</span>');
final RegExp facebookAltRE = RegExp(r"alt='https:\/\/www.facebook.com[^']*'");
final RegExp phoneNumberRE = RegExp(r'([\d-+]{8,})([^"/\d])');
final RegExp prefixStarPhoneNumberRE = RegExp(r'(\*\d{3,})([^"])');
final RegExp suffixStarPhoneNumberRE = RegExp(r'(\d{3,}\*)([^"])');
final RegExp phoneNumberNonDigitsRE = RegExp(r'[-+]+');
final RegExp divElementRE = RegExp(r'<div[^>]*>([^<:]*):\s*(((?!</div>).)+)');
final RegExp mailTitleRE = RegExp(r'(mail|מייל)');
final RegExp phoneTitleRE = RegExp(r'^(טלפון|נייד|בית)$');
final RegExp mobilePhoneTitleRE = RegExp(r'<a href="tel:05[^>]*>([^<]+)</a>');
final RegExp suffixStar = RegExp(r'(\d*)\*');

String phoneNumberUrl(String phoneNumber) =>
    'tel:' +
    phoneNumber
        .replaceAll(phoneNumberNonDigitsRE, '')
        .replaceFirstMapped(suffixStar, (Match match) => '*' + match.group(1));

String phoneNumberMatcher(Match match) =>
    '<a href="${phoneNumberUrl(match.group(1))}">${match.group(1)}</a>${match.group(2)}';

class PageHTMLProcessor {
  PageHTMLProcessor(this.page)
      : html = page.dummyPage == true
            ? page.html
            : page.html
                .replaceFirst(
                    '<table', '<table width="100%" style="font-size: 1.2em;"')
                .replaceAll('font-size:10pt', '')
                .replaceAll('background-color:transparent', '')
                .replaceAll(" href='/", " href='$siteUrl/")
                .replaceAll(' href="/', ' href="$siteUrl/')
                .replaceAll(RegExp(r'\s*</a>'), '</a>')
                .replaceAll(styleURLRE, '')
                .replaceAll(specialCharsRE, '')
                .replaceAllMapped(
                    spanElementRE, (Match match) => match.group(1))
                .replaceAll(twitterImgRE, twitterDataImg)
                .replaceAll(facebookImgRE, facebookDataImg)
                .replaceAll(instagramImgRE, instagramDataImg)
                .replaceAll(facebookAltRE, '')
                .replaceAllMapped(phoneNumberRE, phoneNumberMatcher)
                .replaceAllMapped(prefixStarPhoneNumberRE, phoneNumberMatcher)
                .replaceAllMapped(suffixStarPhoneNumberRE, phoneNumberMatcher) {
    final String htmlForDataValue = html
        .replaceAll('<br/>', '</div><div>')
        .replaceAll(RegExp(r'<p(\s+[^>]+)*>'), '<div>')
        .replaceAll('</p>', '</div>');
    dataValues = divElementRE
        .allMatches(htmlForDataValue)
        .map((RegExpMatch match) => PageDataValue(match))
        .toList(growable: false);

    phoneValues = dataValues
        .where((PageDataValue v) => v.isPhoneValue())
        .toList(growable: false);
    mailValues = dataValues
        .where((PageDataValue v) => v.label.contains(mailTitleRE))
        .toList(growable: false);

    final PageDataValue homeValue =
        getValueForLabel('טלפון', mustBePhone: true);
    for (PageDataValue v in phoneValues) {
      if (!inContact(v.phoneValue())) {
        appendAddContactLink(v,
            givenName: v.label.contains(phoneTitleRE) ? null : v.label,
            homePhone: homeValue);
      }
    }

    html = html.replaceAllMapped(
        mobilePhoneTitleRE,
        (Match match) =>
            '${match.group(0)}&nbsp;${whatsAppLink(match.group(1))}');

    html = replaceEmail(html);
    html = replacePToDiv(html);

    final String viewSize = html.contains('style="font-size') ? '1.2em' : '1.6em';
    html = '<div style="font-size: $viewSize;" dir="rtl">$html</div>';
  }

  Page page;
  String html;
  List<PageDataValue> dataValues;
  List<PageDataValue> phoneValues;
  List<PageDataValue> mailValues;

  bool hasLabel(String label) =>
      dataValues.any((PageDataValue v) => v.label == label);

  PageDataValue getValueForLabel(String label, {bool mustBePhone = false}) {
    final PageDataValue dataValue = dataValues
        .firstWhere((PageDataValue v) => v.label == label, orElse: () => null);
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
    if (homePhone != null &&
        homePhone != dataValue &&
        !inContact(homePhone.phoneValue())) {
      phones += ',' + homePhone.toUrlPart();
    }

    String url =
        'action:addUser?givenName=$givenName&familyName=$familyName&phones=$phones';
    final List<PageDataValue> addressValues = dataValues
        .where((PageDataValue v) => v.label == 'כתובת')
        .toList(growable: false);
    if (addressValues.isNotEmpty) {
      if (addressValues.length > 1) {
        throw 'More than one address in ${page.title}';
      }

      url += '&address=${addressValues[0].htmlValue}';
    }

    if (mailValues.isNotEmpty) {
      String emails;
      if (mailValues.length == 1 ||
          phoneValues.length == 1 ||
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

    final String htmlValue =
        dataValue.htmlValue.replaceFirst(RegExp(r'<div>\s*$'), '');

    html = html.replaceFirst(
        htmlValue,
        htmlValue +
            '''
                <a href="$url" style="position: relative; top: 9px; right: 7px; text-decoration: none; color: purple;">
                  <svg width="32px" height="32px" viewBox="0 0 24 24" version="1.1" xmlns="http://www.w3.org/2000/svg">
                    <g stroke="none" stroke-width="1" fill="purple">
                      <path d="M17,17 L17,20 L16,20 L16,17 L13,17 L13,16 L16,16 L16,13 L17,13 L17,16 L20,16 L20,17 L17,17 Z M12,20 L7,20 C6.44771525,20 6,19.5522847 6,19 L6,17 C6,14.4353804 7.60905341,12.2465753 9.87270435,11.3880407 C8.74765126,10.68015 8,9.42738667 8,8 C8,5.790861 9.790861,4 12,4 C14.209139,4 16,5.790861 16,8 C16,9.42738667 15.2523487,10.68015 14.1272957,11.3880407 C13.8392195,11.573004 13.4634542,11.7769904 13,12 L13,10.829 C14.165,10.417 15,9.307 15,8 C15,6.343 13.657,5 12,5 C10.343,5 9,6.343 9,8 C9,9.307 9.835,10.417 11,10.829 L11,12.1 C8.718,12.564 7,14.581 7,17 L7,19 L12,19 L12,20 Z"></path>
                    </g>'
                  </svg>
                </a>
                ''');
  }

  String getPageFamilyName() => page.title.split(RegExp(r'\s')).last;

  String getPageGivenName() => page.title
      .substring(0, page.title.length - getPageFamilyName().length)
      .trim();
}

class PageView extends StatefulWidget {
  const PageView(this.page, this.phoneNumber) : super();

  final Page page;
  final String phoneNumber;

  @override
  PageViewState createState() => PageViewState(page, phoneNumber);
}

class PageViewState extends State<PageView> {
  PageViewState(this.page, this.phoneNumber)
      : html = PageHTMLProcessor(page).html {
    openPageViews.add(this);
  }

  @override
  void dispose() {
    super.dispose();
    openPageViews.remove(this);
  }

  final Page page;
  final String phoneNumber;
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
        openUrl('${page.url}#auth:$phoneNumber');
        return;
    }
  }

  String getDataUrlForHtml() => Uri.dataFromString(html,
          mimeType: 'text/html', encoding: Encoding.getByName('UTF-8'))
      .toString();

  void onWebViewCreated(WebViewController controller) =>
      webViewController = controller;

  Future<void> onPageFinished(String url) =>
      webViewController.evaluateJavascript(
          'document.body.scrollLeft = document.body.scrollWidth');

  NavigationDecision onWebViewNavigation(
      NavigationRequest navigation, BuildContext context) {
    final String pageUrlBase =
        RegExp(r'https:\/\/[^\/]+\/').firstMatch(page.url ?? '')?.group(0);
    if (pageUrlBase != null && navigation.url.startsWith(pageUrlBase)) {
      openUrlOrPage(navigation.url, phoneNumber, context);
    } else if (navigation.url.startsWith('action:addUser?')) {
      addContact(navigation.url);
    } else {
      openUrl(navigation.url);
    }

    return NavigationDecision.prevent;
  }

  void addContact(String url) {
    final String queryString = Uri.decodeQueryComponent(url.split('?')[1]);
    final Contact contact = Contact();
    for (List<String> keyValue
        in queryString.split('&').map((String v) => v.split('='))) {
      final String value = keyValue[1];
      switch (keyValue[0]) {
        case 'givenName':
          contact.givenName = value;
          break;

        case 'familyName':
          contact.familyName = value;
          break;

        case 'address':
          contact.postalAddresses = <PostalAddress>[
            PostalAddress(label: 'בית', street: value)
          ];
          break;

        case 'phones':
          contact.phones = value.split(',').map((String v) =>
              Item(label: v.startsWith('05') ? 'mobile' : 'home', value: v));
          break;

        case 'emails':
          contact.emails =
              value.split(',').map((String v) => Item(label: 'home', value: v));
          break;
      }
    }

    NativeContactDialog.addContact(contact);
  }

  FloatingActionButton getShareButton() {
    return FloatingActionButton.extended(
      onPressed: () => Share.share(
          '${page.title}\n${getPageInnerText(page, leaveAnchors: false)}',
          subject: page.title),
      label: const Text('שתף'),
      icon: const Icon(Icons.share),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(page.title),
          actions: page.url == null
              ? null
              : <Widget>[
                  PopupMenuButton<String>(
                      onSelected: onMenuSelected,
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuItem<String>>[
                            const PopupMenuItem<String>(
                              value: 'copyPageUrl',
                              child: Text('העתק את כתובת הדף'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'openPageInBrowser',
                              child: Text('פתח דף בדפדפן'),
                            ),
                          ]),
                ],
        ),
        body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: tagsList(page.tags,
                    filled: false, openTag: openTag, context: context),
              ),
              Expanded(
                  child: WebView(
                javascriptMode: JavascriptMode.unrestricted,
                initialUrl: getDataUrlForHtml(),
                onWebViewCreated: onWebViewCreated,
                onPageFinished: onPageFinished,
                navigationDelegate: (NavigationRequest navigation) =>
                    onWebViewNavigation(navigation, context),
              ))
            ]),
        floatingActionButton: getShareButton(),
      );
}

class _MainState extends State<Main> {
  _MainState(this._openedTag) {
    if (_openedTag != null) {
      _searchResults = pages
          .where((Page page) =>
              isPageSearchable(page) &&
              page.tags != null &&
              page.tags.contains(_openedTag))
          .toList(growable: false);
      _searchResults.sort((Page a, Page b) => a.title.compareTo(b.title));
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SharedPreferences _prefs;
  List<Page> _searchResults;
  List<String> _tagsSearchResults;
  List<Page> _updatedPages;
  Timer _searchOverflowTimer;
  bool _isUserVerified = false;
  final TextEditingController _phoneNumberController = TextEditingController();
  String _phoneNumber = '';
  Exception _fetchError;
  String _responseError;
  bool _reloadingData = false;
  bool _parsingPages = false;
  final TextEditingController _searchTextController = TextEditingController();
  String _searchString = '';
  String _openedTag;

  Future<void> fetchData() async {
    try {
      _fetchError = null;
      _reloadingData = true;
      _prefs.remove('data');

      final http.Response response = await getData();
      _parsingPages = true;

      if (response.statusCode == 200) {
        _prefs.setString('data', response.body);
        final dynamic jsonData = json.decode(response.body);
        setState(() {
          pages = parseData(jsonData, growable: false);
          getTagsFromPages();
          setLastUpdateDate(jsonData);
        });
      } else {
        _responseError = 'Server returned an error: ${response.statusCode} ${response.body}';
        showError('הורדת הנתונים נכשלה.', _responseError);
      }
    } catch (e) {
      _fetchError = e;
      showError('טעינת הנתונים נכשלה.', e);
    }

    _reloadingData = false;
    _parsingPages = false;
  }

  List<Page> parseData(dynamic jsonData, {@required bool growable}) {
    final List<Map<String, dynamic>> dynamicPages =
        jsonData['pages'].cast<Map<String, dynamic>>();
    return dynamicPages
        .map((Map<String, dynamic> page) => Page.fromMap(page))
        .toList(growable: growable);
  }

  void getTagsFromPages() {
    final Set<String> tagsSet = <String>{};
    for (Page p in pages) {
      if (p.tags != null) {
        tagsSet.addAll(p.tags);
      }
    }
    tags = tagsSet.toList();
  }

  String normalizedNumber(String number) {
    return number.replaceAll(RegExp(r'\D'), '');
  }

  Page getNumberPage(String number) {
    if (number?.isEmpty ?? true) {
      return null;
    }

    if (pages == null) {
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

    return pages.firstWhere(
        (Page page) =>
            page.isDeleted != true &&
            page.text.replaceAll(RegExp(r'[-\.]'), '').contains(number),
        orElse: () => null);
  }

  @override
  void initState() {
    super.initState();
    if (_openedTag != null) {
      SharedPreferences.getInstance().then((SharedPreferences prefs) {
        setState(() {
          _prefs = prefs;
          _phoneNumber = _prefs.getString('validationNumber');
          _isUserVerified = _phoneNumber?.isNotEmpty;
        });
      });

      return;
    }

    _phoneNumberController.addListener(
        () => setState(() => _phoneNumber = _phoneNumberController.text));

    _searchTextController.addListener(handleSearchChanged);

    loadContacts();

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        _prefs = prefs;
        _phoneNumber = _prefs.getString('validationNumber') ?? '';
        if (_phoneNumber?.isEmpty ?? true) {
          fetchData();
        } else {
          try {
            final String dataString = _prefs.getString('data');
            pages = parseData(json.decode(dataString), growable: true);
            getTagsFromPages();
            _isUserVerified = true;
            checkForUpdates(forceUpdate: false);
          } catch(_) {
            fetchData().then((_) => checkPhoneNumber());
          }
        }
        _prefs.setInt('patchLevel', patchLevel);
      });
    });

    WidgetsBinding.instance
        .addObserver(LifecycleEventHandler(() => loadPhoneContacts()));
  }

  Future<void> loadContacts() async {
    if (await Permission.contacts.request().isGranted) {
      contactPermissionWasGranted = true;
      loadPhoneContacts();
    }
  }

  Future<void> loadPhoneContacts() async {
    if (!contactPermissionWasGranted) {
      return;
    }

    final Iterable<contacts_plugin.Contact> contacts =
        await contacts_plugin.ContactsService.getContacts(
            withThumbnails: false);

    contactPhones = Set<String>.from(contacts.expand<String>(
        (contacts_plugin.Contact contact) => contact.phones.map(
            (contacts_plugin.Item item) => item.value
                .replaceAll(RegExp(r'[- ()]'), '')
                .replaceAll('+972', '0'))));

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
      _prefs.setString('validationName', page.title);

      setState(() {
        _isUserVerified = true;
      });
    }
  }

  List<String> parseToWords(String s) {
    final int pos = s.indexOf('"');
    if (pos == -1 || (pos > 0 && s[pos - 1] != ' ')) {
      return s.split(' ');
    }

    int nextPos = s.indexOf('"', pos + 1);
    if (nextPos == -1) {
      s = s + '"';
      nextPos = s.indexOf('"', pos + 1);
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
      return page.title.contains(re) ||
          page.text.contains(re) ||
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

  void handleSearchChanged() {
    final String searchString = _searchTextController.text.trim();
    if (searchString == _searchString && _openedTag != null) {
      return;
    }

    setState(() {
      _searchString = searchString;
      _openedTag = null;
    });
    if (_searchString == '___resetValidationNumber') {
      _prefs.remove('validationNumber');
      _prefs.remove('validationName');
      setState(() {
        _searchTextController.clear();
        _isUserVerified = false;
      });
    }

    if (searchString.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }

    if (searchString == newPagesKeyword) {
      setState(() => _searchResults = _updatedPages ?? <Page>[]);
      return;
    }

    final List<String> searchWords = parseToWords(_searchString.toLowerCase())
        .map((String s) => s.trim())
        .where((String w) => w.isNotEmpty)
        .toList(growable: false);
    final List<Page> result = pages
        .where((Page page) =>
            isPageSearchable(page) &&
            searchWords.every((String word) => isPageMatchWord(page, word)))
        .toList(growable: false);
    final List<String> tagsResult = tags
        .where((String tag) => searchWords
            .every((String word) => tag.toLowerCase().contains(word)))
        .toList(growable: false);

    result.sort((Page a, Page b) {
      final int titleCompare = compareSearchIndexes(a.title, b.title);
      if (titleCompare != 0) {
        return titleCompare;
      }

      final int textCompare = compareSearchIndexes(a.html, b.html);
      if (textCompare != 0) {
        return textCompare;
      }

      return a.title.compareTo(b.title);
    });

    if (result.length > searchResultsLimit) {
      if (_searchOverflowTimer != null ||
          _searchResults == null ||
          _searchResults.length <= searchResultsLimit) {
        setState(() {
          if (_searchOverflowTimer != null) {
            _searchOverflowTimer.cancel();
          }

          _searchOverflowTimer = Timer(
            searchOverflowDuration,
            () => setState(() => _searchOverflowTimer = null),
          );
        });
      }
    }

    setState(() {
      _searchResults = result;
      _tagsSearchResults = tagsResult;
    });
  }

  FloatingActionButton getFeedbackButton() {
    return _searchString.isEmpty || _searchResults == null
        ? FloatingActionButton.extended(
            onPressed: () async {
              const String url =
                  'mailto:splintor@gmail.com?subject=ספר הטלפונים של ירוחם';
              await openUrl(url);
            },
            label: const Text('משוב'),
            icon: const Icon(Icons.send),
          )
        : null;
  }

  int getLastUpdateDate() {
    try {
      return _prefs.getInt('lastUpdateDate');
    } catch (e) {
      return 0;
    }
  }

  Future<http.Response> getData({int lastUpdateDate = 0}) {
    const Map<String, String> headers = <String, String>{
      'cookie': DataAuthCookie,
    };

    final Uri url = Uri.https(siteDomain, '/api/allPages', <String, String>{
      'UpdatedAfter':
          DateTime.fromMillisecondsSinceEpoch(lastUpdateDate, isUtc: true)
              .toIso8601String(),
      'RequestedBy': _phoneNumber
    });

    return http.get(url, headers: headers);
  }

  void setLastUpdateDate(dynamic jsonData) =>
      _prefs.setInt('lastUpdateDate', jsonData['maxDate']);

  String getUpdateStatus(int updatedPagesCount) {
    switch (updatedPagesCount) {
      case 0:
        return 'לא נמצאו עדכונים.';
      case 1:
        return 'דף אחד עודכן.';
      default:
        return '$updatedPagesCount דפים עודכנו.';
    }
  }

  Future<void> checkForUpdates({bool forceUpdate}) async {
    if (forceUpdate) {
      showInSnackBar('בודק אם יש עדכונים...');
    }
    try {
      final int currentPatchLevel = _prefs.getInt('patchLevel') ?? 0;
      final int lastUpdateDate =
          currentPatchLevel < 1 ? startOfTime : getLastUpdateDate();
      final http.Response response =
          await getData(lastUpdateDate: lastUpdateDate);

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
          getTagsFromPages();
          setLastUpdateDate(jsonData);
          if (forceUpdate || updatedPages.isNotEmpty) {
            showInSnackBar(getUpdateStatus(updatedPages.length),
                actionLabel: updatedPages.isEmpty ? null : 'הצג',
                actionHandler: updatedPages.isEmpty
                    ? null
                    : () => setState(() {
                          _searchTextController.text = newPagesKeyword;
                          _searchResults = _updatedPages = updatedPages;
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
        showError(
            'הורדת העדכון נכשלה.', 'Status Code is ${response.statusCode}');
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
            borderSide: const BorderSide(width: 1),
            borderRadius: BorderRadius.circular(32.0)),
      ),
    );
  }

  Row buildTagTitle() {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          tagsList(<String>[_openedTag], filled: true, context: context),
          Text(' (${_searchResults.length} דפים בקטגוריה)',
              style: const TextStyle(fontSize: 18)),
        ]);
  }

  Future<void> openAboutPage() async =>
      openPage(await getAboutPage(), _phoneNumber, context);

  Widget buildSearchContent() {
    if ((_searchString.isEmpty && _openedTag == null) ||
        _searchResults == null) {
      return GestureDetector(
        onTap: openAboutPage,
        child: Image.asset('./assets/round_irus.png'),
      );
    } else if (_searchResults.length > searchResultsLimit &&
        _searchString != newPagesKeyword &&
        _openedTag == null) {
      if (_searchOverflowTimer == null) {
        return Align(
          alignment: Alignment.topRight,
          child: Text.rich(
              TextSpan(style: emptyListMessageStyle, children: <TextSpan>[
            const TextSpan(text: 'נמצאו '),
            TextSpan(
              text: _searchResults.length.toString(),
              style: const TextStyle(color: Colors.blueAccent),
            ),
            const TextSpan(
                text:
                    ' תוצאות מתאימות. יש לצמצם את התוצאות ע"י הוספת עוד מילות חיפוש.'),
          ])),
        );
      } else {
        return null;
      }
    } else if (_searchResults.isEmpty && _tagsSearchResults.isEmpty) {
      return Align(
        alignment: Alignment.topRight,
        child: Text.rich(
            TextSpan(style: emptyListMessageStyle, children: <TextSpan>[
          const TextSpan(text: 'לא נמצאו תוצאות מתאימות לחיפוש '),
          TextSpan(
            text: _searchString,
            style: const TextStyle(color: Colors.blueAccent),
          ),
        ])),
      );
    } else {
      return ListView(
        children: <Widget>[
          tagsList(_tagsSearchResults,
              filled: true, openTag: openTag, context: context),
          ..._searchResults
              .map<PageItem>((Page page) =>
                  PageItem(page: page, phoneNumber: _phoneNumber))
              .toList(growable: false)
        ],
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                _openedTag != null
                                    ? buildTagTitle()
                                    : buildSearchField(),
                                const Padding(
                                    padding: EdgeInsets.only(bottom: 10.0)),
                                Expanded(
                                    child: Container(
                                        height: 20.0,
                                        child: buildSearchContent()))
                              ],
                            ))))));
  }

  Widget buildValidationView() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
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
            child: ElevatedButton(
              onPressed: getNumberPage(_phoneNumber) == null
                  ? null
                  : () => checkPhoneNumber(),
              child: const Text('כניסה', style: TextStyle(fontSize: 24.0)),
              style: ElevatedButton.styleFrom(
                  primary: Colors.deepPurpleAccent,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30.0))),
                  padding: const EdgeInsets.all(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
          ),
        ]);
  }

  String getMainWidgetText() {
    if (_fetchError != null) {
      return 'אויש, הטעינה נכשלה. :(';
    }

    if (_responseError != null) {
      return 'אויש, ההורדה נכשלה! ' + _responseError;
    }

    if (_prefs == null) {
      return 'טוען את ספר הטלפונים...';
    }

    if (pages == null) {

      if (_reloadingData) {
        return 'טוען דפים מחדש...';
      }

      if (_parsingPages) {
        return 'מכין דפים...';
      }

      return 'טוען דפים...';
    }

    return null;
  }

  Widget buildMainWidget() {
    final String mainWidgetText = getMainWidgetText();
    return mainWidgetText != null ? Center(child: Text(mainWidgetText)) : _isUserVerified ? buildSearchView() : buildValidationView();
  }

  Future<void> onMenuSelected(String itemValue) async {
    switch (itemValue) {
      case 'about':
        openAboutPage();
        return;

      case 'openInBrowser':
        final String suffix = '#auth:$_phoneNumber';
        if (_openedTag != null) {
          openUrl('$siteUrl/tag/$_openedTag$suffix');
        } else if (_searchString.isNotEmpty) {
          openUrl('$siteUrl/search/$_searchString$suffix');
        } else {
          openUrl('$siteUrl$suffix');
        }
        return;

      case 'checkForUpdates':
        checkForUpdates(forceUpdate: true);
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
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                    const PopupMenuItem<String>(
                      value: 'about',
                      child: Text('אודות'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'openInBrowser',
                      child: Text('פתח בדפדפן'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'checkForUpdates',
                      child: Text('בדוק אם יש עדכונים'),
                    ),
                  ]),
        ],
      ),
      body: buildMainWidget(),
      floatingActionButton: getFeedbackButton(),
    );
  }

  void showError(String title, Object error) {
    showInSnackBar(title,
        isWarning: true,
        actionLabel: 'פרטים',
        actionHandler: () =>
            openPage(getErrorPage(title, error), _phoneNumber, context));
  }

  void showInSnackBar(String value,
      {bool isWarning = false, String actionLabel, Function actionHandler}) {
    final SnackBarAction action = actionLabel == null
        ? null
        : SnackBarAction(label: actionLabel, onPressed: actionHandler, textColor: Colors.blue);
    final Text content =
        Text(value, style: TextStyle(color: isWarning ? Colors.red : null));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(action: action, content: content));
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
