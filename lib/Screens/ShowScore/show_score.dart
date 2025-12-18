import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/TestHistory/test_history.dart';
import 'package:flutter_application_1/Screens/Home/home.dart';

class ShowScore extends StatefulWidget {
  final int rightEyeScore;
  final int leftEyeScore;
  const ShowScore({
    Key? key,
    required this.rightEyeScore,
    required this.leftEyeScore,
  }) : super(key: key);

  @override
  State<ShowScore> createState() => _ShowScoreState();
}

class _ShowScoreState extends State<ShowScore> {
  var _isRightEye = true;
  // Format display: 0 = Snellen (10/x), 1 = Decimal (VA), 2 = Meter (6/x), 3 = 20/20 format
  int _formatDisplay = 0;

  // Get vision impairment category based on WHO standards
  String getVisionCategory() {
    // Use better eye score
    int betterEyeScore = widget.rightEyeScore < widget.leftEyeScore 
        ? widget.rightEyeScore 
        : widget.leftEyeScore;
    
    if (betterEyeScore == 0) return 'Unable to determine';
    
    // Convert to 6/x format for comparison
    int meterScore = (betterEyeScore * 6 ~/ 10);
    if (meterScore == 0) meterScore = 1;
    
    // WHO Categories based on better eye
    // Normal: 6/6 to 6/12
    // Mild vision impairment: worse than 6/12, equal to or better than 6/18
    // Moderate vision impairment: worse than 6/18, equal to or better than 6/60
    // Severe vision impairment: worse than 6/60
    
    if (meterScore <= 12) {
      return 'Normal vision';
    } else if (meterScore <= 18) {
      return 'Mild vision impairment';
    } else if (meterScore <= 60) {
      return 'Moderate vision impairment';
    } else {
      return 'Severe vision impairment';
    }
  }
  
  // Get category explanation
  String getCategoryExplanation() {
    String category = getVisionCategory();
    switch (category) {
      case 'Normal vision':
        return 'Your vision in the better eye is within normal range (6/6 to 6/12).';
      case 'Mild vision impairment':
        return 'Visual acuity in your better eye is worse than 6/12 but equal to or better than 6/18. Consider consulting an eye specialist.';
      case 'Moderate vision impairment':
        return 'Visual acuity in your better eye is worse than 6/18 but equal to or better than 6/60. We recommend seeing an ophthalmologist soon.';
      case 'Severe vision impairment':
        return 'Visual acuity in your better eye is worse than 6/60. Please consult an ophthalmologist as soon as possible.';
      default:
        return '';
    }
  }
  
  // Get category color
  Color getCategoryColor() {
    String category = getVisionCategory();
    switch (category) {
      case 'Normal vision':
        return Colors.green;
      case 'Mild vision impairment':
        return Colors.orange;
      case 'Moderate vision impairment':
        return Colors.deepOrange;
      case 'Severe vision impairment':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Convert score to different formats
  String getFormattedScore(int score) {
    if (score == 0) return 'Unable to determine';
    
    switch (_formatDisplay) {
      case 0: // Snellen 10/x format
        return '10/$score';
      case 1: // Decimal format
        double decimalVA = 10.0 / score;
        return decimalVA.toStringAsFixed(2);
      case 2: // Meter format (6/x)
        int meterScore = (score * 6 ~/ 10);
        if (meterScore == 0) meterScore = 1;
        return '6/$meterScore';
      case 3: // 20/20 format equivalent
        int twentyScore = (score * 20 ~/ 10);
        if (twentyScore == 0) twentyScore = 1;
        return '20/$twentyScore';
      default:
        return '10/$score';
    }
  }

  String getExplanation(int score) {
    if (score == 0) {
      return 'You were not able to read the row of maximum size set for this chart. Your visual acuity score is beyond the scope of this test. Please visit an ophthalmologist for a check-up.';
    }
    
    switch (_formatDisplay) {
      case 0: // Snellen 10/x
        return '''The "10/x" format means:
• "10" = distance in feet where you can read the letters
• "x" = distance from which a normal person can read the same letters

For example, if your score is "10/20", you need to be 10 feet away to read letters that a normal person can read from 20 feet away.''';
      case 1: // Decimal
        double decimalVA = 10.0 / score;
        return '''Decimal format represents visual acuity as a ratio:
• 1.0 = Normal vision (20/20 equivalent)
• > 1.0 = Better than normal vision
• < 1.0 = Worse than normal vision

Your decimal VA: ${decimalVA.toStringAsFixed(2)}''';
      case 2: // Meter
        return '''The "6/x" format is the metric equivalent of "10/x":
• "6" = distance in meters where you can read the letters
• "x" = distance from which a normal person can read the same letters

This is commonly used in countries using the metric system.''';
      case 3: // 20/20 format
        return '''The "20/20" format is the most common visual acuity notation in the US:
• "20" = distance in feet where you can read the letters
• "20" (second) = distance from which a normal person can read the same letters

For example, "20/30" means you need to be 20 feet away to read what a normal person can read from 30 feet away.''';
      default:
        return '';
    }
  }

  Widget _scoreWidget(int score) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Your Visual Acuity Score:',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.05,
        ),
        // Score display
        CircleAvatar(
          radius: MediaQuery.of(context).size.width * 0.2,
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            score == 0 ? '10 / -' : getFormattedScore(score),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.04,
        ),
        // Format explanation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade100,
          ),
          child: Text(
            getExplanation(score),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.04,
        ),
        // Format toggle buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _formatDisplay = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _formatDisplay == 0
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
              ),
              child: Text(
                '10/x',
                style: TextStyle(
                  color: _formatDisplay == 0 ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _formatDisplay = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _formatDisplay == 1
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
              ),
              child: Text(
                'Decimal',
                style: TextStyle(
                  color: _formatDisplay == 1 ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _formatDisplay = 2;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _formatDisplay == 2
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
              ),
              child: Text(
                '6/x',
                style: TextStyle(
                  color: _formatDisplay == 2 ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _formatDisplay = 3;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _formatDisplay == 3
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
              ),
              child: Text(
                '20/20',
                style: TextStyle(
                  color: _formatDisplay == 3 ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.04,
        ),
        // Vision Category based on WHO standards
        if (score != 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getCategoryColor().withOpacity(0.1),
              border: Border.all(color: getCategoryColor(), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: getCategoryColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WHO Classification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: getCategoryColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  getVisionCategory(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: getCategoryColor(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  getCategoryExplanation(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on better eye: ${getFormattedScore(widget.rightEyeScore < widget.leftEyeScore ? widget.rightEyeScore : widget.leftEyeScore)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.03,
        ),
        // Interpretation
        if (score != 0)
          Text(
            score > 10
                ? 'Your vision is poorer than an average person.'
                : score == 10
                    ? 'Your vision is normal as that of an average person.'
                    : 'Your vision is better than an average person.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.05,
        ),
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const HomePage(title: 'Home'),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('Home'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TestHistory(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Test History'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    padding: const EdgeInsets.fromLTRB(25, 5, 25, 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(20),
                      color: _isRightEye
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                    ),
                    
                    child: Center(
                      
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isRightEye = true;
                          });
                        },
                        child: Text(
                          'Right Eye',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isRightEye ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    padding: const EdgeInsets.fromLTRB(25, 5, 25, 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(20),
                      color: _isRightEye
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                    ),
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isRightEye = false;
                          });
                        },
                        child: Text(
                          'Left Eye',
                          style: TextStyle(
                            fontSize: 14,
                            color: _isRightEye ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _scoreWidget(
                    _isRightEye ? widget.rightEyeScore : widget.leftEyeScore,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
