import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_weather_app_v2/components/weather_icon.dart';
import 'package:flutter_weather_app_v2/constants.dart';
import 'package:flutter_weather_app_v2/ui/detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// ============================================================
// LOCATION ERRORS
// ============================================================

enum _LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class _LocationException implements Exception {
  final String message;
  final _LocationIssue issue;

  const _LocationException(this.message, {required this.issue});

  @override
  String toString() => message;
}

// ============================================================
// HOME PAGE STATE
// ============================================================

class _HomePageState extends State<HomePage> {
  // ----------------------------------------------------------
  // STORAGE KEYS
  // ----------------------------------------------------------

  static const String _savedLocationKey = 'weather_selected_location';

  static const String _weatherCacheKey = 'weather_cached_response_v1';

  static const String _weatherCacheQueryKey = 'weather_cached_query_v1';

  static const String _weatherCacheTimeKey = 'weather_cached_time_v1';

  // ----------------------------------------------------------
  // BUTTON COLORS
  // ----------------------------------------------------------

  static const Color _cyan = Color(0xFF50DFEF);
  static const Color _purple = Color(0xFF6258CD);
  static const Color _purpleBorder = Color(0xFFA89CFF);
  static const Color _warning = Color(0xFFFFD38A);

  // ----------------------------------------------------------
  // LOCATION SERVICE
  // ----------------------------------------------------------

  final Location _location = Location();

  // ----------------------------------------------------------
  // WEATHER STATE
  // ----------------------------------------------------------

  String _city = '';
  String _country = '';
  String _condition = '';
  String _iconFile = 'heavycloudy.png';
  String _localTime = '';

  String? _selectedQuery;
  String? _weatherError;
  String? _locationError;
  String? _offlineMessage;

  DateTime? _lastUpdated;

  double _temperature = 0;
  double _feelsLike = 0;
  double _wind = 0;

  int _humidity = 0;
  int _cloud = 0;
  int _uv = 0;

  bool _initializing = true;
  bool _loadingWeather = false;
  bool _locating = false;
  bool _showingCachedWeather = false;

  int _weatherVersion = 0;
  int _locationVersion = 0;
  int _selectionVersion = 0;

