
// lib/screens/register_screen.dart - User registration screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/homeScreen.dart';

class RegisterScreen extends StatefulWidget {
    const RegisterScreen({super.key});

    @override
    _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();

    @override
    void dispose() {
        _nameController.dispose();
        _emailController.dispose();
        _passwordController.dispose();
        super.dispose();
    }

    Future<void> _register() async {
        if (_formKey.currentState!.validate()) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.register(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _nameController.text.trim(),
        );

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
                    title: const Text('Register'),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
        key: _formKey,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: 'Name',
            border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter your name';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
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
            onPressed: authProvider.isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        ),
        child: authProvider.isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : const Text('Register'),
        ),
        ],
        ),
        ),
        ),
        );
    }
}

