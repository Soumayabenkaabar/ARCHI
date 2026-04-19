import 'package:flutter/material.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatelessWidget {
  final String backgroundImage;

  const SignupScreen({this.backgroundImage = "assets/images/arr2.jpg"});

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isDesktop = width > 800;

    return Scaffold(body: isDesktop ? _desktop(context) : _mobile(context));
  }

  Widget _desktop(BuildContext context) {
    return Stack(
      children: [
        /// 🔥 IMAGE FULL
        Positioned.fill(child: Image.asset(backgroundImage, fit: BoxFit.cover)),

        /// 🔥 OVERLAY
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

        /// 🔥 FORM CENTER
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 450), // 🔥 IMPORTANT
              child: signupForm(context, isMobile: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobile(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(backgroundImage, fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),
        Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: signupForm(context, isMobile: true),
          ),
        ),
      ],
    );
  }

  Widget signupForm(BuildContext context, {bool isMobile = false}) {
    Widget content = _formContent(context, isMobile);

    if (isMobile) {
      return glassContainer(child: content);
    }

    return Container(
      width: 400,
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: content,
    );
  }

  Widget _formContent(BuildContext context, bool isMobile) {
    Color textColor = isMobile ? Colors.white : Colors.black;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Sign Up",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 20),
        TextField(decoration: inputDecoration("Name", Icons.person, isMobile)),
        SizedBox(height: 15),
        TextField(decoration: inputDecoration("Email", Icons.email, isMobile)),
        SizedBox(height: 15),
        TextField(
          obscureText: true,
          decoration: inputDecoration("Password", Icons.lock, isMobile),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            child: Text("Create account"),
          ),
        ),
        SizedBox(height: 15),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            "Already have an account?",
            style: TextStyle(color: textColor),
          ),
        ),
      ],
    );
  }

  InputDecoration inputDecoration(String hint, IconData icon, bool isMobile) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: isMobile ? Colors.white.withOpacity(0.2) : Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}