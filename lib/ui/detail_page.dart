import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_weather_app_v2/components/weather_icon.dart';
import 'package:flutter_weather_app_v2/constants.dart';
import 'package:intl/intl.dart';

class DetailPage extends StatefulWidget {
  final List dailyForecastWeather;

  const DetailPage({super.key, required this.dailyForecastWeather});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _dateLabel(dynamic value) {
    try {
      return DateFormat(
        'EEEE, d MMMM',
      ).format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  String _shortDate(dynamic value) {
    try {
      return DateFormat('EEE, d MMM').format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  int _number(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return num.tryParse(value.toString())?.round() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Constants.backgroundNavy,
      body: Stack(
        children: [
          // Shared background gradient.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: Constants.backgroundGradient),
            ),
          ),

          // Background glow decorations.
          Positioned(
            top: -120,
            right: -100,
            child: _BackgroundGlow(
              diameter: 340,
              color: Constants.accentBlue.withValues(alpha: .22),
            ),
          ),

          Positioned(
            bottom: 60,
            left: -140,
            child: _BackgroundGlow(
              diameter: 310,
              color: Constants.accentPurple.withValues(alpha: .15),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),

                const SizedBox(height: 12),

                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Constants.searchRadius),
                        ),
                        child: Stack(
                          children: [
                            _buildScrollableBody(isTablet),

                            // Prevent forecast cards from
                            // appearing inside the header
                            // when scrolling upward.
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: SizedBox(
                                  height: 30,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: Constants.scrollFadeGradient,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          _GlassCard(
            radius: 17,
            padding: EdgeInsets.zero,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Constants.textPrimary,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Text(
              'Forecasts',
              style: TextStyle(
                color: Constants.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Icon(
            Icons.calendar_month_rounded,
            color: Constants.accentCyan,
            size: 27,
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildScrollableBody(bool isTablet) {
    if (widget.dailyForecastWeather.isEmpty) {
      return const Center(
        child: Text(
          'Forecast data is not available.',
          style: TextStyle(color: Constants.textPrimary, fontSize: 16),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isTablet ? 32 : 18,
        28,
        isTablet ? 32 : 18,
        35,
      ),
      children: [
        _buildOverview(),

        const SizedBox(height: 28),

        const Text(
          'Daily forecast',
          style: TextStyle(
            color: Constants.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Plan ahead with the upcoming weather',
          style: TextStyle(color: Constants.textMuted, fontSize: 13),
        ),

        const SizedBox(height: 18),

        ...List.generate(widget.dailyForecastWeather.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _buildDayCard(widget.dailyForecastWeather[index], index),
          );
        }),
      ],
    );
  }

  Widget _buildOverview() {
    final first = widget.dailyForecastWeather.first;
    final day = first['day'];

    final condition = day['condition']['text'].toString();

    final maxTemp = _number(day['maxtemp_c']);
    final minTemp = _number(day['mintemp_c']);

    return _GlassCard(
      radius: Constants.searchRadius,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Constants.accentCyan,
                size: 21,
              ),

              SizedBox(width: 9),

              Text(
                'Weather outlook',
                style: TextStyle(
                  color: Constants.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 330;

              final icon = SizedBox(
                width: compact ? 100 : 120,
                height: compact ? 100 : 120,
                child: WeatherIcon(
                  file: weatherIconFile(condition),
                  width: compact ? 100 : 120,
                ),
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Constants.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '$maxTemp° / $minTemp°',
                    style: const TextStyle(
                      color: Constants.textPrimary,
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _dateLabel(first['date']),
                    style: const TextStyle(
                      color: Constants.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  children: [icon, const SizedBox(height: 8), details],
                );
              }

              return Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(dynamic forecast, int index) {
    final day = forecast['day'];

    final condition = day['condition']['text'].toString();

    final maxTemp = _number(day['maxtemp_c']);
    final minTemp = _number(day['mintemp_c']);
    final wind = _number(day['maxwind_kph']);
    final humidity = _number(day['avghumidity']);
    final rain = _number(day['daily_chance_of_rain'] ?? 0);

    final isToday = index == 0;

    return _GlassCard(
      radius: 25,
      padding: const EdgeInsets.all(18),
      highlighted: isToday,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isToday ? 'Today' : _shortDate(forecast['date']),
                  style: const TextStyle(
                    color: Constants.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Constants.accentCyan.withValues(alpha: .17),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'CURRENT DAY',
                    style: TextStyle(
                      color: Constants.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: .6,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: WeatherIcon(file: weatherIconFile(condition), width: 76),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Constants.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 6),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            '$maxTemp°',
                            style: const TextStyle(
                              color: Constants.textPrimary,
                              fontSize: 29,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 9),

                          Text(
                            '$minTemp°',
                            style: const TextStyle(
                              color: Constants.textMuted,
                              fontSize: 21,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(height: 1, color: Constants.glassDivider),

          const SizedBox(height: 15),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WeatherChip(icon: Icons.air_rounded, text: '$wind km/h'),

              _WeatherChip(icon: Icons.water_drop_outlined, text: '$humidity%'),

              _WeatherChip(icon: Icons.umbrella_outlined, text: '$rain% rain'),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// REUSABLE GLASS CARD
// ==========================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  const _GlassCard({
    required this.child,
    this.radius = Constants.cardRadius,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
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
            gradient: highlighted ? Constants.glassHighlightGradient : null,
            color: highlighted ? null : Constants.glassBackground,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: highlighted
                  ? Constants.glassHighlight
                  : Constants.glassBorder,
              width: Constants.glassBorderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ==========================================
// WEATHER METRIC CHIP
// ==========================================

class _WeatherChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WeatherChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Constants.glassBackground,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Constants.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Constants.accentCyan, size: 17),

          const SizedBox(width: 6),

          Text(
            text,
            style: const TextStyle(
              color: Constants.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BACKGROUND GLOW DECORATION
// ==========================================

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
