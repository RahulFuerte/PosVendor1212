import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';

class Dashboard extends StatefulWidget {
  final String phoneNo;
  const Dashboard({super.key, required this.phoneNo});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: appbar1,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Icon(Icons.add_shopping_cart),
      ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Name',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 22),
            ),
            Text(
              'R ID : 711659',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      drawer: MyDrawer(phoneNo: widget.phoneNo , adminPhoneNo: widget.phoneNo,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            const Row(
              children: [
                _InfoCard(
                  title: "Sales",
                  value: '₹0',
                  icon: Icons.point_of_sale,
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                _InfoCard(
                  title: "Total Bills",
                  value: '₹0',
                  icon: Icons.receipt,
                  color: appbar1,
                ),
                const SizedBox(
                  width: 10,
                ),
                _InfoCard(
                  title: "Total Expenses",
                  value: '₹0',
                  icon: Icons.trending_down,
                  color: Colors.red.shade600,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'Orders',
                      active: selectedTab == 0,
                      onTap: () => setState(() => selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      title: 'KOTS',
                      active: selectedTab == 1,
                      onTap: () => setState(() => selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            selectedTab == 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recent Orders",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "View All",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          OrderTile(
                            bill: 7,
                            token: 1,
                            amount: 69,
                            time: '02/01/26 06:23 PM',
                            typeText: "Dine In",
                            typeColor: Colors.teal,
                          ),
                          OrderTile(
                            bill: 8,
                            token: 1,
                            amount: 256,
                            time: '02/01/26 06:23 PM',
                            typeText: "Pick Up",
                            typeColor: Colors.orange,
                          ),
                          OrderTile(
                            bill: 9,
                            token: 1,
                            amount: 450,
                            time: '02/01/26 06:23 PM',
                            typeText: "Dine In",
                            typeColor: Colors.teal,
                          ),
                          OrderTile(
                            bill: 10,
                            token: 1,
                            amount: 300,
                            time: '02/01/26 06:23 PM',
                            typeText: "Delivery",
                            typeColor: Colors.red,
                          ),
                          OrderTile(
                            bill: 11,
                            token: 1,
                            amount: 400,
                            time: '02/01/26 06:23 PM',
                            typeText: "Dine In",
                            typeColor: Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                    ],
                  )
                : ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      KOTTile(kotNo: 101, table: 'T1', items: 3),
                      KOTTile(kotNo: 102, table: 'T2', items: 5),
                      KOTTile(kotNo: 103, table: 'Parcel', items: 2),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

/// INFO CARD
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          border: Border.all(color: color, width: 0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 18)),
                        Icon(icon, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(value,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: color, overflow: TextOverflow.ellipsis)),
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

/// TAB BUTTON
class _TabButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: active ? appbar1 : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(color: active ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
    );
  }
}

/// ORDER TILE
class OrderTile extends StatelessWidget {
  final int bill;
  final int token;
  final int amount;
  final String time;
  final bool edited;
  final String typeText;
  final Color typeColor;

  const OrderTile({
    super.key,
    required this.bill,
    required this.token,
    required this.amount,
    required this.time,
    this.edited = false,
    required this.typeText,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border(left: BorderSide(color: typeColor, width: 5)),
          boxShadow: [BoxShadow(blurRadius: 2, spreadRadius: 3, color: Colors.grey.shade100, offset: const Offset(0, 3))]),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Bill No. $bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    typeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'Token No. $token',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text('$time${edited ? '  Edited' : ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
          ),
          Column(
            children: [
              Text('₹$amount', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.local_print_shop_outlined, color: appbar1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// KOT TILE
class KOTTile extends StatelessWidget {
  final int kotNo;
  final String table;
  final int items;

  const KOTTile({
    super.key,
    required this.kotNo,
    required this.table,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: appbar1, width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          /// KOT NUMBER
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KOT',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '#$kotNo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          /// DIVIDER
          Container(
            height: 35,
            width: 1,
            color: Colors.grey.shade300,
          ),

          const SizedBox(width: 16),

          /// TABLE INFO
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TABLE',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                table,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const Spacer(),

          /// ITEMS COUNT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: appbar1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$items Items',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: appbar1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
