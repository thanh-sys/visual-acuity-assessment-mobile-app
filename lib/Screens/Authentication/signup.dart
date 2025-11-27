import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/Screens/Authentication/signin.dart';
import 'package:flutter_application_1/Screens/Home/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SignUp extends StatefulWidget {
  const SignUp({
    Key? key,
  }) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  var _email = "";
  var _password = "";
  var _name = "";
  var _confirmPassword = "";
  var _isLoading = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _authentication = FirebaseAuth.instance;

  bool _canLogin() {
    FocusScope.of(context).unfocus();
    var isValid = _formKey.currentState!.validate();
    if (_password != _confirmPassword) {
      isValid = false;
      Fluttertoast.showToast(msg: 'Password did not match');
    }
    if (isValid) {
      _formKey.currentState!.save();
    }
    return isValid;
  }

  void _onSignUp() {
    if (_canLogin()) {
      setState(() {
        _isLoading = true;
      });
      _authentication
          .createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      )
          .then(
        (value) {
          FirebaseFirestore.instance.collection('Users').doc(_email).set(
            {
              'name': _name,
              'email': _email,
              'password': _password.hashCode,
            },
          );
          setState(() {
            _isLoading = false;
          });
          Fluttertoast.showToast(msg: 'Sign Up Successfull');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) {
                return const HomePage(
                  title: 'EyeSuggest',
                );
              },
            ),
          );
        },
      ).catchError(
        (error) {
          setState(() {
            _isLoading = false;
          });
          Fluttertoast.showToast(msg: error.message);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.2,
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/images/app-bar.png'),
            ),
            Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                color: Color.fromRGBO(196, 196, 196, 0.5400000214576721),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Register With Us!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Your information is safe with us.',
                      style: TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Form(
                    key: _formKey,
                    child: Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Enter your full name',
                              hintStyle: TextStyle(
                                fontSize: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Color.fromRGBO(33, 111, 182, 1),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _name = value!;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Enter your email',
                              hintStyle: TextStyle(
                                fontSize: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Color.fromRGBO(33, 111, 182, 1),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _email = value!;
                            },
                          ),
                          TextFormField(
                            obscureText: true,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(
                                fontSize: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Color.fromRGBO(33, 111, 182, 1),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _password = value!;
                            },
                          ),
                          TextFormField(
                            obscureText: true,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Confirm password',
                              hintStyle: TextStyle(
                                fontSize: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Color.fromRGBO(33, 111, 182, 1),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    20.0,
                                  ),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please re-enter your password ';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _confirmPassword = value!;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          height: 50,
                          child: TextButton(
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all(
                                const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20.0),
                                  ),
                                ),
                              ),
                              fixedSize: WidgetStateProperty.all(
                                Size.fromWidth(
                                    MediaQuery.of(context).size.width),
                              ),
                              foregroundColor: WidgetStateProperty.all(
                                Colors.white,
                              ),
                              backgroundColor: WidgetStateProperty.all(
                                Theme.of(context).primaryColor,
                              ),
                              elevation: WidgetStateProperty.all(2),
                            ),
                            onPressed: _onSignUp,
                          ),
                        ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) {
                                return const SignIn();
                              },
                            ),
                          );
                        },
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
