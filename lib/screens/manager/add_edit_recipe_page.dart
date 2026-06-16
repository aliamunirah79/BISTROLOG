import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditRecipePage extends StatefulWidget {
  final Map<String, dynamic>? recipe;

  const AddEditRecipePage({
    super.key,
    this.recipe,
  });

  @override
  State<AddEditRecipePage> createState() => _AddEditRecipePageState();
}

class _AddEditRecipePageState extends State<AddEditRecipePage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final descriptionController = TextEditingController();
  final ingredientsController = TextEditingController();
  final stepsController = TextEditingController();

  bool isSaving = false;
  bool isUploadingImage = false;

  String? imageUrl;

  bool get isEditMode => widget.recipe != null;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      final recipe = widget.recipe!;

      nameController.text = recipe['name'] ?? '';
      categoryController.text = recipe['category'] ?? '';
      descriptionController.text = recipe['description'] ?? '';
      ingredientsController.text = recipe['ingredients'] ?? '';
      stepsController.text = recipe['steps'] ?? '';
      imageUrl = recipe['image_url'];
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    ingredientsController.dispose();
    stepsController.dispose();
    super.dispose();
  }

  Future<CroppedFile?> cropImage(String imagePath) async {
    if (kIsWeb) {
      return null;
    }

    return ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Recipe Image',
          toolbarColor: mulberry,
          toolbarWidgetColor: cream,
          activeControlsWidgetColor: mulberry,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Recipe Image',
        ),
      ],
    );
  }

  Future<String?> uploadRecipeImage(File imageFile) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in.');
    }

    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final filePath = 'recipes/$fileName';

    await supabase.storage.from('recipe_images').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return supabase.storage.from('recipe_images').getPublicUrl(filePath);
  }

  Future<void> pickImage() async {
    try {
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (pickedImage == null) {
        return;
      }

      File finalFile = File(pickedImage.path);

      if (!kIsWeb) {
        final cropped = await cropImage(pickedImage.path);

        if (cropped != null) {
          finalFile = File(cropped.path);
        }
      }

      setState(() {
        isUploadingImage = true;
      });

      final uploadedUrl = await uploadRecipeImage(finalFile);

      if (!mounted) return;

      setState(() {
        imageUrl = uploadedUrl;
        isUploadingImage = false;
      });

      showMessage('Recipe image uploaded.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUploadingImage = false;
      });

      showMessage('Failed to upload image: $e', isError: true);
    }
  }

  Future<void> saveRecipe() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final data = {
        'name': nameController.text.trim(),
        'category': categoryController.text.trim(),
        'description': descriptionController.text.trim(),
        'ingredients': ingredientsController.text.trim(),
        'steps': stepsController.text.trim(),
        'image_url': imageUrl,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isEditMode) {
        await supabase
            .from('recipes')
            .update(data)
            .eq('recipe_id', widget.recipe!['recipe_id']);

        showMessage('Recipe updated successfully.');
      } else {
        data['created_by'] = user.id;

        await supabase.from('recipes').insert(data);

        showMessage('Recipe added successfully.');
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      showMessage('Failed to save recipe: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            mulberryDark,
            mulberry,
            mulberryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: cream.withOpacity(0.18),
            child: Icon(
              isEditMode ? Icons.edit : Icons.add,
              color: cream,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Edit Recipe' : 'Add New Recipe',
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isEditMode
                      ? 'Update recipe details and image.'
                      : 'Create a new cafe recipe record.',
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildImageSection() {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return buildImagePlaceholder();
                },
              ),
            )
          else
            buildImagePlaceholder(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isUploadingImage ? null : pickImage,
              icon: isUploadingImage
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: mulberry,
                      ),
                    )
                  : const Icon(Icons.image),
              label: Text(
                isUploadingImage
                    ? 'Uploading...'
                    : hasImage
                        ? 'Change Image'
                        : 'Upload Recipe Image',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: mulberry,
                side: const BorderSide(color: mulberry),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (hasImage)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  imageUrl = null;
                });
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove Image'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildImagePlaceholder() {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: creamDark.withOpacity(0.85),
        ),
      ),
      child: const Icon(
        Icons.restaurant_menu,
        size: 70,
        color: mulberry,
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: mulberryDark,
          fontWeight: FontWeight.w500,
        ),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: mulberry),
          prefixIcon: maxLines == 1
              ? Icon(
                  icon,
                  color: mulberry,
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 70),
                  child: Icon(
                    icon,
                    color: mulberry,
                  ),
                ),
          filled: true,
          fillColor: softWhite,
          alignLabelWithHint: maxLines > 1,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: creamDark.withOpacity(0.85),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: mulberry,
              width: 1.8,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.3,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: cream,
            fontFamily: 'Georgia',
          ),
        ),
        backgroundColor: isError ? mulberryDark : mulberry,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Recipe' : 'Add Recipe',
          style: const TextStyle(
            color: cream,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: mulberry,
        foregroundColor: cream,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            buildHeader(),
            const SizedBox(height: 18),
            buildImageSection(),
            const SizedBox(height: 18),
            buildTextField(
              controller: nameController,
              label: 'Recipe Name',
              icon: Icons.restaurant_menu,
            ),
            buildTextField(
              controller: categoryController,
              label: 'Category',
              icon: Icons.category,
            ),
            buildTextField(
              controller: descriptionController,
              label: 'Description',
              icon: Icons.info_outline,
              maxLines: 3,
              requiredField: false,
            ),
            buildTextField(
              controller: ingredientsController,
              label: 'Ingredients',
              icon: Icons.format_list_bulleted,
              maxLines: 5,
            ),
            buildTextField(
              controller: stepsController,
              label: 'Steps',
              icon: Icons.list_alt,
              maxLines: 6,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveRecipe,
                icon: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cream,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : isEditMode
                          ? 'Update Recipe'
                          : 'Save Recipe',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  disabledBackgroundColor: mulberry.withOpacity(0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}