import 'package:flutter/material.dart';import 'package:flutter_localization/flutter_localization.dart';

import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/expense_service.dart';
import 'package:pos/data/models/expense_model.dart';
import 'package:pos/data/models/expense_category_model.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';
import 'package:pos/core/widgets/skeleton.dart';
import 'package:pos/l10n/app_locale.dart';
class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<Expenses> createState() => _ExpensesState();
}

class _ExpensesState extends State<Expenses> {
  int selectedTab = 0;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<ExpenseCategoryModel> categories = [];
  List<ExpenseModel> expenses = [];
  List<ExpenseModel> filteredExpenses = [];
  List<ExpenseCategoryModel> filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });
      await Future.wait([fetchCategories(), fetchExpenses()]);
    } catch (e) {
      debugPrint('Expenses load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _filterExpenses(String query) {
    final q = query.toLowerCase();
    filteredExpenses = expenses.where((exp) {
      final categoryName = _getCategoryName(exp).toLowerCase();
      return categoryName.contains(q) || (exp.note?.toLowerCase().contains(q) ?? false);
    }).toList();
    setState(() {});
  }

  void _filterCategories(String query) {
    final q = query.toLowerCase();
    filteredCategories = categories.where((cat) {
      return cat.name.toLowerCase().contains(q);
    }).toList();
    setState(() {});
  }

  String _getCategoryName(ExpenseModel exp) {
    if (exp.categoryName.isNotEmpty) return exp.categoryName;
    final cat = categories.firstWhere(
      (c) => c.id == exp.expenseCategoryId,
      orElse: () => ExpenseCategoryModel(name: AppLocale.unknown.getString(context), adminId: ''),
    );
    return cat.name;
  }

  Future<void> fetchExpenses({DateTime? date}) async {
    final target = date ?? selectedDate;
    final startDate = DateTime(target.year, target.month, 1);
    final endDate = DateTime(target.year, target.month + 1, 0, 23, 59, 59);
    try {
      expenses = await ExpenseService().getExpenses(
        startDate: startDate,
        endDate: endDate,
      );
      filteredExpenses = List.from(expenses);
    } catch (e) {
      debugPrint('fetchExpenses error: $e');
    }
  }

  Future<void> fetchCategories() async {
    try {
      categories = await ExpenseService().getExpenseCategories();
      filteredCategories = List.from(categories);
    } catch (e) {
      debugPrint('fetchCategories error: $e');
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ExpenseService().deleteExpense(id);
      await fetchExpenses();
      setState(() {});
    } catch (e) {
      SnackBarUtils.showError(context, '${AppLocale.error.getString(context)}: $e');
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await ExpenseService().deleteExpenseCategory(id);
      await fetchCategories();
      setState(() {});
    } catch (e) {
      SnackBarUtils.showError(context, '${AppLocale.error.getString(context)}: $e');
    }
  }

  void _showAddCategoryDialog({ExpenseCategoryModel? category}) {
    if (category != null) {
      _categoryController.text = category.name;
    } else {
      _categoryController.clear();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool innerLoading = false;

        return StatefulBuilder(
          builder: (context, setStateInner) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: category == null ? AppLocale.addCategory.getString(context) : AppLocale.editCategory.getString(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _categoryController,
                        enabled: !innerLoading,
                        decoration: InputDecoration(
                          hintText: AppLocale.enterCategoryName.getString(context),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: innerLoading
                                ? null
                                : () {
                                    _categoryController.clear();
                                    Navigator.pop(context);
                                  },
                            child: MyText(text: AppLocale.cancel.getString(context)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbar1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: innerLoading
                                ? null
                                : () async {
                                    final categoryName = _categoryController.text.trim();
                                    if (categoryName.isEmpty) return;
                                    setStateInner(() => innerLoading = true);
                                    try {
                                      if (category == null) {
                                        await ExpenseService().createExpenseCategory(categoryName);
                                      } else {
                                        await ExpenseService().updateExpenseCategory(category.id!, categoryName);
                                      }
                                      await fetchCategories();
                                      setState(() {});
                                      _categoryController.clear();
                                      Navigator.pop(context);
                                    } catch (e) {
                                      setStateInner(() => innerLoading = false);
                                      SnackBarUtils.showError(context, '${AppLocale.error.getString(context)}: $e');
                                    }
                                  },
                            child: innerLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : MyText(
                                    text: category == null ? AppLocale.add.getString(context) : AppLocale.update.getString(context),
                                    color: Colors.white,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xffF6F8FA),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: MyText(
            text: AppLocale.expenses.getString(context),
            fontWeight: FontWeight.w600,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                  await fetchExpenses(date: date);
                  setState(() {});
                }
              },
            ),
          ],
        ),
        body: isLoading
            ? _buildSkeletonList()
            : Consumer<SubscriptionProvider>(
                builder: (context, subProvider, _) {
                  final hasView = subProvider.hasPermission("Expenses", checkView: true);
                  if (!hasView) {
                    return const AccessDeniedWidget(feature: "Expense");
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              _tabButton(AppLocale.expenses.getString(context), 0),
                              _tabButton(AppLocale.categories.getString(context), 1),
                            ],
                          ),
                        ),
                      ),
                      if (selectedTab == 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterExpenses,
                            decoration: InputDecoration(
                              hintText: AppLocale.searchExpenses.getString(context),
                              prefixIcon: const Icon(Icons.search, color: appbar1),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: expenses.isEmpty
                              ? Center(child: MyText(text: AppLocale.noExpenses.getString(context)))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredExpenses.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final exp = filteredExpenses[i];
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 5),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 25,
                                            backgroundColor: appbar1.withOpacity(.15),
                                            child: MyText(
                                              text: _getCategoryName(exp).isNotEmpty
                                                  ? _getCategoryName(exp)[0].toUpperCase()
                                                  : 'E',
                                              color: appbar1,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                MyText(
                                                  text: _getCategoryName(exp),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                const SizedBox(height: 4),
                                                MyText(
                                                  text: "${exp.date.day}/${exp.date.month}/${exp.date.year}",
                                                  color: Colors.grey,
                                                ),
                                                if (exp.note != null && exp.note!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  MyText(
                                                    text: exp.note!,
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              MyText(
                                                text: PriceUtils.formatPrice(exp.amount),
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: appbar1,
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (subProvider.hasPermission("Expenses", checkEdit: true))
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                      onPressed: () async {
                                                        final result = await Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => AddExpense(
                                                              
                                                              categories: categories,
                                                              expense: exp,
                                                            ),
                                                          ),
                                                        );
                                                        if (result == true) {
                                                          await fetchExpenses();
                                                          setState(() {});
                                                        }
                                                      },
                                                    ),
                                                  if (subProvider.hasPermission("Expenses", checkDelete: true))
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                      onPressed: () => _deleteExpense(exp.id!),
                                                    ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (subProvider.hasPermission("Expenses", checkCreate: true))
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: appbar1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddExpense(
                                          categories: categories,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      await fetchExpenses();
                                      setState(() {});
                                    }
                                  },
                                  child: MyText(
                                    text: AppLocale.addExpense.getString(context),
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (selectedTab == 1) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            onChanged: _filterCategories,
                            decoration: InputDecoration(
                              hintText: AppLocale.searchCategoryName.getString(context),
                              prefixIcon: const Icon(Icons.search, color: appbar1),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: categories.isEmpty
                              ? Center(child: MyText(text: AppLocale.noCategories.getString(context)))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredCategories.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final cat = filteredCategories[i];
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 5),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 25,
                                            backgroundColor: appbar1.withOpacity(.15),
                                            child: MyText(
                                              text: cat.name.isNotEmpty ? cat.name[0].toUpperCase() : 'C',
                                              color: appbar1,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: MyText(
                                              text: cat.name,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (subProvider.hasPermission("Expenses", checkEdit: true))
                                                IconButton(
                                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                  onPressed: () => _showAddCategoryDialog(category: cat),
                                                ),
                                              if (subProvider.hasPermission("Expenses", checkDelete: true))
                                                IconButton(
                                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                  onPressed: () => _deleteCategory(cat.id!),
                                                ),
                                            ],
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (subProvider.hasPermission("Expenses", checkCreate: true))
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: appbar1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => _showAddCategoryDialog(),
                                  child: MyText(
                                    text: AppLocale.addCategory.getString(context),
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ));
  }

  Widget _tabButton(String text, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? appbar1 : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: MyText(
            text: text,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: [
        // Tab Skeleton
        const Padding(
          padding: EdgeInsets.all(16),
          child: Skeleton(height: 45, borderRadius: 25, width: double.infinity),
        ),
        // Search Skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Skeleton(height: 55, borderRadius: 14, width: double.infinity),
        ),
        const SizedBox(height: 12),
        // List Skeleton
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
              ),
              child: const Row(
                children: [
                  Skeleton(height: 50, width: 50, borderRadius: 25),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 16, width: 120),
                        SizedBox(height: 8),
                        Skeleton(height: 12, width: 80),
                      ],
                    ),
                  ),
                  Skeleton(height: 20, width: 60),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AddExpense extends StatefulWidget {
  final List<ExpenseCategoryModel> categories;
  final ExpenseModel? expense;
  const AddExpense({super.key, required this.categories, this.expense});

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  ExpenseCategoryModel? selectedCategory;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      amountController.text = widget.expense!.amount.toString();
      noteController.text = widget.expense!.note ?? '';
      selectedDate = widget.expense!.date;
      selectedCategory = widget.categories.firstWhere(
        (c) => c.id == widget.expense!.expenseCategoryId,
        orElse: () => widget.categories.isNotEmpty
            ? widget.categories.first
            : widget.categories.firstWhere((element) => false,
                orElse: () => ExpenseCategoryModel(name: AppLocale.unknown.getString(context), adminId: '', id: 'unknown')),
      );
    } else {
      if (widget.categories.isNotEmpty) {
        selectedCategory = widget.categories.first;
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  void _selectCategory() {
    if (widget.categories.isEmpty) {
      SnackBarUtils.showWarning(context, AppLocale.pleaseCreateACategoryFirst.getString(context));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ListView(
        children: widget.categories.map((cat) {
          return ListTile(
            title: MyText(text: cat.name),
            trailing: selectedCategory?.id == cat.id ? const Icon(Icons.check, color: appbar1) : null,
            onTap: () {
              setState(() => selectedCategory = cat);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _saveExpense() async {
    try {
      if (amountController.text.isEmpty) {
        SnackBarUtils.showWarning(context, AppLocale.pleaseEnterAnAmount.getString(context));
        return;
      }
      if (selectedCategory == null) {
        SnackBarUtils.showWarning(context, AppLocale.pleaseSelectACategory.getString(context));
        return;
      }
      setState(() {
        isLoading = true;
      });

      if (widget.expense == null) {
        await ExpenseService().addExpense(
          expenseCategoryId: selectedCategory!.id!,
          amount: double.parse(amountController.text),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          date: selectedDate,
        );
      } else {
        await ExpenseService().updateExpense(
          id: widget.expense!.id!,
          expenseCategoryId: selectedCategory!.id,
          amount: double.parse(amountController.text),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          date: selectedDate,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save expense error: $e');
      SnackBarUtils.showError(context, '${AppLocale.error.getString(context)}: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FA),
      appBar: AppBar(title: MyText(text: widget.expense == null ? AppLocale.addExpense.getString(context) : AppLocale.editExpense.getString(context))),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _cardField(
                    label: AppLocale.categoryAsterisk.getString(context),
                    child: GestureDetector(
                      onTap: _selectCategory,
                      child: Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: selectedCategory?.name ?? AppLocale.selectCategory.getString(context),
                              fontSize: 16,
                              color: selectedCategory == null ? Colors.grey.shade400 : Colors.black,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: appbar1),
                        ],
                      ),
                    ),
                  ),
                  _cardField(
                    label: AppLocale.amountAsterisk.getString(context),
                    child: TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: AppLocale.enterAmount.getString(context),
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _cardField(
                    label: AppLocale.note.getString(context),
                    child: TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: AppLocale.optionalNote.getString(context),
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _cardField(
                    label: AppLocale.date.getString(context),
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              fontSize: 16,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 18, color: appbar1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbar1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saveExpense,
                  child: isLoading
                      ? Transform.scale(
                          scale: 0.5,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      : MyText(
                          text: widget.expense == null ? AppLocale.save.getString(context) : AppLocale.update.getString(context),
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardField({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: label,
            fontSize: 14,
            color: appbar1,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
