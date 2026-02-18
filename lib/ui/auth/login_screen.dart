import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _error = null; });
    
    bool success;
    if (_isRegistering) {
       final username = _emailCtrl.text.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
       success = await AuthService().register(username, _passCtrl.text, _emailCtrl.text); 
    } else {
       success = await AuthService().login(_emailCtrl.text, _passCtrl.text);
    }

    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _error = _isRegistering 
            ? "Échec de l'inscription. Ce nom d'utilisateur ou email est peut-être déjà pris."
            : "Échec de la connexion. Vérifiez vos identifiants.";
        _isLoading = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return _isRegistering ? 'L\'email est requis' : 'Le nom d\'utilisateur est requis';
    }
    if (_isRegistering) {
      final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Veuillez entrer un email valide';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (_isRegistering && value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waves, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 20),
                Text("Ondes Core", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: _emailCtrl,
                  validator: _validateEmail,
                  keyboardType: _isRegistering ? TextInputType.emailAddress : TextInputType.text,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _isRegistering ? "Email" : "Nom d'utilisateur",
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  validator: _validatePassword,
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
      ),
    );
  }
}
