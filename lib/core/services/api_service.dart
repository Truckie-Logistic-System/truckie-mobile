import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/exceptions.dart';

class ApiService {
  final String baseUrl;
  final http.Client client;

  ApiService({required this.baseUrl, required this.client});

  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      return _processResponse(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> post(String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final response = await client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> put(String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final response = await client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      return _processResponse(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw UnauthorizedException();
    } else {
      throw ServerException(
        message: response.body,
        statusCode: response.statusCode,
      );
    }
  }
}
