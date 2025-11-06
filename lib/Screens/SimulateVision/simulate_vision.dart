import 'dart:ui';

import 'package:flutter/material.dart';

class SimulateVision extends StatefulWidget {
  const SimulateVision({Key? key}) : super(key: key);

  @override
  State<SimulateVision> createState() => _SimulateVisionState();
}

class _SimulateVisionState extends State<SimulateVision> {
  var _score = 0.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(8.0),
        margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
        child: Column(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Image.asset(
                'assets/images/simulate-vision.jpg',
                fit: BoxFit.fitHeight,
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _score == 0.1
                    ? 0.0
                    : _score == 0.2
                        ? 0.0
                        : _score == 0.3
                            ? 0.0
                            : _score == 0.4
                                ? 0.5
                                : _score == 0.5
                                    ? 0.6
                                    : _score == 0.6
                                        ? 0.7
                                        : _score == 0.7
                                            ? 1.0
                                            : _score == 0.8
                                                ? 2.0
                                                : _score == 0.9
                                                    ? 3.0
                                                    : _score == 1.0
                                                        ? 4.0
                                                        : 0.0,
                sigmaY: _score == 0.1
                    ? 0.0
                    : _score == 0.2
                        ? 0.0
                        : _score == 0.3
                            ? 0.0
                            : _score == 0.4
                                ? 0.5
                                : _score == 0.5
                                    ? 0.6
                                    : _score == 0.6
                                        ? 0.7
                                        : _score == 0.7
                                            ? 1.0
                                            : _score == 0.8
                                                ? 2.0
                                                : _score == 0.9
                                                    ? 3.0
                                                    : _score == 1.0
                                                        ? 4.0
                                                        : 0.0,
              ),
              child: Container(
                color: Colors.black.withOpacity(0),
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            const Text('Your Vision'),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.05,
            ),
            Slider(
              value: _score,
              divisions: 10,
              label: _score == 0.1
                  ? '10/4'
                  : _score == 0.2
                      ? '10/7'
                      : _score == 0.3
                          ? '10/10'
                          : _score == 0.4
                              ? '10/15'
                              : _score == 0.5
                                  ? '10/20'
                                  : _score == 0.6
                                      ? '10/30'
                                      : _score == 0.7
                                          ? '10/40'
                                          : _score == 0.8
                                              ? '10/50'
                                              : _score == 0.9
                                                  ? '10/60'
                                                  : _score == 1.0
                                                      ? '10/70'
                                                      : '-',
              onChanged: (changedScore) {
                setState(() {
                  _score = changedScore;
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Excellent'),
                  Text('Poor'),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.025,
            ),
            const Text(
              'Slide to set your Visual Acuity Score',
            ),
          ],
        ),
      ),
    );
  }
}
