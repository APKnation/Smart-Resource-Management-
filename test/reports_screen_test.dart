import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:e_resource/core/theme.dart';

/// Verifies that fl_chart's [BarChart] renders correctly with
/// [SideTitleWidget] using the `axisSide` parameter — the API
/// that was broken in fl_chart 0.68.0 and fixed in reports_screen.dart.
void main() {
  testWidgets('BarChart with SideTitleWidget(axisSide:) renders',
      (WidgetTester tester) async {
    // Sample data: 7 days of download counts.
    final values = [3.0, 7.0, 2.0, 5.0, 8.0, 4.0, 6.0];
    final days = List.generate(7, (i) {
      final d = DateTime(2025, 1, 1 + i);
      return DateTime(d.year, d.month, d.day);
    });
    final maxVal = values.fold(1.0, (a, b) => b > a ? b : a);

    Widget dayLabel(double value, TitleMeta meta, List<DateTime> days) {
      final idx = value.toInt();
      if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          DateFormat('MM/dd').format(days[idx]),
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxVal + 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                    ),
                  ),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) =>
                          dayLabel(value, meta, days),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.blue,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Pump the widget to allow fl_chart to render its bar chart.
    await tester.pumpAndSettle();

    // Verify the bar chart renders.
    expect(find.byType(BarChart), findsOneWidget);

    // Verify day labels are rendered.
    expect(find.text('01/01'), findsOneWidget);
    expect(find.text('01/07'), findsOneWidget);
  });
}
