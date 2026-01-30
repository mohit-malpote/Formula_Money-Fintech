import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart'; 
import 'main.dart';

class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Added Name Controller
  final TextEditingController _nameController = TextEditingController(); 
  bool isLogin = true;

  void _handleAuth() async {
    try {
      if (isLogin) {
        // 1. Log in existing user
        User? user = await FirebaseService().login(
          _emailController.text, 
          _passwordController.text
        );
        
        if (user != null) {
          UserProfile dummyProfile = UserProfile(); 
          dummyProfile.username = "User"; // Fallback name

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationContainer(
                profile: dummyProfile,      
                initialGoals: "Welcome back!", 
              ),
            ),
          );
        }
      } else {
        // 2. Sign up new user
        // Now using _nameController.text instead of "New Player"
        User? user = await FirebaseService().signUp(
          _emailController.text, 
          _passwordController.text,
          _nameController.text 
        );

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SurveyScreen()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Add the logo using the 'screenshot' path
            Image.asset(
              'screenshots/logo.jpeg', 
              height: 100, 
            ),
            const SizedBox(height: 20),
            Text("Formula Money", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 30),
            
            // New Name Field: Only shows when signing up
            if (!isLogin) ...[
              TextField(
                controller: _nameController, 
                decoration: InputDecoration(labelText: "Full Name", border: OutlineInputBorder())
              ),
              const SizedBox(height: 15),
            ],

            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _handleAuth,
              child: Text(isLogin ? "Login" : "Join the Game"),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? "New here? Create Account" : "Already a member? Login"),
            )
          ],
        ),
      ),
    );
  }
}