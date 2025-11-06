import 'package:flutter/material.dart';

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

  Widget _scoreWidget(int score) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Your Visual Acuity Score:',
          style: TextStyle(
            fontSize: 22,
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.07,
        ),
        CircleAvatar(
          radius: MediaQuery.of(context).size.width * 0.3,
          child: score == 0
              ? const Text(
                  '10 / -',
                  style: TextStyle(
                    fontSize: 32,
                  ),
                )
              : Text(
                  '10 / ' + score.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                  ),
                ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.07,
        ),
        score == 0
            ? const Text(
                'You were not able to read the row of maximum size set for this chart. Your visual acuity score is beyond the scope of this test. Please visit an ophthalmologist for a check-up.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                ),
              )
            : score > 10
                ? const Text(
                    'Your vision is poorer than an average person.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                    ),
                  )
                : score == 10
                    ? const Text(
                        'Your vision is normal as that of an average person.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      )
                    : const Text(
                        'Your vision is better than an average person.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                        ),
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
                            fontSize: 14,
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
              _scoreWidget(
                _isRightEye ? widget.rightEyeScore : widget.leftEyeScore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
