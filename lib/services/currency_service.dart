import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class CurrencyService {
  // Primary API: ExchangeRate-API (free, no key required)
  static const String _primaryUrl = 'https://open.er-api.com/v6/latest';
  // Fallback API: Frankfurter
  static const String _fallbackUrl = 'https://api.frankfurter.app/latest';
  
  // Cache exchange rates to avoid excessive API calls
  static final Map<String, _CachedRates> _ratesCache = {};
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Get exchange rates from a base currency to all supported currencies
  Future<Map<String, double>?> getExchangeRates(String baseCurrency) async {
    // Check cache first
    final cached = _ratesCache[baseCurrency];
    if (cached != null && !cached.isExpired) {
      debugPrint('CurrencyService: Using cached rates for $baseCurrency');
      return cached.rates;
    }

    // Try primary API first
    var rates = await _fetchFromPrimaryApi(baseCurrency);
    
    // If primary fails, try fallback
    if (rates == null) {
      debugPrint('CurrencyService: Primary API failed, trying fallback...');
      rates = await _fetchFromFallbackApi(baseCurrency);
    }
    
    if (rates != null) {
      // Cache the rates
      _ratesCache[baseCurrency] = _CachedRates(rates);
      debugPrint('CurrencyService: Fetched ${rates.length} rates for $baseCurrency');
    }
    
    return rates;
  }

  Future<Map<String, double>?> _fetchFromPrimaryApi(String baseCurrency) async {
    try {
      final response = await http.get(
        Uri.parse('$_primaryUrl/$baseCurrency'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rates = (data['rates'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, (value as num).toDouble()));
          debugPrint('CurrencyService: Primary API success');
          return rates;
        }
      }
      debugPrint('CurrencyService: Primary API error ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('CurrencyService: Primary API exception: $e');
      return null;
    }
  }

  Future<Map<String, double>?> _fetchFromFallbackApi(String baseCurrency) async {
    try {
      final response = await http.get(
        Uri.parse('$_fallbackUrl?from=$baseCurrency'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rates = (data['rates'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
        
        // Add the base currency with rate 1.0
        rates[baseCurrency] = 1.0;
        debugPrint('CurrencyService: Fallback API success');
        return rates;
      }
      debugPrint('CurrencyService: Fallback API error ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('CurrencyService: Fallback API exception: $e');
      return null;
    }
  }

  /// Convert an amount from one currency to another
  Future<double?> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    if (from == to) return amount;

    final rates = await getExchangeRates(from);
    if (rates == null || !rates.containsKey(to)) {
      return null;
    }

    return amount * rates[to]!;
  }

  /// Convert multiple amounts to a target currency
  /// Returns a map of original currency -> converted amount
  Future<Map<String, double>> convertMultiple({
    required Map<String, double> amounts,
    required String targetCurrency,
  }) async {
    final result = <String, double>{};
    
    for (final entry in amounts.entries) {
      if (entry.key == targetCurrency) {
        result[entry.key] = entry.value;
      } else {
        final converted = await convert(
          amount: entry.value,
          from: entry.key,
          to: targetCurrency,
        );
        if (converted != null) {
          result[entry.key] = converted;
        }
      }
    }
    
    return result;
  }

  /// Get the total of multiple currency amounts converted to a target currency
  Future<double?> getTotalInCurrency({
    required Map<String, double> currencyAmounts,
    required String targetCurrency,
  }) async {
    double total = 0;
    
    for (final entry in currencyAmounts.entries) {
      if (entry.key == targetCurrency) {
        total += entry.value;
      } else {
        final converted = await convert(
          amount: entry.value,
          from: entry.key,
          to: targetCurrency,
        );
        if (converted == null) {
          // If conversion fails for any currency, return null
          return null;
        }
        total += converted;
      }
    }
    
    return total;
  }

  /// Clear the rates cache
  void clearCache() {
    _ratesCache.clear();
  }
}

class _CachedRates {
  final Map<String, double> rates;
  final DateTime fetchedAt;

  _CachedRates(this.rates) : fetchedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > CurrencyService._cacheDuration;
}
