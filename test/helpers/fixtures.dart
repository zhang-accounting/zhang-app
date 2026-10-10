import 'dart:convert';
import 'dart:io';

/// Decoded JSON of `test/fixtures/<name>` (full response incl. envelope).
Object? fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

/// The `data` member of a fixture's envelope.
Object? fixtureData(String name) => (fixture(name) as Map)['data'];

/// Raw text of a fixture.
String fixtureText(String name) => File('test/fixtures/$name').readAsStringSync();
