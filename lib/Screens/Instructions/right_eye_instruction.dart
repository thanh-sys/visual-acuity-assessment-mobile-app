import 'package:flutter_application_1/Screens/Measure/measure_acuity.dart';  // Temporarily commented
import 'package:flutter/material.dart';

class RightEyeInstruction extends StatefulWidget {
  const RightEyeInstruction({Key? key}) : super(key: key);

  @override
  State<RightEyeInstruction> createState() => _RightEyeInstructionState();
}

class _RightEyeInstructionState extends State<RightEyeInstruction> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Please cover your right eye.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Image.asset(
                  'assets/images/righteye.png',
                  fit: BoxFit.fitHeight,
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              const Text(
                "Once done, press 'Ready'",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) {
                        return const MeasureAcuity();
                      },
                    ),
                  );
                },
                child: const Text(
                  'Ready',
                  style: TextStyle(
                    fontSize: 22,
                  ),
                ),
                style: ButtonStyle(
                  elevation: WidgetStateProperty.all(5),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
