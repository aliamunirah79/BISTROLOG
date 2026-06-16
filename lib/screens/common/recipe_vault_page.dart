import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeVaultPage extends StatefulWidget {
  final bool showAppBar;

  const RecipeVaultPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<RecipeVaultPage> createState() => _RecipeVaultPageState();
}

class _RecipeVaultPageState extends State<RecipeVaultPage> {
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final ScrollController contentScrollController = ScrollController();

  bool isLoading = true;
  bool showFloatingSearch = false;

  List<Map<String, dynamic>> recipes = [];

  String selectedCategory = 'All';
  String searchQuery = '';

  final Map<String, GlobalKey> categoryKeys = {};

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadRecipes();
    contentScrollController.addListener(handleScroll);
    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    contentScrollController.removeListener(handleScroll);
    contentScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void handleScroll() {
    final shouldShowSearch = contentScrollController.hasClients &&
        contentScrollController.offset > 78;

    if (shouldShowSearch != showFloatingSearch) {
      setState(() {
        showFloatingSearch = shouldShowSearch;
      });
    }

    updateCategoryFromScroll();
  }

  void updateCategoryFromScroll() {
    if (searchQuery.trim().isNotEmpty) {
      return;
    }

    final categories = getRecipeCategories().where((c) => c != 'All').toList();

    if (categories.isEmpty) {
      return;
    }

    String? activeCategory;
    double closestTop = double.negativeInfinity;

    for (final category in categories) {
      final key = categoryKeys[category];
      final context = key?.currentContext;

      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final position = box.localToGlobal(Offset.zero).dy;

      if (position <= 210 && position > closestTop) {
        closestTop = position;
        activeCategory = category;
      }
    }

    if (activeCategory != null && activeCategory != selectedCategory) {
      setState(() {
        selectedCategory = activeCategory!;
      });
    }
  }

  Future<void> loadRecipes() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('recipes')
          .select()
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('name', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        recipes = data;

        final categories = getRecipeCategoriesFrom(data);
        if (!categories.contains(selectedCategory)) {
          selectedCategory = 'All';
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load recipes: $e', isError: true);
    }
  }

  String getRecipeName(Map<String, dynamic> recipe) {
    return (recipe['name'] ?? 'Untitled Recipe').toString();
  }

  String getRecipeCategory(Map<String, dynamic> recipe) {
    final category = (recipe['category'] ?? '').toString().trim();

    if (category.isEmpty) {
      return 'Uncategorized';
    }

    return category;
  }

  String getRecipeDescription(Map<String, dynamic> recipe) {
    return (recipe['description'] ?? 'No description.').toString();
  }

  List<String> getRecipeCategoriesFrom(List<Map<String, dynamic>> data) {
    final categories = data
        .map(getRecipeCategory)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    categories.sort();

    return ['All', ...categories];
  }

  List<String> getRecipeCategories() {
    return getRecipeCategoriesFrom(recipes);
  }

