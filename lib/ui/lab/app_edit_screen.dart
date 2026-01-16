import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/dev_studio_service.dart';

/// Screen for editing app details in Dev Studio
/// Allows developers to manage category, age rating, banner, screenshots, etc.
class AppEditScreen extends StatefulWidget {
  final MiniApp app;

  const AppEditScreen({super.key, required this.app});

  @override
  State<AppEditScreen> createState() => _AppEditScreenState();
}

class _AppEditScreenState extends State<AppEditScreen> with SingleTickerProviderStateMixin {
  final _service = DevStudioService();
  late TabController _tabController;
  
  MiniApp? _app;
  bool _isLoading = true;
  bool _isSaving = false;
  List<AppCategory> _categories = [];
  
  // Controllers for text fields
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _fullDescCtrl;
  late TextEditingController _whatsNewCtrl;
  late TextEditingController _privacyUrlCtrl;
  late TextEditingController _supportUrlCtrl;
  late TextEditingController _websiteUrlCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _languagesCtrl;
  
  // Selected values
  int? _selectedCategoryId;
  String _selectedAgeRating = '4+';
  
  // File uploads
  File? _newIcon;
  File? _newBanner;
  List<File> _newScreenshots = [];

  static const List<String> _ageRatings = ['4+', '9+', '12+', '17+'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initControllers();
    _loadData();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: widget.app.name);
    _descCtrl = TextEditingController(text: widget.app.description);
    _fullDescCtrl = TextEditingController(text: widget.app.fullDescription);
    _whatsNewCtrl = TextEditingController(text: widget.app.whatsNew);
    _privacyUrlCtrl = TextEditingController(text: widget.app.privacyUrl);
    _supportUrlCtrl = TextEditingController(text: widget.app.supportUrl);
    _websiteUrlCtrl = TextEditingController(text: widget.app.websiteUrl);
    _tagsCtrl = TextEditingController(text: widget.app.tags.join(', '));
    _languagesCtrl = TextEditingController(text: widget.app.languages.join(', '));
    _selectedCategoryId = widget.app.category?.id;
    _selectedAgeRating = widget.app.ageRating;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load categories and app detail in parallel
      final results = await Future.wait([
        _service.getCategories(),
        _service.getAppDetail(widget.app.dbId!),
      ]);
      
