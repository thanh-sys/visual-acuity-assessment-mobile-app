import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TestHistory extends StatefulWidget {
  const TestHistory({Key? key}) : super(key: key);

  @override
  State<TestHistory> createState() => _TestHistoryState();
}

class _TestHistoryState extends State<TestHistory> {
  late Future<List<Map<String, dynamic>>> _testHistory;

  @override
  void initState() {
    super.initState();
    _testHistory = _fetchTestHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchTestHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('vision_tests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'docId': doc.id,
          'leftEyeScore': data['leftEyeScore'] ?? 0,
          'rightEyeScore': data['rightEyeScore'] ?? 0,
          'timestamp': data['timestamp'] as Timestamp?,
          'testDate': data['testDate'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching test history: $e');
      return [];
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (timestamp is String) {
      try {
        final dateTime = DateTime.parse(timestamp);
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return timestamp;
      }
    }
    return 'Unknown date';
  }

  String _formatShortDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
    } else if (timestamp is String) {
      try {
        final dateTime = DateTime.parse(timestamp);
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  String _getFormattedScore(int score) {
    if (score == 0) return '10/-';
    return '10/$score';
  }

  String _getInterpretation(int score) {
    if (score == 0) {
      return 'Unable to determine';
    } else if (score > 10) {
      return 'Poorer than normal';
    } else if (score == 10) {
      return 'Normal vision';
    } else {
      return 'Better than normal';
    }
  }

  String _getTrendAnalysis(List<Map<String, dynamic>> tests) {
    if (tests.length < 2) return '';
    
    final reversedTests = tests.reversed.toList();
    
    final firstLeftScore = reversedTests.first['leftEyeScore'] as int;
    final lastLeftScore = reversedTests.last['leftEyeScore'] as int;
    final firstRightScore = reversedTests.first['rightEyeScore'] as int;
    final lastRightScore = reversedTests.last['rightEyeScore'] as int;
    
    final leftDiff = lastLeftScore - firstLeftScore;
    final rightDiff = lastRightScore - firstRightScore;
    
    String leftTrend = '';
    String rightTrend = '';
    
    if (leftDiff < 0) {
      leftTrend = 'Left eye: Improved ↗ (${leftDiff.abs()} points better)';
    } else if (leftDiff > 0) {
      leftTrend = 'Left eye: Declined ↘ (${leftDiff} points worse)';
    } else {
      leftTrend = 'Left eye: Stable →';
    }
    
    if (rightDiff < 0) {
      rightTrend = 'Right eye: Improved ↗ (${rightDiff.abs()} points better)';
    } else if (rightDiff > 0) {
      rightTrend = 'Right eye: Declined ↘ (${rightDiff} points worse)';
    } else {
      rightTrend = 'Right eye: Stable →';
    }
    
    return '$leftTrend\n$rightTrend';
  }

  Widget _buildChart(List<Map<String, dynamic>> tests) {
    if (tests.isEmpty) {
      return const SizedBox.shrink();
    }

    final reversedTests = tests.reversed.toList();
    
    final leftEyeSpots = <FlSpot>[];
    final rightEyeSpots = <FlSpot>[];
    
    for (int i = 0; i < reversedTests.length; i++) {
      final test = reversedTests[i];
      final leftScore = (test['leftEyeScore'] as int).toDouble();
      final rightScore = (test['rightEyeScore'] as int).toDouble();
      
      leftEyeSpots.add(FlSpot(i.toDouble(), -leftScore));
      rightEyeSpots.add(FlSpot(i.toDouble(), -rightScore));
    }

    final allScores = [
      ...leftEyeSpots.map((s) => s.y),
      ...rightEyeSpots.map((s) => s.y),
    ];
    
    double minY = allScores.reduce((a, b) => a < b ? a : b);
    double maxY = allScores.reduce((a, b) => a > b ? a : b);
    
    // Tăng padding để cột Y dài hơn (từ 0.2 lên 0.5)
    final yPadding = (maxY - minY) * 0.5;
    minY = minY - yPadding;
    maxY = (maxY + yPadding).clamp(double.negativeInfinity, 0);
    
    minY = (minY / 2).floor() * 2.0;
    maxY = (maxY / 2).ceil() * 2.0;
    
    // Tăng khoảng cách tối thiểu (từ 6 lên 10)
    if (maxY - minY < 10) {
      final center = (maxY + minY) / 2;
      minY = center - 5;
      maxY = (center + 5).clamp(double.negativeInfinity, 0);
    }
    
    final yInterval = ((maxY - minY) / 5).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vision Acuity Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getTrendAnalysis(tests),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: yInterval,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 0.8,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 0.8,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Test Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < reversedTests.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                _formatShortDate(reversedTests[index]['timestamp']),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Text(
                        'Vision Score\n(lower is better)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yInterval,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            '10/${(-value).toInt()}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: (reversedTests.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: leftEyeSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: rightEyeSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.green,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes
                        .map((index) {
                          return TouchedSpotIndicatorData(
                            FlLine(
                              color: Colors.grey.withOpacity(0.4),
                              strokeWidth: 2,
                            ),
                            FlDotData(
                              getDotPainter:
                                  (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: Colors.yellow,
                                  strokeWidth: 2,
                                  strokeColor: Colors.orange,
                                );
                              },
                            ),
                          );
                        })
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems:
                        (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots
                          .map((barSpot) {
                            final isLeftEye = barSpot.barIndex == 0;
                            final index = barSpot.x.toInt();
                            final dateStr = _formatShortDate(reversedTests[index]['timestamp']);
                            return LineTooltipItem(
                              '$dateStr\n${isLeftEye ? 'Left' : 'Right'} Eye\n10/${(-barSpot.y).toInt()}',
                              TextStyle(
                                color: isLeftEye
                                    ? Colors.blue
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          })
                          .toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Left Eye', Colors.blue),
              const SizedBox(width: 30),
              _buildLegendItem('Right Eye', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _testHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading test history: ${snapshot.error}'),
            );
          }

          final tests = snapshot.data ?? [];

          if (tests.isEmpty) {
            return const Center(
              child: Text(
                'No test history available',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildChart(tests),
                ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    final leftScore = test['leftEyeScore'] as int;
                    final rightScore = test['rightEyeScore'] as int;
                    final timestamp = test['timestamp'];

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(timestamp),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Left Eye',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      CircleAvatar(
                                        radius: 35,
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        child: Text(
                                          _getFormattedScore(leftScore),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _getInterpretation(leftScore),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Right Eye',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      CircleAvatar(
                                        radius: 35,
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        child: Text(
                                          _getFormattedScore(rightScore),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _getInterpretation(rightScore),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}