  List<Map<String, dynamic>> getSearchFilteredRecipes() {
    if (searchQuery.trim().isEmpty) {
      return recipes;
    }

    final keyword = searchQuery.toLowerCase();

    return recipes.where((recipe) {
      final name = getRecipeName(recipe).toLowerCase();
      final category = getRecipeCategory(recipe).toLowerCase();
      final description = getRecipeDescription(recipe).toLowerCase();
      final ingredients = (recipe['ingredients'] ?? '').toString().toLowerCase();

      return name.contains(keyword) ||
          category.contains(keyword) ||
          description.contains(keyword) ||
          ingredients.contains(keyword);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> getGroupedRecipes() {
    final sourceRecipes = getSearchFilteredRecipes();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final recipe in sourceRecipes) {
      final category = getRecipeCategory(recipe);
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(recipe);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => getRecipeName(a).compareTo(getRecipeName(b)));
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }

  void jumpToCategory(String category) {
    setState(() {
      selectedCategory = category;
    });

    if (category == 'All') {
      if (contentScrollController.hasClients) {
        contentScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final key = categoryKeys[category];
    final context = key?.currentContext;

    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.02,
      );
    }
  }

  void clearSearch() {
    searchController.clear();
    setState(() {
      searchQuery = '';
    });
  }

  void openSearchPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SafeArea(
            child: TextField(
              autofocus: true,
              controller: searchController,
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search recipe...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: mulberry,
                ),
                suffixIcon: searchController.text.trim().isNotEmpty
                    ? IconButton(
                        onPressed: clearSearch,
                        icon: const Icon(
                          Icons.close,
                          color: mulberry,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: softWhite,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: creamDark.withOpacity(0.85),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: mulberry,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData getCategoryIcon(String category) {
    final lower = category.toLowerCase();

    if (category == 'All') return Icons.grid_view;
    if (lower.contains('coffee')) return Icons.local_cafe;
    if (lower.contains('chocolate')) return Icons.coffee;
    if (lower.contains('matcha')) return Icons.spa;
    if (lower.contains('tea')) return Icons.emoji_food_beverage;
    if (lower.contains('refresher')) return Icons.local_drink;
    if (lower.contains('frappe')) return Icons.blender;
    if (lower.contains('pastry')) return Icons.bakery_dining;
    if (lower.contains('cake')) return Icons.cake;
    if (lower.contains('dessert')) return Icons.icecream;
    if (lower.contains('hot')) return Icons.lunch_dining;

    return Icons.restaurant_menu;
  }

  void showRecipeDetail(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: mulberry.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (recipe['image_url'] != null &&
                      recipe['image_url'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        recipe['image_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return buildImagePlaceholder();
                        },
                      ),
                    )
                  else
                    buildImagePlaceholder(),
                  const SizedBox(height: 18),
                  Text(
                    getRecipeName(recipe),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: mulberryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mulberry.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        getRecipeCategory(recipe),
                        style: const TextStyle(
                          color: mulberry,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildDetailSection(
                    title: 'Description',
                    content: getRecipeDescription(recipe),
                    icon: Icons.info_outline,
                  ),
                  buildDetailSection(
                    title: 'Ingredients',
                    content: recipe['ingredients'] ?? 'No ingredients.',
                    icon: Icons.format_list_bulleted,
                  ),
                  buildDetailSection(
                    title: 'Steps',
                    content: recipe['steps'] ?? 'No steps.',
                    icon: Icons.list_alt,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildImagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: creamDark,
        ),
      ),
      child: const Icon(
        Icons.restaurant_menu,
        size: 70,
        color: mulberry,
      ),
    );
  }

  Widget buildDetailSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: mulberry.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: mulberry,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: mulberryDark,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              height: 1.45,
              color: Colors.grey.shade800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSmallPlaceholder() {
    return Container(
      height: 82,
      width: 82,
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.local_cafe,
        color: mulberry,
        size: 34,
      ),
    );
  }

  Widget buildRecipeCard(Map<String, dynamic> recipe) {
    final imageUrl = recipe['image_url'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 13),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.70),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showRecipeDetail(recipe),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return buildSmallPlaceholder();
                        },
                      )
                    : buildSmallPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getRecipeName(recipe),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: mulberryDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      getRecipeCategory(recipe),
                      style: const TextStyle(
                        color: mulberry,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      getRecipeDescription(recipe),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: mulberry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopIntroCard() {
    if (!widget.showAppBar) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cafe Recipe Guide',
            style: TextStyle(
              color: cream,
              fontFamily: 'Georgia',
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'View standard recipe, ingredients and preparation steps.',
            style: TextStyle(
              color: creamDark,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchField() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: showFloatingSearch
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('search_box'),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: searchController,
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search recipe...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: mulberry,
                  ),
                  suffixIcon: searchController.text.trim().isNotEmpty
                      ? IconButton(
                          onPressed: clearSearch,
                          icon: const Icon(
                            Icons.close,
                            color: mulberry,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: softWhite,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: creamDark.withOpacity(0.85),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: mulberry,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget buildCategorySidebar() {
    final categories = getRecipeCategories();

    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: softWhite,
        border: Border(
          right: BorderSide(
            color: creamDark.withOpacity(0.75),
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 90),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => jumpToCategory(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? mulberry.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: selected ? mulberry : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    getCategoryIcon(category),
                    color: selected ? mulberry : Colors.grey.shade600,
                    size: 25,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? mulberry : Colors.grey.shade700,
                      fontSize: 10.8,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildCategoryHeader(String category, List<Map<String, dynamic>> items) {
    categoryKeys.putIfAbsent(category, () => GlobalKey());

    return Container(
      key: categoryKeys[category],
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                color: mulberryDark,
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: mulberry.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${items.length} item',
              style: const TextStyle(
                color: mulberry,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecipeBody() {
    final groupedRecipes = getGroupedRecipes();
    final searchedRecipes = getSearchFilteredRecipes();

    return Column(
      children: [
        buildTopIntroCard(),
        buildSearchField(),
        Expanded(
          child: Row(
            children: [
              buildCategorySidebar(),
              Expanded(
                child: searchedRecipes.isEmpty
                    ? Center(
                        child: Text(
                          'No recipe found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView(
                        controller: contentScrollController,
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          if (searchQuery.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: Text(
                                '${searchedRecipes.length} result(s) found',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ...groupedRecipes.entries.expand((entry) {
                            final category = entry.key;
                            final items = entry.value;

                            return [
                              buildCategoryHeader(category, items),
                              ...items.map(buildRecipeCard),
                            ];
                          }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Recipe Vault',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cream,
                ),
              ),
              centerTitle: true,
              backgroundColor: mulberry,
              foregroundColor: cream,
              elevation: 0,
            )
          : null,
      floatingActionButton: showFloatingSearch
          ? FloatingActionButton(
              mini: true,
              backgroundColor: softWhite,
              foregroundColor: mulberry,
              elevation: 5,
              onPressed: openSearchPanel,
              child: const Icon(Icons.search),
            )
          : null,
      body: RefreshIndicator(
        color: mulberry,
        onRefresh: loadRecipes,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: mulberry,
                ),
              )
            : buildRecipeBody(),
      ),
    );
  }
}