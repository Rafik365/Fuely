// lib/screens/login_screen.dart - User login screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/homeScreen.dart';
import 'package:trip_tank_fuely/registerScreen.dart';

class LoginScreen extends StatefulWidget {
    const LoginScreen({super.key});

    @override
    _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
    final _formKey = GlobalKey<FormState>();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();

    @override
    void dispose() {
        _emailController.dispose();
        _passwordController.dispose();
        super.dispose();
    }

    Future<void> _login() async {
        if (_formKey.currentState!.validate()) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            print("Login attempt with: ${_emailController.text.trim()}");
            
            final success = await authProvider.login(
                _emailController.text.trim(),
                _passwordController.text.trim(),
            );


            print("Login success: $success, error: ${authProvider.errorMessage}");

            if (success && mounted) {

                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
            }
        }
    }

    @override
    Widget build(BuildContext context) {
        final authProvider = Provider.of<AuthProvider>(context);

        return Scaffold(
            appBar: AppBar(
                    title: const Text('Login'),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
        key: _formKey,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter your email';
        }
        if (!value.contains('@')) {
            return 'Please enter a valid email';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _passwordController,
            obscureText: true,
        decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter your password';
        }
        if (value.length < 6) {
            return 'Password must be at least 6 characters';
        }
        return null;
    },
        ),
        const SizedBox(height: 24),
        if (authProvider.errorMessage.isNotEmpty)
            Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
        child: Text(
        authProvider.errorMessage,
        style: TextStyle(color: Colors.red[900]),
        ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: authProvider.isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        ),
        child: authProvider.isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : const Text('Login'),
        ),
        const SizedBox(height: 16),
        TextButton(
            onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
        },
        child: const Text('Don\'t have an account? Register'),
        ),
        ],
        ),
        ),
        ),
        );
    }
}
