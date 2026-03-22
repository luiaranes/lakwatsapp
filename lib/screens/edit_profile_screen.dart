import 'package:flutter/material.dart';
import 'package:larga/models/user_profile.dart';
import 'package:larga/services/profile_service.dart';
import 'package:larga/utils/snackbar_utils.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _homeCityController;
  late final TextEditingController _homeCountryController;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.profile.displayName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _homeCityController = TextEditingController(text: widget.profile.homeCity ?? '');
    _homeCountryController = TextEditingController(text: widget.profile.homeCountry ?? '');

    _displayNameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _homeCityController.addListener(_onFieldChanged);
    _homeCountryController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _homeCityController.dispose();
    _homeCountryController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final hasChanges = _displayNameController.text != (widget.profile.displayName ?? '') ||
        _bioController.text != (widget.profile.bio ?? '') ||
        _homeCityController.text != (widget.profile.homeCity ?? '') ||
        _homeCountryController.text != (widget.profile.homeCountry ?? '');

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if user is clearing any fields that had existing data
    final fieldsBeingCleared = <String>[];
    
    final originalBio = widget.profile.bio ?? '';
    final originalCity = widget.profile.homeCity ?? '';
    final originalCountry = widget.profile.homeCountry ?? '';
    
    final newBio = _bioController.text.trim();
    final newCity = _homeCityController.text.trim();
    final newCountry = _homeCountryController.text.trim();
    
    if (originalBio.isNotEmpty && newBio.isEmpty) {
      fieldsBeingCleared.add('Bio');
    }
    if (originalCity.isNotEmpty && newCity.isEmpty) {
      fieldsBeingCleared.add('Home City');
    }
    if (originalCountry.isNotEmpty && newCountry.isEmpty) {
      fieldsBeingCleared.add('Home Country');
    }

    // Confirm if clearing fields
    if (fieldsBeingCleared.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Fields?'),
          content: Text(
            'You are about to clear the following fields:\n\n'
            '${fieldsBeingCleared.map((f) => '• $f').join('\n')}\n\n'
            'Are you sure you want to remove this information?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      // Only send fields that have actually changed
      final displayNameChanged = _displayNameController.text.trim() != (widget.profile.displayName ?? '');
      final bioChanged = newBio != originalBio;
      final cityChanged = newCity != originalCity;
      final countryChanged = newCountry != originalCountry;

      await _profileService.updateProfile(
        displayName: displayNameChanged ? _displayNameController.text.trim() : null,
        bio: bioChanged && newBio.isNotEmpty ? newBio : null,
        homeCity: cityChanged && newCity.isNotEmpty ? newCity : null,
        homeCountry: countryChanged && newCountry.isNotEmpty ? newCountry : null,
        clearBio: bioChanged && newBio.isEmpty && originalBio.isNotEmpty,
        clearHomeCity: cityChanged && newCity.isEmpty && originalCity.isNotEmpty,
        clearHomeCountry: countryChanged && newCountry.isEmpty && originalCountry.isNotEmpty,
      );

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Profile updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to update profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = widget.profile.avatarUrl;
    final displayName = _displayNameController.text.isNotEmpty 
        ? _displayNameController.text 
        : 'Traveler';

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _hasChanges ? theme.colorScheme.primary : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: avatarUrl == null
                                  ? Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => SnackBarUtils.showInfo(context, 'Avatar upload coming soon!'),
                        child: const Text('Change Photo'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Form fields
                _buildSectionHeader('Basic Info'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'How should we call you?',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    prefixIcon: const Icon(Icons.edit_note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('Location'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _homeCityController,
                  decoration: InputDecoration(
                    labelText: 'Home City',
                    hintText: 'e.g., Manila',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _homeCountryController,
                  decoration: InputDecoration(
                    labelText: 'Home Country',
                    hintText: 'e.g., Philippines',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }
}
