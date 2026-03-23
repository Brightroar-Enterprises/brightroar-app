import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _baseUrl = 'http://10.13.108.6:8000/api/v1';
  static const String _tokenKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  static Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParams != null) uri = uri.replace(queryParameters: queryParams);

    final headers = await _headers(auth: auth);
    final encoded = body != null ? jsonEncode(body) : null;
    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          throw ApiException(
              statusCode: 0, message: 'Unsupported method: $method');
      }
    } on SocketException catch (e) {
      throw ApiException(statusCode: 0, message: 'No connection: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Connection failed: $e');
    }

    if (response.statusCode == 401) {
      // Try to refresh the token automatically
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry the original request once with the new token
        final newHeaders = await _headers(auth: auth);
        try {
          switch (method) {
            case 'GET':
              response = await http.get(uri, headers: newHeaders).timeout(const Duration(seconds: 15));
              break;
            case 'POST':
              response = await http.post(uri, headers: newHeaders, body: encoded).timeout(const Duration(seconds: 15));
              break;
            case 'PUT':
              response = await http.put(uri, headers: newHeaders, body: encoded).timeout(const Duration(seconds: 15));
              break;
            case 'DELETE':
              response = await http.delete(uri, headers: newHeaders).timeout(const Duration(seconds: 15));
              break;
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            if (response.body.isEmpty) return {};
            return jsonDecode(response.body);
          }
        } catch (_) {}
      }
      // Refresh failed or retry also failed — clear tokens and force re-login
      await clearTokens();
      throw ApiException(statusCode: 401, message: 'Session expired. Please login again.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    Map<String, dynamic> error = {};
    try {
      error = jsonDecode(response.body);
    } catch (_) {}
    throw ApiException(
        statusCode: response.statusCode,
        message: error['detail']?.toString() ??
            'Server error ${response.statusCode}');
  }

  // AUTH
  static Future<Map<String, dynamic>> register(
      {required String companyName,
      required String email,
      required String contactPerson,
      required String password}) async {
    return await request('POST', '/auth/register',
        body: {
          'company_name': companyName,
          'corporate_email': email,
          'contact_person': contactPerson,
          'password': password
        },
        auth: false);
  }

  static Future<void> login(
      {required String email, required String password}) async {
    final data = await request('POST', '/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    await saveTokens(data['access_token'], data['refresh_token']);
  }

  static Future<void> logout() async {
    try {
      await request('POST', '/auth/logout');
    } catch (_) {}
    await clearTokens();
  }

  static Future<Map<String, dynamic>> getMe() async =>
      await request('GET', '/auth/me');

  // WALLETS
  static Future<Map<String, dynamic>> getWallets() async =>
      await request('GET', '/wallets/');
  static Future<Map<String, dynamic>> createWallet(
      {required String name,
      required String walletType,
      String assetSymbol = 'USDT',
      String? address}) async {
    return await request('POST', '/wallets/', body: {
      'name': name,
      'wallet_type': walletType,
      'asset_symbol': assetSymbol,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  }

  static Future<Map<String, dynamic>> updateWallet(String walletId,
      {String? name, String? address}) async {
    return await request('PUT', '/wallets/$walletId', body: {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
    });
  }

  static Future<void> deleteWallet(String walletId) async {
    await request('DELETE', '/wallets/$walletId');
  }

  static Future<Map<String, dynamic>> syncWalletOnchain(String walletId) async =>
      await request('POST', '/wallets/$walletId/sync-onchain');

  // TRANSACTIONS
  static Future<Map<String, dynamic>> getTransactions(
      {String? txType, String? status, int page = 1, int pageSize = 20}) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString()
    };
    if (txType != null) params['tx_type'] = txType;
    if (status != null) params['status'] = status;
    return await request('GET', '/transactions/', queryParams: params);
  }

  static Future<Map<String, dynamic>> transfer(
      {required String fromWalletId,
      String? toWalletId,
      String? toExternalAddress,
      required String assetSymbol,
      required double amount,
      String? description}) async {
    return await request('POST', '/transactions/transfer', body: {
      'from_wallet_id': fromWalletId,
      if (toWalletId != null) 'to_wallet_id': toWalletId,
      if (toExternalAddress != null) 'to_external_address': toExternalAddress,
      'asset_symbol': assetSymbol,
      'amount': amount,
      if (description != null) 'description': description,
    });
  }

  // ANALYTICS
  static Future<Map<String, dynamic>> getPortfolioOverview() async =>
      await request('GET', '/analytics/portfolio');
  static Future<Map<String, dynamic>> getPerformance(
          {String period = 'ytd'}) async =>
      await request('GET', '/analytics/performance',
          queryParams: {'period': period});
  static Future<Map<String, dynamic>> getProfitHistory() async =>
      await request('GET', '/analytics/profit-history');

  // MARKET
  static Future<Map<String, dynamic>> getPrices(
          [String symbols = 'BTCUSDT,ETHUSDT,SOLUSDT,DOTUSDT']) async =>
      await request('GET', '/market/prices', queryParams: {'symbols': symbols});
  static Future<Map<String, dynamic>> getTicker(String symbol) async =>
      await request('GET', '/market/ticker/$symbol');
  static Future<List<dynamic>> getKlines(String symbol,
          {String interval = '1d', int limit = 30}) async =>
      await request('GET', '/market/klines/$symbol',
          queryParams: {'interval': interval, 'limit': limit.toString()});

  // BINANCE ACCOUNT
  static Future<Map<String, dynamic>> saveBinanceCredentials(
      {required String apiKey,
      required String apiSecret,
      String label = 'Main'}) async {
    return await request('POST', '/binance/credentials',
        body: {'api_key': apiKey, 'api_secret': apiSecret, 'label': label});
  }

  static Future<Map<String, dynamic>> getBinanceAccount() async =>
      await request('GET', '/binance/account');
  static Future<Map<String, dynamic>> getBinanceCredentials() async =>
      await request('GET', '/binance/credentials');
  static Future<void> deleteBinanceCredentials() async =>
      await request('DELETE', '/binance/credentials');
  static Future<Map<String, dynamic>> syncBinanceWallets() async =>
      await request('POST', '/binance/sync-wallets');
  static Future<Map<String, dynamic>> getBinancePnl(
          {String period = 'all'}) async =>
      await request('GET', '/binance/pnl', queryParams: {'period': period});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});
  @override
  String toString() => message;
}