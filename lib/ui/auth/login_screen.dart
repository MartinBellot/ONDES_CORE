import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });
    
    bool success;
    if (_isRegistering) {
       success = await AuthService().register(_emailCtrl.text.split('@')[0], _passCtrl.text, _emailCtrl.text); 
    } else {
       success = await AuthService().login(_emailCtrl.text, _passCtrl.text); // Using email as username for simplicity here, or separate fields
       // Actually my backend expects 'username'. Let's assume username input for now or handle email logic
    }

    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _error = "Échec de l'authentification. Vérifiez vos identifiants.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.waves, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text("Ondes Core", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nom d'utilisateur",
                  filled: true,
                  fillColor: Colors.white10,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Mot de passe",
                  filled: true,
                  fillColor: Colors.white10,
                ),
              ),
               
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),

              const SizedBox(height: 30),
              
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    child: Text(_isRegistering ? "Créer un compte" : "Se connecter"),
                  ),
                ),
              
              TextButton(
                onPressed: () => setState(() => _isRegistering = !_isRegistering),
                child: Text(_isRegistering ? "J'ai déjà un compte" : "Créer un compte"), 
              )
            ],
          ),
        ),
      ),
    );
  }
}
