import 'package:flutter/widgets.dart';

/// One editable custom header (name + secret value) of a server profile.
class HeaderRow {
  HeaderRow([String name = '', String value = ''])
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }

  /// Non-empty rows as a header map (names trimmed, values verbatim).
  static Map<String, String> toMap(Iterable<HeaderRow> rows) => {
    for (final h in rows)
      if (h.name.text.trim().isNotEmpty) h.name.text.trim(): h.value.text,
  };
}
