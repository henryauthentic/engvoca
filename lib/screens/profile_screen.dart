import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../firebase/firebase_service.dart';
import '../models/user.dart' as app_user;
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../db/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firebaseService = FirebaseService();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  File? _selectedImage;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _nameController.text = firebaseUser.displayName ?? '';
      
      final userData = await _firebaseService.getUser(firebaseUser.uid);
      if (userData != null && mounted) {
        setState(() {
          _currentAvatarUrl = userData.avatar;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (choice != null) {
      final pickedFile = await picker.pickImage(
        source: choice,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    }
  }

  Future<String> _saveAvatarToAppDir(File pickedImage) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/avatars');
    if (!avatarDir.existsSync()) {
      avatarDir.createSync(recursive: true);
    }

    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedImage.path)}';
    final savedImage = await pickedImage.copy('${avatarDir.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        throw Exception('Không tìm thấy người dùng');
      }

      await firebaseUser.updateDisplayName(_nameController.text);
      await _authService.reloadUser();

      final currentUserData = await _firebaseService.getUser(firebaseUser.uid);
      String avatarUrl = currentUserData?.avatar ?? "assets/images/default_avatar.png";
      
      if (_selectedImage != null) {
        avatarUrl = await _saveAvatarToAppDir(_selectedImage!);
      }

      final updatedUser = app_user.User(
        id: firebaseUser.uid,
        email: firebaseUser.email!,
        displayName: _nameController.text,
        avatar: avatarUrl,
        createdAt: currentUserData?.createdAt ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        totalWords: currentUserData?.totalWords ?? 0,
        learnedWords: currentUserData?.learnedWords ?? 0,
      );

      await DatabaseHelper.instance.upsertUser(
        id: firebaseUser.uid,
        name: _nameController.text,
        email: firebaseUser.email!,
        avatarUrl: avatarUrl,
        level: 1,
        totalPoints: currentUserData?.totalWords ?? 0,
        wordsLearned: currentUserData?.learnedWords ?? 0,
      );
      
      await _firebaseService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thành công!'),
            backgroundColor: AppConstants.secondaryColor,
          ),
        );
        
        setState(() {
          _currentAvatarUrl = avatarUrl;
          _selectedImage = null;
          _isEditing = false;
        });

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Chỉnh sửa',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              Stack(
                children: [
                  Hero(
                    tag: 'profile_avatar',
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            context.primaryColor,
                            context.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _selectedImage != null
                          ? ClipOval(
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                              ),
                            )
                          : _currentAvatarUrl != null && _currentAvatarUrl!.startsWith('/')
                          ? ClipOval(
                              child: Image.file(
                                File(_currentAvatarUrl!),
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: const TextStyle(
                                        fontSize: 60,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.secondaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingLarge),

              // Name field
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: context.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tên hiển thị',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditing,
                        decoration: InputDecoration(
                          hintText: 'Nhập tên của bạn',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          ),
                          filled: true,
                          fillColor: _isEditing
                              ? context.surfaceColor
                              : context.subtleBackground,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên';
                          }
                          if (value.length < 2) {
                            return 'Tên phải có ít nhất 2 ký tự';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
              ),

              const SizedBox(height: AppConstants.paddingMedium),

              // Email field (readonly)
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            color: context.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.subtleBackground,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          border: Border.all(
                            color: context.dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.email ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Icon(
                              Icons.lock,
                              size: 16,
                              color: context.textTertiary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email không thể thay đổi',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
              ),

              const SizedBox(height: AppConstants.paddingLarge),

              // Save button
              if (_isEditing)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Lưu thay đổi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _nameController.text = user?.displayName ?? '';
                            _selectedImage = null;
                          });
                        },
                        child: const Text('Hủy'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}