import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

/// In-memory dio adapter: records requests and answers with [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? json, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody rawJsonResponse(String text, {int status = 200}) => ResponseBody.fromString(
  text,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody textResponse(String text, {int status = 200}) => ResponseBody.fromString(
  text,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
  },
);

ResponseBody emptyResponse(int status, {Map<String, List<String>> headers = const {}}) =>
    ResponseBody.fromString('', status, headers: headers);
