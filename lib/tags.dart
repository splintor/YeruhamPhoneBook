import 'package:flutter/material.dart';

Widget tagsList(List<String> tags,
    {@required bool filled,
    void Function(String tag, BuildContext context) openTag,
    @required BuildContext context}) {
  return Wrap(
    children: (tags ?? <String>[])
        .map((String tag) =>
            tagChip(tag, filled: filled, onTap: openTag == null ? null : () => openTag(tag, context)))
        .toList(),
  );
}

Widget tagChip(
  String text, {
  GestureTapCallback onTap,
  bool filled,
}) {
  final bool isPublic = text == 'ציבורי';
  final Color tagColor = isPublic ? Colors.green : const Color(0xFF5F1B68);
  final Color fillColor = filled ? tagColor : Colors.white;
  final Color textColor = filled ? Colors.white : tagColor;
  return InkWell(
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 5.0,
              horizontal: 5.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(100.0),
                  border: Border.all(color: textColor)),
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.0,
                ),
              ),
            ),
          ),
        ],
      ));
}
