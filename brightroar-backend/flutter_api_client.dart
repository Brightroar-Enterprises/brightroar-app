// lib/services/api_client.dart
// Drop this file into your Brightroar Flutter project

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Change to your server IP / domain when deployed
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator
  // static const String baseUrl = 'https://api.yourdomain.com/api/v1'; // Production

  static const _storage = FlutterSecureStorage();

  // ── Token management ───────────────────────────────────────────────────────

  static Future<String?> _getAccessToken() =>
      _storage.read(key: 'access_token');

  static Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // ── Base request ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await _getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    final encoded = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }

    final error = jsonDecode(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      message: error['detail'] ?? 'Unknown error',
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String companyName,
    required String email,
    required String contactPerson,
    required String password,
  }) async {
    return _request('POST', '/auth/register', body: {
      'company_name': companyName,
      'corporate_email': email,
      'contact_person': contactPerson,
      'password': password,
    }, auth: false);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _request('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    }, auth: false);
    await _saveTokens(data['access_token'], data['refresh_token']);
  }

  static Future<void> logout() async {
    await _request('POST', '/auth/logout');
    await clearTokens();
  }

  static Future<Map<String, dynamic>> getMe() =>
      _request('GET', '/auth/me');

  // ── Wallets ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getWallets() =>
      _request('GET', '/wallets/');

  static Future<Map<String, dynamic>> createWallet({
    required String name,
    required String walletType,
    String assetSymbol = 'USDT',
  }) =>
      _request('POST', '/wallets/', body: {
        'name': name,
        'wallet_type': walletType,
        'asset_symbol': assetSymbol,
      });

  // ── Transactions ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTransactions({
    String? txType,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) {
    final params = StringBuffer('/transactions/?page=$page&page_size=$pageSize');
    if (txType != null) params.write('&tx_type=$txType');
    if (status != null) params.write('&status=$status');
    return _request('GET', params.toString());
  }

  static Future<Map<String, dynamic>> transfer({
    required String fromWalletId,
    String? toWalletId,
    String? toExternalAddress,
    required String assetSymbol,
    required double amount,
    String? description,
  }) =>
      _request('POST', '/transactions/transfer', body: {
        'from_wallet_id': fromWalletId,
        if (toWalletId != null) 'to_wallet_id': toWalletId,
        if (toExternalAddress != null) 'to_external_address': toExternalAddress,
        'asset_symbol': assetSymbol,
        'amount': amount,
        if (description != null) 'description': description,
      });

  // ── Analytics ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPortfolioOverview() =>
      _request('GET', '/analytics/portfolio');

  static Future<Map<String, dynamic>> getPerformance({String period = 'ytd'}) =>
      _request('GET', '/analytics/performance?period=$period');

  static Future<Map<String, dynamic>> getProfitHistory() =>
      _request('GET', '/analytics/profit-history');

  // ── Market (Binance) ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPrices([
    String symbols = 'BTCUSDT,ETHUSDT,SOLUSDT,DOTUSDT',
  ]) =>
      _request('GET', '/market/prices?symbols=$symbols');

  static Future<Map<String, dynamic>> getTicker(String symbol) =>
      _request('GET', '/market/ticker/$symbol');

  static Future<List<dynamic>> getKlines(
    String symbol, {
    String interval = '1d',
    int limit = 30,
  }) async {
    final data = await _request(
      'GET',
      '/market/klines/$symbol?interval=$interval&limit=$limit',
    );
    return data as List<dynamic>;
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
