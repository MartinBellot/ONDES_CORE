import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_library_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _bioCtrl = TextEditingController();
  File? _newAvatar;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _user = AuthService().currentUser;
      _bioCtrl.text = _user?['bio'] ?? "";
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _newAvatar = File(picked.path);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    await AuthService().updateProfile(
      bio: _bioCtrl.text,
      avatar: _newAvatar
    );
     setState(() {
        _isLoading = false;
        _loadData();
        _newAvatar = null;
     });
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour !")));
  }

  Future<void> _deleteAllApps() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Attention"),
        content: const Text("Voulez-vous vraiment supprimer toutes les applications locales ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer tout", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true) {
       setState(() => _isLoading = true);
       await AppLibraryService().deleteAllApps();
       setState(() => _isLoading = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applications supprimées")));
       }
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    // In strict architecture we would use a Stream/Listener on AuthState, 
    // but here we might need to recreate the Root widget structure or trigger a rebuild.
    // For now we assume Main handles it or we restart.
    // Ideally we navigate to Main which redirects to Login.
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/'); // Trigger Main rebuild?
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: Text("Non connecté"));
    
    // Construct Avatar provider
    ImageProvider avatarProvider;
    if (_newAvatar != null) {
      avatarProvider = FileImage(_newAvatar!);
    } else if (_user!['avatar'] != null) {
      String url = _user!['avatar'];
      if (!url.startsWith('http')) url = "http://127.0.0.1:8000$url";
      avatarProvider = NetworkImage(url);
    } else {
       avatarProvider = const NetworkImage("https://via.placeholder.com/150"); 
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Profil"),
         actions: [
          IconButton(
            onPressed: () async {
               await AuthService().logout();
               // Trigger a full app rebuild/navigation
               // Since we are inside a TabView, it's tricky. 
               // We will use a global key or proper State Management later.
               // For now, hack:
               runApp(const MaterialApp(home: Scaffold(body: Center(child: Text("Restarting..."))))); // Terrible hack but resets
               // Actually, `main.dart` should listen to auth change.
            }, 
            icon: const Icon(Icons.logout, color: Colors.redAccent)
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             GestureDetector(
               onTap: _pickImage,
               child: CircleAvatar(
                 radius: 60,
                 backgroundImage: avatarProvider,
                 child: const Icon(Icons.camera_alt, color: Colors.white54, size: 30),
               ),
             ),
             const SizedBox(height: 20),
             Text("@${_user!['username']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
             Text(_user!['email'] ?? "", style: const TextStyle(color: Colors.white54)),
             
             const SizedBox(height: 30),
             
             TextField(
               controller: _bioCtrl,
               style: const TextStyle(color: Colors.white),
               maxLines: 4,
               decoration: const InputDecoration(
                 labelText: "Biographie",
                 filled: true,
                 fillColor: Colors.white10,
                 border: OutlineInputBorder()
               ),
             ),

             const SizedBox(height: 20),

             SizedBox(
               width: double.infinity,
               height: 50,
               child: ElevatedButton(
                 onPressed: _isLoading ? null : _save,
                 child: _isLoading ? const CircularProgressIndicator() : const Text("Enregistrer"),
               ),
             ),

             const SizedBox(height: 40),
             
             TextButton.icon(
               onPressed: _isLoading ? null : _deleteAllApps,
               icon: const Icon(Icons.delete_forever, color: Colors.white54),
               label: const Text("Supprimer toutes les apps locales", style: TextStyle(color: Colors.white54)),
             )
          ],
        ),
      ),
    );
  }
}