  List<dynamic> _hours = [];
  List<dynamic> _days = [];

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreWeatherAndLocation();
      }
    });
  }

  @override
  void dispose() {
    _weatherVersion++;
    _locationVersion++;
    _selectionVersion++;

    super.dispose();
  }

  // ==========================================================
  // RESTORE LOCATION AND CACHED WEATHER
  // ==========================================================

  Future<void> _restoreWeatherAndLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      final savedQuery = prefs.getString(_savedLocationKey);

      final cachedQuery = prefs.getString(_weatherCacheQueryKey);

      final cachedResponse = prefs.getString(_weatherCacheKey);

      final cachedTime = prefs.getString(_weatherCacheTimeKey);

      if (savedQuery != null && savedQuery.trim().isNotEmpty) {
        _selectedQuery = savedQuery;

        if (cachedResponse != null && cachedQuery == savedQuery) {
          try {
            final data = jsonDecode(cachedResponse) as Map<String, dynamic>;

            final updatedAt = cachedTime == null
                ? null
                : DateTime.tryParse(cachedTime);

            if (!mounted) return;

            setState(() {
              _applyWeatherData(
                data,
                savedQuery,
                fromCache: true,
                updatedAt: updatedAt,
              );

              _initializing = false;
            });
          } catch (error) {
            debugPrint('Cache restoration failed: $error');
          }
        }

        if (!mounted) return;

        setState(() {
          _initializing = false;
        });

        // Refresh saved location without requesting GPS.
        if (_selectedQuery == savedQuery) {
          _fetchWeather(savedQuery);
        }
      } else {
        setState(() {
          _initializing = false;
        });

        // GPS only runs automatically when there is no
        // previously saved location.
        await _useCurrentLocation();
      }
    } catch (error) {
      debugPrint('Startup error: $error');

      if (!mounted) return;

      setState(() {
        _initializing = false;
        _weatherError =
            'Could not restore saved weather. '
            'Search for a city or use GPS.';
      });
    }
  }

  // ==========================================================
  // APPLY WEATHER DATA
  // ==========================================================

  void _applyWeatherData(
    Map<String, dynamic> data,
    String query, {
    required bool fromCache,
    DateTime? updatedAt,
  }) {
    final location = data['location'] as Map<String, dynamic>;

    final current = data['current'] as Map<String, dynamic>;

    final forecast = data['forecast']['forecastday'] as List<dynamic>;

    _city = location['name'].toString();
    _country = location['country'].toString();
    _localTime = location['localtime'].toString();

    _condition = current['condition']['text'].toString();

    _iconFile = weatherIconFile(_condition);

    _temperature = (current['temp_c'] as num).toDouble();

    _feelsLike = (current['feelslike_c'] as num).toDouble();

    _wind = (current['wind_kph'] as num).toDouble();

    _humidity = (current['humidity'] as num).round();

    _cloud = (current['cloud'] as num).round();

    _uv = (current['uv'] as num).round();

    _days = forecast;

    _hours = forecast.isEmpty ? [] : forecast.first['hour'] as List<dynamic>;

    _selectedQuery = query;
    _showingCachedWeather = fromCache;
    _lastUpdated = updatedAt;
    _weatherError = null;
  }

  // ==========================================================
  // SAVE WEATHER CACHE
  // ==========================================================

  Future<void> _saveWeatherCache(
    Map<String, dynamic> data,
    String query,
    DateTime updatedAt,
    int version,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted || version != _weatherVersion) {
        return;
      }

      await prefs.setString(_weatherCacheKey, jsonEncode(data));

      await prefs.setString(_weatherCacheQueryKey, query);

      await prefs.setString(_weatherCacheTimeKey, updatedAt.toIso8601String());
    } catch (error) {
      debugPrint('Cache saving failed: $error');
    }
  }

  // ==========================================================
  // SAVE SELECTED LOCATION
  // ==========================================================

  Future<void> _saveLocation(String query, int selectionVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted || selectionVersion != _selectionVersion) {
        return;
      }

      await prefs.setString(_savedLocationKey, query);
    } catch (error) {
      debugPrint('Location saving failed: $error');
    }
  }

  // ==========================================================
  // GPS LOCATION
  // ==========================================================

  Future<void> _useCurrentLocation() async {
    if (_locating) return;

    final version = ++_locationVersion;

    setState(() {
      _locating = true;
      _locationError = null;
      _weatherError = null;
    });

    try {
      // Check device Location service.
      bool serviceEnabled = await _location.serviceEnabled();

      if (!mounted || version != _locationVersion) {
        return;
      }

      // Ask Android to enable Location using its
      // native system prompt when supported.
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();

        if (!mounted || version != _locationVersion) {
          return;
        }

        if (!serviceEnabled) {
          throw const _LocationException(
            'Device Location is turned off.',
            issue: _LocationIssue.serviceDisabled,
          );
        }
      }

      // Check app-level location permission.
      PermissionStatus permission = await _location.hasPermission();

      if (!mounted || version != _locationVersion) {
        return;
      }

      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }

      if (!mounted || version != _locationVersion) {
        return;
      }

      if (permission == PermissionStatus.deniedForever) {
        throw const _LocationException(
          'Location permission has been blocked. '
          'Open App Settings to allow location access.',
          issue: _LocationIssue.permissionPermanentlyDenied,
        );
      }

      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        throw const _LocationException(
          'Location permission was denied.',
          issue: _LocationIssue.permissionDenied,
        );
      }

      // Set appropriate accuracy for weather detection.
      await _location.changeSettings(accuracy: LocationAccuracy.balanced);

      // Get coordinates with a timeout.
      final position = await _location.getLocation().timeout(
        const Duration(seconds: 20),
      );

      if (!mounted || version != _locationVersion) {
        return;
      }

      final latitude = position.latitude;
      final longitude = position.longitude;

      // ignore: unnecessary_null_comparison
      if (latitude == null || longitude == null) {
        throw Exception('GPS coordinates are unavailable.');
      }

      final query = '$latitude,$longitude';

      setState(() {
        _locating = false;
      });

      await _fetchWeather(query, saveSelection: true);
    } on _LocationException catch (error) {
      if (!mounted || version != _locationVersion) {
        return;
      }

      setState(() {
        _locating = false;
        _locationError = error.message;
      });

      await _showLocationSettingsDialog(error);
    } on TimeoutException {
      if (!mounted || version != _locationVersion) {
        return;
      }

      setState(() {
        _locating = false;
        _locationError = 'GPS timed out. Try again or search for a city.';
      });
    } catch (error) {
      if (!mounted || version != _locationVersion) {
        return;
      }

      debugPrint('GPS error: $error');

      setState(() {
        _locating = false;
        _locationError = 'Could not detect your location. Try again.';
      });
    }
  }

  // ==========================================================
  // LOCATION SETTINGS DIALOG
  // ==========================================================

  Future<void> _showLocationSettingsDialog(_LocationException error) async {
    if (!mounted) return;

    final serviceDisabled = error.issue == _LocationIssue.serviceDisabled;

    final permanentlyDenied =
        error.issue == _LocationIssue.permissionPermanentlyDenied;

    final openSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: Constants.glassBlur,
                sigmaY: Constants.glassBlur,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Constants.searchBackground,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _purpleBorder, width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _cyan.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Icon(
                          serviceDisabled
                              ? Icons.location_off_rounded
                              : Icons.location_disabled_rounded,
                          color: _cyan,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        serviceDisabled
                            ? 'Turn On Device Location'
                            : 'Location Permission Required',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Constants.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        serviceDisabled
                            ? 'Device Location is turned off. '
                                  'Open Location Settings to enable it.'
                            : permanentlyDenied
                            ? 'Location permission has been blocked. '
                                  'Open App Settings to allow location access.'
                            : 'The Weather App needs location permission. '
                                  'You can retry GPS or search for a city.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Constants.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                          icon: Icon(
                            serviceDisabled || permanentlyDenied
                                ? Icons.settings_rounded
                                : Icons.refresh_rounded,
                          ),
                          label: Text(
                            serviceDisabled
                                ? 'Open Location Settings'
                                : permanentlyDenied
                                ? 'Open App Settings'
                                : 'Try Again',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: Constants.backgroundNavy,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(false);

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _openCitySearch();
                              }
                            });
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Search City'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _purple,
                            side: const BorderSide(color: _purpleBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: const Text(
                          'Not Now',
                          style: TextStyle(color: Constants.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (openSettings != true || !mounted) {
      return;
    }

    // ========================================================
    // ACTUAL ANDROID SETTINGS NAVIGATION
    // ========================================================

    if (!serviceDisabled && !permanentlyDenied) {
      await _useCurrentLocation();
      return;
    }

    try {
      if (serviceDisabled) {
        await AppSettings.openAppSettings(type: AppSettingsType.location);
      } else {
        // Opens Android's settings page for this app.
        await AppSettings.openAppSettings(type: AppSettingsType.settings);
      }
    } catch (error) {
      debugPrint('Unable to open Android Settings: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Settings. Please try again.'),
        ),
      );
    }
  }

  // ==========================================================
  // MANUAL CITY SELECTION
  // ==========================================================

  void _selectManualCity(String query) {
    _locationVersion++;

    setState(() {
      _locating = false;
      _locationError = null;
    });

    _fetchWeather(query, saveSelection: true);
  }

  // ==========================================================
  // WEATHER API
  // ==========================================================

  Future<void> _fetchWeather(String query, {bool saveSelection = false}) async {
    if (query.trim().isEmpty) return;

    final version = ++_weatherVersion;

    final selectionVersion = saveSelection
        ? ++_selectionVersion
        : _selectionVersion;

    final previousQuery = _selectedQuery;
    final sameLocation = previousQuery == query;

    setState(() {
      _loadingWeather = true;
      _weatherError = null;
      _offlineMessage = null;
    });

    try {
      final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
        'key': Constants.apiKey,
        'q': query.trim(),
        'days': '7',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        String message = 'Weather request failed.';

        try {
          final errorData = jsonDecode(response.body);

          message = errorData['error']['message']?.toString() ?? message;
        } catch (_) {}

        throw Exception(message);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted || version != _weatherVersion) {
        return;
      }

      final updatedAt = DateTime.now();

      setState(() {
        _applyWeatherData(data, query, fromCache: false, updatedAt: updatedAt);

        _loadingWeather = false;
        _offlineMessage = null;
        _locationError = null;
      });

      if (saveSelection) {
        await _saveLocation(query, selectionVersion);
      }

      if (!mounted || version != _weatherVersion) {
        return;
      }

      await _saveWeatherCache(data, query, updatedAt, version);
    } catch (error) {
      if (!mounted || version != _weatherVersion) {
        return;
      }

      final isNetworkFailure =
          error is TimeoutException ||
          error is SocketException ||
          error is http.ClientException;

      final hasWeather = _days.isNotEmpty;

      setState(() {
        _loadingWeather = false;

        if (hasWeather && sameLocation) {
          _showingCachedWeather = true;

          _offlineMessage = isNetworkFailure
              ? 'You appear to be offline. '
                    'Showing your last saved weather.'
              : 'Weather update failed: $error';

          _weatherError = null;
        } else if (hasWeather) {
          _offlineMessage =
              'Could not load the selected city. '
              'Showing weather for $_city.';

          _weatherError = null;
        } else {
          _weatherError = isNetworkFailure
              ? 'No internet connection. '
                    'Connect and try again.'
              : error.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  // ==========================================================
  // REFRESH WEATHER
  // ==========================================================

  Future<void> _refreshWeather() async {
    final query = _selectedQuery;

    if (query == null || query.isEmpty) {
      setState(() {
        _locationError = 'Search for a city or tap the GPS button.';
      });

      return;
    }

    await _fetchWeather(query);
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  void _openForecast() {
    if (_days.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(dailyForecastWeather: _days),
      ),
    );
  }

  void _openCitySearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _CitySearchSheet(
          onCitySelected: (query) {
            Navigator.of(sheetContext).pop();
            _selectManualCity(query);
          },
        );
      },
    );
  }

  // ==========================================================
  // DATE HELPERS
  // ==========================================================

  String get _formattedDate {
    try {
      return DateFormat(
        'EEEE, d MMMM',
      ).format(DateTime.parse(_localTime.replaceFirst(' ', 'T')));
    } catch (_) {
      return 'Current weather';
    }
  }

  int get _currentLocalHour {
    try {
      return DateTime.parse(_localTime.replaceFirst(' ', 'T')).hour;
    } catch (_) {
      return DateTime.now().hour;
    }
  }

  String get _lastUpdatedText {
    if (_lastUpdated == null) {
      return 'Update time unavailable';
    }

    return 'Updated ${DateFormat('d MMM, h:mm a').format(_lastUpdated!.toLocal())}';
  }

  // ==========================================================
  // PRIMARY ACTION BUTTON
  // ==========================================================

  Widget _primaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: _cyan,
        foregroundColor: Constants.backgroundNavy,
        disabledBackgroundColor: Constants.glassBackground,
        disabledForegroundColor: Constants.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // ==========================================================
  // SECONDARY ACTION BUTTON
  // ==========================================================

  Widget _secondaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: _purple,
        side: const BorderSide(color: _purpleBorder, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // ==========================================================
  // MAIN SCREEN - SAFE AREA
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final isTablet = screenWidth >= 700;

    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: Constants.backgroundNavy,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: Constants.backgroundGradient),
            ),
          ),

          Positioned(
            top: -110,
            right: -110,
            child: _BackgroundGlow(
              diameter: 330,
              color: Constants.accentBlue.withValues(alpha: .22),
            ),
          ),

          Positioned(
            top: 340,
            left: -130,
            child: _BackgroundGlow(
              diameter: 290,
              color: Constants.accentPurple.withValues(alpha: .14),
            ),
          ),

          // SafeArea keeps controls away from the
          // status bar, display cutout, and system
          // navigation area.
          SafeArea(
            top: true,
            bottom: true,
            left: true,
            right: true,
            child: RefreshIndicator(
              color: Constants.backgroundBlue,
              onRefresh: _refreshWeather,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  18,
                  horizontalPadding,
                  35,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),

                          const SizedBox(height: 22),

                          if (_offlineMessage != null) _buildOfflineBanner(),

                          if (_locationError != null) _buildLocationError(),

                          if (_weatherError != null) _buildWeatherError(),

                          if (_initializing)
                            _buildLoading('Loading saved weather...'),

                          if (_locating && _days.isEmpty)
                            _buildLoading('Detecting your location...'),

                          if (_loadingWeather && _days.isEmpty)
                            _buildLoading('Loading weather...'),

                          if (!_initializing &&
                              !_locating &&
                              !_loadingWeather &&
                              _days.isEmpty &&
                              _weatherError == null &&
                              _locationError == null)
                            _buildEmptyState(),

                          if (_days.isNotEmpty) ...[
                            if (_loadingWeather)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 15),
                                child: LinearProgressIndicator(
                                  color: Constants.accentCyan,
                                  backgroundColor: Constants.glassBackground,
                                ),
                              ),

                            _buildHero(isTablet),

                            const SizedBox(height: 25),

                            _buildSectionHeader(
                              'Hourly forecast',
                              'Next hours',
                            ),

                            const SizedBox(height: 13),

                            _buildHourly(),

                            const SizedBox(height: 27),

                            _buildSectionHeader(
                              'Weather details',
                              'Last available',
                            ),

                            const SizedBox(height: 13),

                            _buildDetails(isTablet),

                            const SizedBox(height: 27),

                            _buildForecastPreview(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _openCitySearch,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Constants.accentCyan,
                  size: 25,
                ),

                const SizedBox(width: 8),

                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _city.isEmpty ? 'Your location' : _city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Constants.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Text(
                        _locating
                            ? 'Locating...'
                            : _country.isEmpty
                            ? 'Choose a city'
                            : _country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Constants.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 9),

        // Bright GPS control.
        Container(
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cyan, width: 1.5),
          ),
          child: IconButton(
            tooltip: 'Use current GPS location',
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cyan,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, color: _cyan, size: 22),
          ),
        ),

        const SizedBox(width: 9),

        // Bright Search control.s
        Container(
          decoration: BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _purpleBorder, width: 1.5),
          ),
          child: IconButton(
            tooltip: 'Search city',
            onPressed: _openCitySearch,
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // OFFLINE BANNER
  // ==========================================================

  Widget _buildOfflineBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _GlassCard(
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: _warning),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Weather update unavailable',
                    style: TextStyle(
                      color: Constants.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              _offlineMessage!,
              style: const TextStyle(
                color: Constants.textSecondary,
                fontSize: 13,
              ),
            ),

            if (_days.isNotEmpty) ...[
              const SizedBox(height: 7),

              Text(
                _lastUpdatedText,
                style: const TextStyle(
                  color: Constants.textMuted,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 15),

            Align(
              alignment: Alignment.centerRight,
              child: _primaryActionButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _loadingWeather ? null : _refreshWeather,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // LOADING
  // ==========================================================

  Widget _buildLoading(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 65),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Constants.accentCyan),

          const SizedBox(height: 18),

          Text(message, style: const TextStyle(color: Constants.textSecondary)),
        ],
      ),
    );
  }

  // ==========================================================
  // LOCATION ERROR
  // ==========================================================

  Widget _buildLocationError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassCard(
        radius: 20,
        child: Column(
          children: [
            const Icon(Icons.location_off_rounded, color: _warning, size: 29),

            const SizedBox(height: 10),

            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Constants.textPrimary),
            ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _primaryActionButton(
                  label: 'Retry GPS',
                  icon: Icons.my_location_rounded,
                  onPressed: _locating ? null : _useCurrentLocation,
                ),

                _secondaryActionButton(
                  label: 'Search City',
                  icon: Icons.search_rounded,
                  onPressed: _openCitySearch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // WEATHER ERROR
  // ==========================================================

  Widget _buildWeatherError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassCard(
        radius: 20,
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _warning, size: 29),

            const SizedBox(height: 10),

            Text(
              _weatherError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Constants.textPrimary),
            ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _primaryActionButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadingWeather ? null : _refreshWeather,
                ),

                _secondaryActionButton(
                  label: 'Search City',
                  icon: Icons.search_rounded,
                  onPressed: _openCitySearch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _buildEmptyState() {
    return _GlassCard(
      radius: 25,
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Constants.accentCyan,
            size: 45,
          ),

          const SizedBox(height: 15),

          const Text(
            'Weather unavailable',
            style: TextStyle(
              color: Constants.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Search for a city or enable GPS '
            'to load weather information.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Constants.textSecondary),
          ),

          const SizedBox(height: 18),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _primaryActionButton(
                label: 'Use GPS',
                icon: Icons.my_location_rounded,
                onPressed: _locating ? null : _useCurrentLocation,
              ),

              _secondaryActionButton(
                label: 'Search City',
                icon: Icons.search_rounded,
                onPressed: _openCitySearch,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CURRENT WEATHER HERO
  // ==========================================================

  Widget _buildHero(bool isTablet) {
    return _GlassCard(
      radius: Constants.heroRadius,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 35 : 18,
        vertical: 28,
      ),
      child: Column(
        children: [
          Text(
            _formattedDate,
            style: const TextStyle(
              color: Constants.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: isTablet ? 180 : 155,
            child: WeatherIcon(file: _iconFile, width: isTablet ? 180 : 155),
          ),

          const SizedBox(height: 7),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_temperature.round()}°',
              style: TextStyle(
                fontSize: isTablet ? 100 : 88,
                height: 1,
                fontWeight: FontWeight.w300,
                letterSpacing: -5,
                color: Constants.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _condition,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Constants.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            _showingCachedWeather
                ? 'Last recorded feels like '
                      '${_feelsLike.round()}°'
                : 'Feels like ${_feelsLike.round()}°',
            style: const TextStyle(
              color: Constants.textSecondary,
              fontSize: 14,
            ),
          ),

          if (_showingCachedWeather) ...[
            const SizedBox(height: 8),

            Text(
              _lastUpdatedText,
              style: const TextStyle(color: Constants.accentCyan, fontSize: 12),
            ),
          ],

          const SizedBox(height: 23),

          Container(height: 1, color: Constants.glassDivider),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _heroMetric(Icons.air_rounded, '${_wind.round()} km/h', 'Wind'),

              _heroMetric(Icons.water_drop_outlined, '$_humidity%', 'Humidity'),

              _heroMetric(Icons.cloud_outlined, '$_cloud%', 'Clouds'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HERO METRIC
  // ==========================================================

  Widget _heroMetric(IconData icon, String value, String label) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: Constants.accentCyan, size: 23),

          const SizedBox(height: 7),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Constants.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: const TextStyle(color: Constants.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION HEADER
  // ==========================================================

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Constants.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        Text(
          subtitle,
          style: const TextStyle(color: Constants.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  // ==========================================================
  // HOURLY FORECAST
  // ==========================================================

  Widget _buildHourly() {
    final start = _currentLocalHour.clamp(0, 23);

    final remaining = _hours.skip(start).toList();

    return SizedBox(
      height: 142,
      child: ListView.separated(
        key: ValueKey('hourly_${_selectedQuery}_$_localTime'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: remaining.length,
        separatorBuilder: (_, _) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final hour = remaining[index] as Map<String, dynamic>;

          final condition = hour['condition']['text'].toString();

          final temperature = (hour['temp_c'] as num).round();

          final time = hour['time'].toString().split(' ').last;

          return _GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: SizedBox(
              width: 61,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    index == 0 && !_showingCachedWeather ? 'Now' : time,
                    style: const TextStyle(
                      color: Constants.textSecondary,
                      fontSize: 12,
                    ),
                  ),

                  SizedBox(
                    height: 47,
                    child: WeatherIcon(
                      file: weatherIconFile(condition),
                      width: 46,
                    ),
                  ),

                  Text(
                    '$temperature°',
                    style: const TextStyle(
                      color: Constants.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // WEATHER DETAILS
  // ==========================================================

  Widget _buildDetails(bool isTablet) {
    final items = [
      _DetailData(
        Icons.thermostat_rounded,
        'Feels like',
        '${_feelsLike.round()}°C',
        'Apparent temperature',
      ),

      _DetailData(
        Icons.water_drop_rounded,
        'Humidity',
        '$_humidity%',
        'Moisture in the air',
      ),

      _DetailData(
        Icons.air_rounded,
        'Wind speed',
        '${_wind.round()} km/h',
        'Recorded wind',
      ),

      _DetailData(
        Icons.wb_sunny_outlined,
        'UV index',
        '$_uv',
        'Sun exposure index',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isTablet ? 4 : 2;

        const gap = 12.0;

        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _GlassCard(
                radius: 23,
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                  height: 128,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, color: Constants.accentCyan, size: 24),

                      const Spacer(),

                      Text(
                        item.value,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Constants.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Constants.textPrimary,
                          fontSize: 13,
                        ),
                      ),

                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Constants.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ==========================================================
  // FORECAST PREVIEW
  // ==========================================================

  Widget _buildForecastPreview() {
    return _GlassCard(
      radius: Constants.cardRadius,
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: _openForecast,
        borderRadius: BorderRadius.circular(18),
        child: const Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: Constants.accentCyan,
              size: 29,
            ),

            SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7-Day Forecast',
                    style: TextStyle(
                      color: Constants.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Explore the upcoming days',
                    style: TextStyle(
                      color: Constants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Constants.textPrimary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL DATA
// ============================================================

class _DetailData {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _DetailData(this.icon, this.label, this.value, this.subtitle);
}

// ============================================================
// BACKGROUND GLOW
// ============================================================

class _BackgroundGlow extends StatelessWidget {
  final double diameter;
  final Color color;

  const _BackgroundGlow({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

// ============================================================
// GLASS CARD
// ============================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.radius = Constants.cardRadius,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Constants.glassBlur,
          sigmaY: Constants.glassBlur,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Constants.glassBackground,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Constants.glassBorder,
              width: Constants.glassBorderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// CITY SEARCH SHEET
// ============================================================

class _CitySearchSheet extends StatefulWidget {
  final ValueChanged<String> onCitySelected;

  const _CitySearchSheet({required this.onCitySelected});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  int _requestVersion = 0;

  bool _loading = false;

  String? _error;

  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _requestVersion++;
    _controller.dispose();

    super.dispose();
  }

  // ==========================================================
  // SEARCH INPUT
  // ==========================================================

  void _onChanged(String value) {
    _debounce?.cancel();

    final version = ++_requestVersion;
    final query = value.trim();

    setState(() {
      _results = [];
      _error = null;
      _loading = query.length >= 2;
    });

    if (query.length < 2) return;

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(query, version),
    );
  }

  // ==========================================================
  // SEARCH WEATHERAPI
  // ==========================================================

  Future<void> _search(String query, int version) async {
    try {
      final uri = Uri.https('api.weatherapi.com', '/v1/search.json', {
        'key': Constants.apiKey,
        'q': query,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (!mounted || version != _requestVersion) {
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('City search failed');
      }

      final data = jsonDecode(response.body) as List;

      setState(() {
        _results = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'City search unavailable. '
            'Check your connection and retry.';
      });

      debugPrint('City search error: $error');
    }
  }

  // ==========================================================
  // SELECT CITY
  // ==========================================================

  void _choose(Map<String, dynamic> city) {
    final latitude = city['lat'];
    final longitude = city['lon'];

    if (latitude == null || longitude == null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    widget.onCitySelected('$latitude,$longitude');
  }

  // ==========================================================
  // SEARCH UI - SAFE AREA AND KEYBOARD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        bottom: true,
        left: true,
        right: true,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .70,
          ),
          decoration: const BoxDecoration(
            color: Constants.searchBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Constants.searchRadius),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 48,
                decoration: BoxDecoration(
                  color: Constants.glassBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Find your city',
                      style: TextStyle(
                        color: Constants.textPrimary,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Constants.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Constants.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search city or region',
                  hintStyle: const TextStyle(color: Constants.textSoft),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Constants.accentCyan,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  filled: true,
                  fillColor: Constants.glassBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) {
                  if (_results.isNotEmpty) {
                    _choose(_results.first);
                  } else if (value.trim().isNotEmpty) {
                    widget.onCitySelected(value.trim());
                  }
                },
              ),

              const SizedBox(height: 14),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(color: Constants.accentCyan),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Constants.textSecondary),
                  ),
                ),

              if (!_loading && _error == null && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    _controller.text.trim().length < 2
                        ? 'Type at least 2 letters to search'
                        : 'No matching cities found',
                    style: const TextStyle(color: Constants.textSoft),
                  ),
                ),

              if (_results.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Constants.glassDivider),
                    itemBuilder: (context, index) {
                      final city = _results[index];

                      final name = city['name']?.toString() ?? '';

                      final region = city['region']?.toString() ?? '';

                      final country = city['country']?.toString() ?? '';

                      return ListTile(
                        onTap: () => _choose(city),
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Constants.accentCyan,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Constants.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            region,
                            country,
                          ].where((part) => part.isNotEmpty).join(', '),
                          style: const TextStyle(color: Constants.textSoft),
                        ),
                        trailing: const Icon(
                          Icons.north_west_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
