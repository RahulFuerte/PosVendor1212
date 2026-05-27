import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/subscription_history_model.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';

class SubscriptionHistoryScreen extends StatefulWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  State<SubscriptionHistoryScreen> createState() => _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends State<SubscriptionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: MyText(text: AppLocale.transactionHistory.getString(context), fontSize: 17, color: Colors.black, fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.1), height: 1),
        ),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingHistory && provider.history.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (provider.history.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.history.length,
              itemBuilder: (context, index) {
                final transaction = provider.history[index];
                return _buildTransactionCard(transaction);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const MyText(text: 'No Transactions Yet', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          const SizedBox(height: 8),
          const MyText(
            text: "You haven't purchased any plans yet.\nWhen you do, they'll appear here.",
            textAlign: TextAlign.center,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(SubscriptionHistoryModel transaction) {
    bool isCompleted = transaction.status == 'completed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: isCompleted ? Colors.green : (transaction.status == 'pending' ? Colors.amber : Colors.red),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MyText(
                                text: transaction.planName,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                              MyText(
                                text: 'ID: ${transaction.paymentId}',
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MyText(
                                text: '₹${transaction.price.toStringAsFixed(0)}',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isCompleted ? Colors.green : (transaction.status == 'pending' ? Colors.amber : Colors.red)).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: MyText(
                                  text: transaction.status.toUpperCase(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? Colors.green : (transaction.status == 'pending' ? Colors.amber : Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDateInfo('Purchased On', DateFormat('dd MMM, yyyy').format(transaction.startDate)),
                          const Spacer(),
                          _buildDateInfo('Expires On', DateFormat('dd MMM, yyyy').format(transaction.endDate)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(text: label, fontSize: 11, color: const Color(0xFF64748B)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF1E293B)),
            const SizedBox(width: 4),
            MyText(text: date, fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ],
        ),
      ],
    );
  }
}
