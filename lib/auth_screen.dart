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
  final TextEditingController _nameController = TextEditingController(); 
  bool isLogin = true;
  bool _isLoading = false;

  void _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in email and password."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        // 1. Log in existing user
        User? user = await FirebaseService().login(email, password);
        
        if (user != null && mounted) {
          UserProfile profile = UserProfile(); 
          final userData = await FirebaseService().getUserData(user.uid);
          profile.username = userData?['username'] ?? email.split('@').first;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationContainer(
                profile: profile,      
                initialGoals: "Welcome back!", 
              ),
            ),
          );
        }
      } else {
        // 2. Sign up new user
        User? user = await FirebaseService().signUp(email, password, name);

        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SurveyScreen()),
          );
        }
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = "This email is already registered. Please tap 'Login' below.";
            break;
          case 'wrong-password':
          case 'invalid-credential':
            errorMessage = "Incorrect email or password.";
            break;
          case 'user-not-found':
            errorMessage = "No account found with this email.";
            break;
          case 'weak-password':
            errorMessage = "Password should be at least 6 characters.";
            break;
          case 'invalid-email':
            errorMessage = "Please enter a valid email address.";
            break;
          default:
            errorMessage = e.message ?? e.toString();
        }
      } else if (errorMessage.contains('permission-denied')) {
        errorMessage = "Firestore permission denied. Please publish updated Firestore rules in Firebase Console.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: resetController,
          decoration: const InputDecoration(labelText: "Enter your email", border: OutlineInputBorder()),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final resetEmail = resetController.text.trim();
              if (resetEmail.isNotEmpty) {
                try {
                  await FirebaseService().sendPasswordReset(resetEmail);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Password reset email sent to $resetEmail")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Formula Money", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 30),
              
              // Name Field: Only shows when signing up
              if (!isLogin) ...[
                TextField(
                  controller: _nameController, 
                  decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
              ],

              TextField(
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController, 
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), 
                obscureText: true,
              ),
              const SizedBox(height: 10),

              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text("Forgot Password?"),
                  ),
                ),
              const SizedBox(height: 10),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isLogin ? "Login" : "Join the Game"),
              ),
              
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "New here? Create Account" : "Already a member? Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}