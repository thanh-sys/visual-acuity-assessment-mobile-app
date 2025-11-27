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

  Widget _buildChart(List<Map<String, dynamic>> tests) {
    if (tests.isEmpty) {
      return const SizedBox.shrink();
    }

    // Tạo dữ liệu cho biểu đồ
    final leftEyeSpots = <FlSpot>[];
    final rightEyeSpots = <FlSpot>[];
    
    for (int i = 0; i < tests.length; i++) {
      final test = tests[i];
      final leftScore = (test['leftEyeScore'] as int).toDouble();
      final rightScore = (test['rightEyeScore'] as int).toDouble();
      
      leftEyeSpots.add(FlSpot(i.toDouble(), leftScore));
      rightEyeSpots.add(FlSpot(i.toDouble(), rightScore));
    }

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
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 2,
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
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '10/${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
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
                maxX: (tests.length - 1).toDouble(),
                minY: 0,
                maxY: 30,
                lineBarsData: [
                  // Left Eye line
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
                  // Right Eye line
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
                            return LineTooltipItem(
                              '${isLeftEye ? 'Left' : 'Right'} Eye\n10/${barSpot.y.toInt()}',
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
          // Legend
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
                            // Date header
                            Text(
                              _formatDate(timestamp),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Scores row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Left Eye
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
                                // Right Eye
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
