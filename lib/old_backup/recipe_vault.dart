import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeVault extends StatefulWidget {
  const RecipeVault({super.key});

  @override
  State<RecipeVault> createState() => _RecipeVaultState();
}

class _RecipeVaultState extends State<RecipeVault> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  bool loading = true;
  bool isManager = false;

  String selectedCategory = 'All';

  List<Map<String, dynamic>> recipes = [];

  final List<String> categories = const [
    'All',
    'Coffee',
    'Refresher',
    'Chocolate',
    'Tea',
    'Matcha',
    'Non-Coffee',
    'Pastries',
    'Hot Meal',
    'Drink Base',
    'Sugar Syrup',
    'Chocolate Concentrate',
    'Tea Base',
  ];

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => loading = true);

    await Future.wait([
      checkUserRole(),
      loadRecipes(),
    ]);

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> checkUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role'] ?? '').toString().toUpperCase();

      if (!mounted) return;

      setState(() {
        isManager = role == 'MANAGER';
      });
    } catch (e) {
      debugPrint('Check user role error: $e');
      if (!mounted) return;
      setState(() => isManager = false);
    }
  }

  Future<void> loadRecipes() async {
    try {
      final data = await supabase
          .from('recipe')
          .select(
            'recipe_id, name, category, ingredients, instructions, image_url, created_by, created_at, updated_at',
          )
          .order('category', ascending: true)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        recipes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Load recipes error: $e');
      _showSnack('Failed to load recipes: $e');
    }
  }

  List<Map<String, dynamic>> get filteredRecipes {
    if (selectedCategory == 'All') {
      return recipes;
    }

    return recipes.where((recipe) {
      final category = (recipe['category'] ?? '').toString();
      return category == selectedCategory;
    }).toList();
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<String> _splitLines(dynamic value) {
    if (value == null) return [];

    return value
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _defaultImageByCategory(String category) {
    switch (category) {
      case 'Coffee':
        return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=900';
      case 'Refresher':
        return 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=900';
      case 'Chocolate':
        return 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=900';
      case 'Tea':
        return 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=900';
      case 'Matcha':
        return 'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?w=900';
      case 'Pastries':
        return 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=900';
      case 'Hot Meal':
        return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900';
      default:
        return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=900';
    }
  }

  Future<void> deleteRecipe(int recipeId) async {
    try {
      await supabase.from('recipe').delete().eq('recipe_id', recipeId);
      _showSnack('Recipe deleted successfully.');
      await loadRecipes();
    } catch (e) {
      _showSnack('Failed to delete recipe: $e');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> recipe) async {
    final recipeId = recipe['recipe_id'];

    if (recipeId == null) {
      _showSnack('Invalid recipe ID.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Recipe?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${recipe['name'] ?? 'this recipe'}"?',
            style: const TextStyle(color: mulberryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mulberryDark),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await deleteRecipe(recipeId as int);
    }
  }

  Future<void> _showRecipeForm({Map<String, dynamic>? recipe}) async {
    final isEditing = recipe != null;

    final nameCtl = TextEditingController(
      text: isEditing ? (recipe['name'] ?? '').toString() : '',
    );

    final ingredientsCtl = TextEditingController(
      text: isEditing ? (recipe['ingredients'] ?? '').toString() : '',
    );

    final instructionsCtl = TextEditingController(
      text: isEditing ? (recipe['instructions'] ?? '').toString() : '',
    );

    final imageUrlCtl = TextEditingController(
      text: isEditing ? (recipe['image_url'] ?? '').toString() : '',
    );

    String selectedFormCategory = isEditing
        ? (recipe['category'] ?? 'Coffee').toString()
        : 'Coffee';

    if (!categories.contains(selectedFormCategory) ||
        selectedFormCategory == 'All') {
      selectedFormCategory = 'Coffee';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cream,
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                isEditing ? 'Edit Recipe' : 'Add Recipe',
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _dialogInput(
                        controller: nameCtl,
                        label: 'Recipe Name',
                        icon: Icons.restaurant_menu,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedFormCategory,
                        decoration: _inputDecoration(
                          label: 'Category',
                          icon: Icons.category_outlined,
                        ),
                        items: categories
                            .where((category) => category != 'All')
                            .map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedFormCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogInput(
                        controller: ingredientsCtl,
                        label: 'Ingredients',
                        icon: Icons.shopping_basket_outlined,
                        maxLines: 6,
                        hint:
                            'Example:\n250ml fresh milk\n2 pumps sugar syrup\n50ml espresso shot\nIce cubes',
                      ),
                      const SizedBox(height: 12),
                      _dialogInput(
                        controller: instructionsCtl,
                        label: 'Instructions',
                        icon: Icons.format_list_numbered,
                        maxLines: 8,
                        hint:
                            'Example:\nFill cup with ice cubes.\nPour 250ml milk into cup.\nAdd 2 pumps sugar syrup.\nExtract 50ml espresso shot and pour over milk.',
                      ),
                      const SizedBox(height: 12),
                      _dialogInput(
                        controller: imageUrlCtl,
                        label: 'Image URL optional',
                        icon: Icons.image_outlined,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tip: Write one ingredient or one instruction per line. The system will automatically show it as 1, 2, 3, 4.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: mulberryDark),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    final ingredients = ingredientsCtl.text.trim();
                    final instructions = instructionsCtl.text.trim();
                    final imageUrl = imageUrlCtl.text.trim();

                    if (name.isEmpty) {
                      _showSnack('Recipe name is required.');
                      return;
                    }

                    if (instructions.isEmpty) {
                      _showSnack('Instructions are required.');
                      return;
                    }

                    await _saveRecipe(
                      recipeId: isEditing ? recipe['recipe_id'] : null,
                      name: name,
                      category: selectedFormCategory,
                      ingredients: ingredients,
                      instructions: instructions,
                      imageUrl: imageUrl,
                    );

                    if (mounted) Navigator.pop(dialogContext);
                  },
                  icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(isEditing ? 'Save' : 'Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mulberry,
                    foregroundColor: cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtl.dispose();
    ingredientsCtl.dispose();
    instructionsCtl.dispose();
    imageUrlCtl.dispose();
  }

  Future<void> _saveRecipe({
    required dynamic recipeId,
    required String name,
    required String category,
    required String ingredients,
    required String instructions,
    required String imageUrl,
  }) async {
    final user = supabase.auth.currentUser;

    try {
      final data = {
        'name': name,
        'category': category,
        'ingredients': ingredients,
        'instructions': instructions,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
      };

      if (recipeId == null) {
        await supabase.from('recipe').insert({
          ...data,
          'created_by': user?.id,
        });

        _showSnack('Recipe added successfully.');
      } else {
        await supabase
            .from('recipe')
            .update(data)
            .eq('recipe_id', recipeId);

        _showSnack('Recipe updated successfully.');
      }

      await loadRecipes();
    } catch (e) {
      _showSnack('Failed to save recipe: $e');
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: mulberry),
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      alignLabelWithHint: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: creamDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: mulberry),
      ),
    );
  }

  Widget _dialogInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        hint: hint,
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cream,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    size: 30,
                    color: mulberry,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recipe Vault',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cream,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Menu preparation guide',
                  style: TextStyle(
                    fontSize: 13,
                    color: cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loadInitialData,
            icon: const Icon(Icons.refresh, color: cream),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _categorySelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? mulberry : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? mulberry : creamDark,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: mulberryDark.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: selected ? cream : mulberryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recipeCard(Map<String, dynamic> recipe) {
    final name = (recipe['name'] ?? 'No Name').toString();
    final category = (recipe['category'] ?? 'Uncategorized').toString();
    final ingredients = _splitLines(recipe['ingredients']);
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    final displayImage =
        imageUrl.isNotEmpty ? imageUrl : _defaultImageByCategory(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailPage(
                recipe: recipe,
                isManager: isManager,
                onEdit: () {
                  Navigator.pop(context);
                  _showRecipeForm(recipe: recipe);
                },
                onDelete: () {
                  Navigator.pop(context);
                  _confirmDelete(recipe);
                },
              ),
            ),
          );

          await loadRecipes();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                displayImage,
                height: 155,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 155,
                  width: double.infinity,
                  color: creamDark,
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: mulberry,
                    size: 42,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: mulberry.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: mulberry,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: mulberryDark,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ingredients.isEmpty
                              ? 'Tap to view preparation instructions'
                              : ingredients.take(3).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isManager)
                    PopupMenuButton<String>(
                      color: Colors.white,
                      icon: const Icon(Icons.more_vert, color: mulberry),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showRecipeForm(recipe: recipe);
                        } else if (value == 'delete') {
                          _confirmDelete(recipe);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: mulberry),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: mulberry,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          const Text(
            'No recipes found',
            style: TextStyle(
              color: mulberryDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isManager
                ? 'Tap the + button to add a new recipe.'
                : 'Recipes added by manager will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredRecipes;

    return Scaffold(
      backgroundColor: cream,
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showRecipeForm(),
              backgroundColor: mulberry,
              foregroundColor: cream,
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: mulberry,
                onRefresh: loadInitialData,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: mulberry),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Menu Recipes',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: mulberryDark,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isManager
                                      ? mulberry.withOpacity(0.12)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isManager ? 'Manager Mode' : 'View Only',
                                  style: TextStyle(
                                    color: isManager
                                        ? mulberry
                                        : Colors.grey.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Browse preparation guides by category.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _categorySelector(),
                          const SizedBox(height: 18),
                          if (list.isEmpty)
                            _emptyState()
                          else
                            ...list.map(_recipeCard),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final bool isManager;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.isManager,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  List<String> _splitLines(dynamic value) {
    if (value == null) return [];

    return value
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _defaultImageByCategory(String category) {
    switch (category) {
      case 'Coffee':
        return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=900';
      case 'Refresher':
        return 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=900';
      case 'Chocolate':
        return 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=900';
      case 'Tea':
        return 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=900';
      case 'Matcha':
        return 'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?w=900';
      case 'Pastries':
        return 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=900';
      case 'Hot Meal':
        return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900';
      default:
        return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=900';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (recipe['name'] ?? 'Recipe').toString();
    final category = (recipe['category'] ?? 'Uncategorized').toString();
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    final displayImage =
        imageUrl.isNotEmpty ? imageUrl : _defaultImageByCategory(category);

    final ingredients = _splitLines(recipe['ingredients']);
    final instructions = _splitLines(recipe['instructions']);

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            _detailHeader(context, name, category),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      displayImage,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        color: creamDark,
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: mulberry,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Ingredients',
                    icon: Icons.shopping_basket_outlined,
                    emptyText: 'No ingredients added yet.',
                    lines: ingredients,
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Preparation Instructions',
                    icon: Icons.format_list_numbered,
                    emptyText: 'No instructions added yet.',
                    lines: instructions,
                  ),
                  if (isManager) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mulberry,
                              foregroundColor: cream,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailHeader(BuildContext context, String name, String category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: cream),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cream,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isManager)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: cream),
              tooltip: 'Edit Recipe',
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required String emptyText,
    required List<String> lines,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mulberry),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            )
          else
            ...lines.asMap().entries.map((entry) {
              return _numberedText(
                number: entry.key + 1,
                text: entry.value,
              );
            }),
        ],
      ),
    );
  }

  Widget _numberedText({
    required int number,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: mulberry,
              shape: BoxShape.circle,
            ),
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: cream,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: mulberryDark,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}