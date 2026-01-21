import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos/data/models/expense_model.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class Expenses extends StatefulWidget {
  final String uid;
  const Expenses({super.key, required this.uid});

  @override
  State<Expenses> createState() => _ExpensesState();
}

class _ExpensesState extends State<Expenses> {
  int selectedTab = 0;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController expenseNameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  List<CategoryModel> categories = [];
  List<ExpenseModel> expenses = [];
  List<ExpenseModel> filteredExpenses = [];
  List<CategoryModel> filteredCategories = [];

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
      await Future.wait([
        fetchCategories(),
        fetchExpenses(),
      ]);
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterExpenses(String query) {
    final q = query.toLowerCase();
    filteredExpenses = expenses.where((exp) {
      return exp.categoryName.toLowerCase().contains(q);
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

  Future<void> fetchExpenses({DateTime? date}) async {
    final target = date ?? DateTime.now();
    final yearMonth = "${target.year}_${target.month.toString().padLeft(2, '0')}";

    final snapshot = await FirebaseFirestore.instance
        .collection('AllExpense')
        .doc(widget.uid)
        .collection('expenses')
        .doc(yearMonth)
        .collection('list')
        .orderBy('date', descending: true)
        .get();

    expenses = snapshot.docs.map((e) => ExpenseModel.fromFirestore(e.data(), e.id)).toList();
    filteredExpenses = List.from(expenses);
  }

  Future<void> fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AllExpense')
        .doc(widget.uid)
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .get();

    categories = snapshot.docs.map((e) => CategoryModel.fromFirestore(e.data(), e.id)).toList();
    filteredCategories = List.from(categories);
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
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
                      const Text(
                        "Add Category",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _categoryController,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: "Enter category name",
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
                            onPressed: isLoading
                                ? null
                                : () {
                                    _categoryController.clear();
                                    Navigator.pop(context);
                                  },
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbar1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final categoryName = _categoryController.text.trim();
                                    if (categoryName.isEmpty) return;

                                    setState(() => isLoading = true);

                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('AllExpense')
                                          .doc(widget.uid)
                                          .collection('categories')
                                          .add({
                                        'name': categoryName,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      fetchCategories();
                                      setState(() {});
                                      _categoryController.clear();

                                      Navigator.pop(context);
                                    } catch (e) {
                                      setState(() => isLoading = false);
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Add",
                                    style: TextStyle(color: Colors.white),
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
          title: const Text(
            "Expenses",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: appbar1,
                ),
              )
            : Column(
                children: [
                  /// 🔹 Tabs (always visible)
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
                          _tabButton("Expenses", 0),
                          _tabButton("Categories", 1),
                        ],
                      ),
                    ),
                  ),

                  /// 🔹 EXPENSE VIEW (ONLY WHEN Expenses TAB)
                  if (selectedTab == 0) ...[
                    /// Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: _filterExpenses,
                        decoration: InputDecoration(
                          hintText: "Search expenses",
                          prefixIcon: Icon(Icons.search, color: appbar1),
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

                    /// Expense List
                    Expanded(
                      child: expenses.isEmpty
                          ? const Center(child: Text("No expenses"))
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
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: appbar1.withOpacity(.15),
                                        child: Text(
                                          exp.categoryName[0].toUpperCase(),
                                          style: TextStyle(
                                            color: appbar1,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp.categoryName,
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "${exp.date.day}/${exp.date.month}/${exp.date.year}",
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "₹ ${numberFormat.format(exp.amount)}",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: appbar1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    /// Add Expense Button
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
                                    uid: widget.uid,
                                    categories: categories,
                                  ),
                                ),
                              );

                              if (result == true) {
                                await fetchExpenses();
                                setState(() {});
                              }
                            },
                            child: const Text(
                              "Add Expense",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  /// 🔹 CATEGORY VIEW (ONLY WHEN Categories TAB)
                  if (selectedTab == 1) ...[
                    /// Search Category Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: _filterCategories,
                        decoration: InputDecoration(
                          hintText: "Search category name",
                          prefixIcon: Icon(Icons.search, color: appbar1),
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

                    /// Expense List
                    Expanded(
                      child: categories.isEmpty
                          ? const Center(child: Text("No categories"))
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
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: appbar1.withOpacity(.15),
                                        child: Text(
                                          cat.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: appbar1,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          cat.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    /// Add Expense Button
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
                            onPressed: _showAddCategoryDialog,
                            child: const Text(
                              "Add Category",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
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
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class AddExpense extends StatefulWidget {
  final String uid;
  final List<CategoryModel> categories;
  const AddExpense({super.key, required this.uid, required this.categories});

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  late CategoryModel selectedCategory;
  DateTime selectedDate = DateTime.now();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.categories.first;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  void _selectCategory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ListView(
        children: widget.categories.map((cat) {
          return ListTile(
            title: Text(cat.name),
            trailing: selectedCategory.id == cat.id ? Icon(Icons.check, color: appbar1) : null,
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
      setState(() {
        isLoading = true;
      });
      if (amountController.text.isEmpty) return;

      final yearMonth = "${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}";

      await FirebaseFirestore.instance
          .collection('AllExpense')
          .doc(widget.uid)
          .collection('expenses')
          .doc(yearMonth)
          .collection('list')
          .add({
        'categoryId': selectedCategory.id,
        'categoryName': selectedCategory.name,
        'amount': int.parse(amountController.text),
        'note': noteController.text,
        'date': selectedDate,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, true);
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FA),
      appBar: AppBar(
        title: const Text("Add Expense"),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// Category
                  _cardField(
                    label: "Category *",
                    child: GestureDetector(
                      onTap: _selectCategory,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedCategory.name,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: appbar1),
                        ],
                      ),
                    ),
                  ),

                  /// Amount
                  _cardField(
                    label: "Amount *",
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter amount",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  /// Note
                  _cardField(
                    label: "Note",
                    child: TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Optional note",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  /// Date
                  _cardField(
                    label: "Date",
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 18, color: appbar1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// Buttons
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
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
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: appbar1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
