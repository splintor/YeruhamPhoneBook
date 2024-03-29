import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeruhamphonebook/main.dart' as main;

Widget tagsList(
  List<String>? tags,
  main.Page? sourcePage,
  SharedPreferences prefs, {
  required bool filled,
  void Function(String tag, main.Page? sourcePage, SharedPreferences prefs,
          BuildContext context)?
      openTag,
  required BuildContext context,
}) {
  return Wrap(
    children: (tags ?? <String>[])
        .map((String tag) => tagChip(tag,
            filled: filled,
            onTap: openTag == null
                ? null
                : () => openTag(tag, sourcePage, prefs, context)))
        .toList(),
  );
}

Widget tagChip(
  String text, {
  GestureTapCallback? onTap,
  bool filled = false,
}) {
  final bool isPublic = text == 'ציבורי';
  final Color tagColor = isPublic ? Colors.green : const Color(0xFF5F1B68);
  final Color fillColor = filled ? tagColor : Colors.white;
  final Color textColor = filled ? Colors.white : tagColor;
  final double padding = filled ? 9 : 6;
  final double fontSize = filled ? 16 : 12;
  return InkWell(
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(6, 12, 0, 5),
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: textColor)),
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ],
      ));
}
