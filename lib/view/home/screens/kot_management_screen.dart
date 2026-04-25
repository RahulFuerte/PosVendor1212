import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/kot_model.dart';
import 'package:pos/data/services/kots_services.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/widgets/order_kot_widgets.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';

class KotManagementScreen extends StatefulWidget {
  final String phoneNo;
  final String adminUid;
  final String? role;
  const KotManagementScreen({super.key, required this.phoneNo, required this.adminUid, this.role});

  @override
  State<KotManagementScreen> createState() => _KotManagementScreenState();
}

class _KotManagementScreenState extends State<KotManagementScreen> {
  List<KotModel> kots = [];
  bool isLoading = false;
  final Set<String> _updatingKotIds = {};
  final KotService _kotService = KotService();

  @override
  void initState() {
    super.initState();
    fetchKOTs();
  }

  Future<void> fetchKOTs() async {
    try {
      setState(() => isLoading = true);
      final fetchedKots = await _kotService.getKots();
      setState(() {
        kots = fetchedKots;
      });
    } catch (e) {
      debugPrint('KOT Fetch Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateKotStatus(String id, String currentStatus) async {
    String nextStatus = "";
    if (currentStatus == "Pending")
      nextStatus = "Preparing";
    else if (currentStatus == "Preparing")
      nextStatus = "Ready";
    else if (currentStatus == "Ready") nextStatus = "Served";

    if (nextStatus.isEmpty) return;

    try {
      setState(() => _updatingKotIds.add(id));
      await _kotService.updateKotStatus(id, nextStatus);
      await fetchKOTs(); // Refresh the list
    } catch (e) {
      debugPrint('KOT Status Update Error: $e');
    } finally {
      if (mounted) {
        setState(() => _updatingKotIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const MyText(text: 'Kitchen Order Tickets (KOT)', fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: fetchKOTs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(
        phoneNo: widget.phoneNo,
        adminPhoneNo: widget.adminUid,
        role: widget.role,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: appbar1))
          : kots.isEmpty
              ? const Center(child: MyText(text: 'No Active KOTs'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: kots.length,
                  itemBuilder: (context, index) {
                    final kot = kots[index];
                    return KOTTile(
                      id: kot.id ?? '',
                      kotNo: kot.kotNumber,
                      table: (kot.tableNumber ?? '').isEmpty ? (kot.orderType ?? 'Takeaway') : kot.tableNumber!,
                      itemList: kot.items.map((e) => e.toJson()).toList(),
                      status: kot.status,
                      createdAt: kot.createdAt?.toLocal() ?? DateTime.now(),
                      isUpdating: _updatingKotIds.contains(kot.id),
                      onStatusUpdate: () => _updateKotStatus(kot.id ?? '', kot.status),
                    );
                  },
                ),
    );
  }
}
