import 'package:bulleted_list/bulleted_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/Instructions/cover_eye_instruction.dart';
import 'package:flutter_application_1/Screens/Measure/measure_acuity.dart';

class Instructions extends StatefulWidget {
  const Instructions({
    Key? key,
  }) : super(key: key);

  @override
  State<Instructions> createState() => _InstructionsState();
}

class _InstructionsState extends State<Instructions> {
  final _listOfInstructions = [
    "Setup: Choose a well-lit room, avoiding screen glare. Place your phone on a stable surface at eye level.",
    "Audio: A quiet environment is best. You are recommended to wear Bluetooth headphones for ease of speech recognition.",
    "Distance: An AI Nurse will guide you. Maintaining the 3-meter distance is crucial. The app will use the camera to help verify this.",
    "Test Order: You must attempt the test twice. IMPORTANT: You must follow the order: RIGHT eye first, then LEFT eye second.",
    "Eye Occlusion: When testing your left eye, cover your right eye with a plain occluder, card, or tissue. Do not press on your eye. The AI Nurse will verify this.",
    "The Test: The Snellen's Chart (letters) will be displayed on the screen.",
    "Voice Command: You MUST strictly say the phrase 'THE LETTER X', where X is the letter you see (e.g., 'THE LETTER E').",
    "Speech Errors: If you fail to speak the complete phrase, or if there is a disturbance in recognition, you will be prompted to try again.",
    "Test Flow: For every row in the Snellen's Chart, three letters will be displayed one-by-one. If you read correctly, the letters will get smaller (next row).",
    "Stopping Rule: The test for one eye will end if you are unable to guess 2 out of 3 letters displayed in a row.",
    "Guessing: If at any point you are unable to read the letter, guess and speak out any random letter, using the same 'THE LETTER X' format.",
    "Results: Once the test has successfully completed, the score for the respective eye will be displayed.",
    "Next Eye: You will then repeat the entire process for your right eye (covering your left eye).",
    "Starting: The test will start as soon as you press 'Ok'. Get in position before pressing the button.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.03,
                  ),
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.height * 0.1,
                  child: Image.asset(
                    'assets/images/app-bar.png',
                  ),
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Please read the instructions carefully',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: BulletedList(
                  style: const TextStyle(
                    fontFamily: 'ABeeZee',
                    color: Colors.black,
                  ),
                  listItems: _listOfInstructions,
                  bulletType: BulletType.conventional,
                  bulletColor: Colors.grey.shade800,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Start with distance check - cover right eye first
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) {
                          return CoverEyeInstruction(
                            eyeToCover: 'right',
                            // onCoverConfirmed: (eyeToTest) {
                            //   // eyeToTest is 'left' (right eye is covered, so we test left eye)
                            //   Navigator.of(context).pushReplacement(
                            //     MaterialPageRoute(
                            //       builder: (context) => MeasureAcuity(eyeToTest: eyeToTest),
                            //     ),
                            //   );
                            // },
                            leftEyeScore: 0,  // TRUYỀN QUA ĐÂY
                          );
                        },
                      ),
                    );
                  },
                  child: const Text(
                    'Start (with distance check)',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  style: ButtonStyle(
                    fixedSize: WidgetStateProperty.all(
                      Size.fromWidth(MediaQuery.of(context).size.width * 0.44),
                    ),
                    elevation: WidgetStateProperty.all(5),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Start without distance check - cover right eye first
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) {
                          return CoverEyeInstruction(
                            eyeToCover: 'right',
                            // onCoverConfirmed: (eyeToTest) {
                            //   // eyeToTest is 'left' (right eye is covered, so we test left eye)
                            //   Navigator.of(context).pushReplacement(
                            //     MaterialPageRoute(
                            //       builder: (context) => MeasureAcuity(eyeToTest: eyeToTest),
                            //     ),
                            //   );
                            // },
                            leftEyeScore: 0,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text(
                    'Start (skip distance check)',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  style: ButtonStyle(
                    fixedSize: WidgetStateProperty.all(
                      Size.fromWidth(MediaQuery.of(context).size.width * 0.44),
                    ),
                    elevation: WidgetStateProperty.all(5),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