      setState(() {
        _categories = results[0] as List<AppCategory>;
        _app = results[1] as MiniApp? ?? widget.app;
        _updateControllersFromApp();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _app = widget.app;
        _isLoading = false;
      });
    }
  }

  void _updateControllersFromApp() {
    if (_app == null) return;
    _nameCtrl.text = _app!.name;
    _descCtrl.text = _app!.description;
    _fullDescCtrl.text = _app!.fullDescription;
    _whatsNewCtrl.text = _app!.whatsNew;
    _privacyUrlCtrl.text = _app!.privacyUrl;
    _supportUrlCtrl.text = _app!.supportUrl;
    _websiteUrlCtrl.text = _app!.websiteUrl;
    _tagsCtrl.text = _app!.tags.join(', ');
    _languagesCtrl.text = _app!.languages.join(', ');
    _selectedCategoryId = _app!.category?.id;
    _selectedAgeRating = _app!.ageRating;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _fullDescCtrl.dispose();
    _whatsNewCtrl.dispose();
    _privacyUrlCtrl.dispose();
    _supportUrlCtrl.dispose();
    _websiteUrlCtrl.dispose();
    _tagsCtrl.dispose();
    _languagesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() => _newIcon = File(result.files.single.path!));
    }
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() => _newBanner = File(result.files.single.path!));
    }
  }

  Future<void> _addScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _newScreenshots.addAll(result.files.map((f) => File(f.path!)));
      });
    }
  }

  Future<void> _saveAll() async {
    if (_app?.dbId == null) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      // Parse tags and languages
      final tags = _tagsCtrl.text
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
      
      final languages = _languagesCtrl.text
          .split(',')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Update app info
      final updatedApp = await _service.updateApp(
        appId: _app!.dbId!,
        name: _nameCtrl.text,
        description: _descCtrl.text,
        fullDescription: _fullDescCtrl.text,
        whatsNew: _whatsNewCtrl.text,
        categoryId: _selectedCategoryId,
        ageRating: _selectedAgeRating,
        privacyUrl: _privacyUrlCtrl.text,
        supportUrl: _supportUrlCtrl.text,
        websiteUrl: _websiteUrlCtrl.text,
        languages: languages,
        tags: tags,
        icon: _newIcon,
        banner: _newBanner,
      );

      // Upload new screenshots
      for (int i = 0; i < _newScreenshots.length; i++) {
        await _service.uploadScreenshot(
          appId: _app!.dbId!,
          screenshot: _newScreenshots[i],
          order: (_app!.screenshots.length) + i,
        );
      }

      if (updatedApp != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application mise à jour avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear new files after successful upload
          setState(() {
            _newIcon = null;
            _newBanner = null;
            _newScreenshots.clear();
          });
          // Reload app data
          _loadData();
        }
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_app?.name ?? 'Chargement...'),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Sauvegarde...' : 'Enregistrer'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Général'),
            Tab(text: 'Médias'),
            Tab(text: 'Métadonnées'),
            Tab(text: 'Paramètres'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildMediaTab(),
                _buildMetadataTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Icon Preview
          Center(
            child: GestureDetector(
              onTap: _pickIcon,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(22),
                      image: _newIcon != null
                          ? DecorationImage(image: FileImage(_newIcon!), fit: BoxFit.cover)
                          : _app?.iconUrl.isNotEmpty == true
                              ? DecorationImage(
                                  image: NetworkImage(_app!.iconUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _newIcon == null && (_app?.iconUrl.isEmpty ?? true)
                        ? const Icon(Icons.apps, size: 48, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Appuyez pour changer l\'icône',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            controller: _nameCtrl,
            label: 'Nom de l\'application',
            icon: Icons.title,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _descCtrl,
            label: 'Description courte',
            icon: Icons.short_text,
            maxLines: 2,
            helperText: 'Affichée dans les listes du Store',
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _fullDescCtrl,
            label: 'Description complète',
            icon: Icons.description,
            maxLines: 6,
            helperText: 'Description détaillée affichée sur la page de l\'app',
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _whatsNewCtrl,
            label: 'Nouveautés de cette version',
            icon: Icons.new_releases,
            maxLines: 4,
            helperText: 'Quoi de neuf dans la dernière version ?',
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Section
          _buildSectionTitle('Bannière', Icons.panorama),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickBanner,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
                image: _newBanner != null
                    ? DecorationImage(image: FileImage(_newBanner!), fit: BoxFit.cover)
                    : _app?.bannerUrl.isNotEmpty == true
                        ? DecorationImage(
                            image: NetworkImage(_app!.bannerUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: _newBanner == null && (_app?.bannerUrl.isEmpty ?? true)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter une bannière (1200x630 recommandé)',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Screenshots Section
          _buildSectionTitle('Captures d\'écran', Icons.screenshot),
          const SizedBox(height: 12),
          
          // Existing screenshots
          if (_app?.screenshots.isNotEmpty ?? false) ...[
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _app!.screenshots.length,
                itemBuilder: (context, index) {
                  final screenshot = _app!.screenshots[index];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            screenshot.imageUrl,
                            fit: BoxFit.cover,
                            height: 220,
                            width: 120,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                            ),
                            icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Supprimer'),
                                  content: const Text('Supprimer cette capture ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _service.deleteScreenshot(
                                  appId: _app!.dbId!,
                                  screenshotId: screenshot.id,
                                );
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // New screenshots to upload
          if (_newScreenshots.isNotEmpty) ...[
            Text(
              'Nouvelles captures (à sauvegarder)',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _newScreenshots.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _newScreenshots[index],
                            fit: BoxFit.cover,
                            height: 120,
                            width: 80,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _newScreenshots.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Add screenshots button
          OutlinedButton.icon(
            onPressed: _addScreenshots,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Ajouter des captures d\'écran'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Selection
          _buildSectionTitle('Catégorie', Icons.category),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButton<int>(
              value: _selectedCategoryId,
              isExpanded: true,
              dropdownColor: Colors.grey.shade900,
              underline: const SizedBox(),
              hint: Text('Sélectionner une catégorie', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              items: _categories.map((cat) {
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(cat.slug), size: 20, color: Colors.white70),
                      const SizedBox(width: 12),
                      Text(cat.name, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
          ),
          const SizedBox(height: 24),

          // Age Rating
          _buildSectionTitle('Âge requis', Icons.child_care),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _ageRatings.map((age) {
              final isSelected = _selectedAgeRating == age;
              return ChoiceChip(
                label: Text(age),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedAgeRating = age);
                },
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.grey.shade800,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _getAgeRatingDescription(_selectedAgeRating),
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Tags
          _buildTextField(
            controller: _tagsCtrl,
            label: 'Tags (séparés par des virgules)',
            icon: Icons.tag,
            helperText: 'Ex: productivité, notes, todo',
          ),
          const SizedBox(height: 16),

          // Languages
          _buildTextField(
            controller: _languagesCtrl,
            label: 'Langues supportées (séparées par des virgules)',
            icon: Icons.language,
            helperText: 'Ex: Français, English, Español',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URLs Section
          _buildSectionTitle('Liens', Icons.link),
          const SizedBox(height: 12),
          
          _buildTextField(
            controller: _privacyUrlCtrl,
            label: 'Politique de confidentialité (URL)',
            icon: Icons.privacy_tip,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _supportUrlCtrl,
            label: 'Support (URL)',
            icon: Icons.support_agent,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _websiteUrlCtrl,
            label: 'Site web (URL)',
            icon: Icons.public,
          ),
          const SizedBox(height: 32),

          // App Info (Read Only)
          _buildSectionTitle('Informations', Icons.info_outline),
          const SizedBox(height: 12),
          _buildInfoRow('Bundle ID', _app?.id ?? ''),
          _buildInfoRow('Version actuelle', _app?.version ?? ''),
          _buildInfoRow('Téléchargements', '${_app?.downloadsCount ?? 0}'),
          _buildInfoRow('Note moyenne', '${_app?.averageRating.toStringAsFixed(1) ?? "-"} ★'),
          _buildInfoRow('Nombre d\'avis', '${_app?.ratingsCount ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.blue),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  String _getAgeRatingDescription(String rating) {
    switch (rating) {
      case '4+':
        return 'Convient à tous les âges, aucun contenu répréhensible';
      case '9+':
        return 'Peut contenir du contenu peu fréquent/modéré non approprié aux enfants';
      case '12+':
        return 'Peut contenir du contenu fréquent/intense non approprié aux moins de 12 ans';
      case '17+':
        return 'Réservé aux adultes, peut contenir du contenu mature';
      default:
        return '';
    }
  }

  IconData _getCategoryIcon(String slug) {
    const iconMap = {
      'games': Icons.games,
      'social': Icons.people,
      'productivity': Icons.task_alt,
      'entertainment': Icons.movie,
      'education': Icons.school,
      'utilities': Icons.build,
      'lifestyle': Icons.spa,
      'finance': Icons.account_balance,
      'health': Icons.favorite,
      'sports': Icons.sports,
      'travel': Icons.flight,
      'food': Icons.restaurant,
      'shopping': Icons.shopping_bag,
      'music': Icons.music_note,
      'photo': Icons.photo_camera,
      'weather': Icons.cloud,
      'news': Icons.article,
      'books': Icons.menu_book,
      'business': Icons.business_center,
      'developer': Icons.code,
      'navigation': Icons.navigation,
      'kids': Icons.child_friendly,
      'art': Icons.palette,
      'medical': Icons.medical_services,
      'reference': Icons.library_books,
    };
    return iconMap[slug] ?? Icons.apps;
  }
}
