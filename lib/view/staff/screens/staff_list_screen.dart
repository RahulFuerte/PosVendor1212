import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/utils/error_utils.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/staff/screens/add_staff_screen.dart';
import 'package:pos/view/staff/screens/edit_staff_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  List<UserModel> _staff = [];
  List<UserModel> _filteredStaff = [];
  bool _isLoading = true;
  String? _adminId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _adminId = prefs.getString('adminUid') ?? prefs.getString('_id');

      if (_adminId != null) {
        final staff = await UserService().getStaff(_adminId!);
        setState(() {
          _staff = staff;
          _filteredStaff = List.from(staff);
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getCleanErrorMessage(e));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterStaff(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredStaff = _staff.where((staff) {
        return staff.name.toLowerCase().contains(q) || staff.phoneNumber.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _deleteStaff(UserModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: MyText(text: AppLocale.deleteStaff.getString(context)),
        content: MyText(text: '${AppLocale.areYouSureDeleteStaff.getString(context)}${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: MyText(text: AppLocale.cancel.getString(context)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: MyText(text: AppLocale.delete.getString(context)),
          ),
        ],
      ),
    );

    if (confirm == true && staff.id != null) {
      try {
        await UserService().deleteStaff(staff.id!);
        await _loadStaff();
        _searchController.clear();
        if (mounted) {
          SnackBarUtils.showSuccess(context, AppLocale.staffDeletedSuccess.getString(context));
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, ErrorUtils.getCleanErrorMessage(e));
        }
      }
    }
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
          text: AppLocale.staffManagement.getString(context),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: appbar1),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterStaff,
                    decoration: InputDecoration(
                      hintText: AppLocale.searchByNameOrPhone.getString(context),
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
                Expanded(
                  child: _staff.isEmpty
                      ? Center(
                          child: MyText(text: AppLocale.noStaffFound.getString(context)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStaff.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final staff = _filteredStaff[i];
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
                                      text: staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
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
                                          text: staff.name,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        const SizedBox(height: 4),
                                        MyText(
                                          text: staff.phoneNumber,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                            onPressed: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditStaffScreen(staff: staff),
                                                ),
                                              );
                                              if (result == true) {
                                                await _loadStaff();
                                                _searchController.clear();
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _deleteStaff(staff),
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
                              builder: (_) => const AddStaffScreen(),
                            ),
                          );
                          if (result == true) {
                            await _loadStaff();
                            _searchController.clear();
                          }
                        },
                        child: MyText(
                          text: AppLocale.addStaff.getString(context),
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
}
