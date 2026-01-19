import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(
      context,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Users Data',
          style: TextStyle(fontFamily: 'tabfont'),
        ),
      ),
      body: FutureBuilder(
        future: _getUserData(),
        builder: (context, AsyncSnapshot<List<UserModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final usersData = snapshot.data;

            if (usersData!.isEmpty) {
              return const Center(child: Text('No users data available.'));
            }

            return ListView.builder(
              itemCount: usersData.length,
              itemBuilder: (context, index) {
                final user = usersData[index];
                return Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      border: Border.all(
                        color: primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: green.shade100,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(40),
                            ),
                          ),
                          height: MediaQuery.of(context).size.height / 9,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Container(
                                height: 65,
                                width: 65,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(75),
                                  image: const DecorationImage(
                                    fit: BoxFit.cover,
                                    image: NetworkImage(
                                        'https://img.freepik.com/premium-vector/businessman-avatar-cartoon-character-profile_18591-50585.jpg?w=360'),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.userName,
                                        style: const TextStyle(
                                          fontFamily: 'tabfont',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 14, color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            user.phoneNumber,
                                            style: const TextStyle(
                                              fontFamily: 'fontmain',
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total: ₹${user.totalAmount}',
                                        style: TextStyle(
                                          fontFamily: 'fontmain',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      printprovider.additem(user.details, user.totalAmount);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: primaryColor,
                                          content: Text('Cart Updated !'),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      MdiIcons.databaseImport,
                                      color: blue,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red.shade300,
                                    ),
                                    onPressed: () => _deleteUserData(context, index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Price')),
                            DataColumn(label: Text('Quantity')),
                          ],
                          rows: user.details
                              .map<DataRow>((detail) => DataRow(
                                    cells: [
                                      DataCell(Text(detail['name'])),
                                      DataCell(Text(detail['price'].toString())),
                                      DataCell(Text(detail['quantity'].toString())),
                                    ],
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<UserModel>> _getUserData() async {
    final box = await Hive.openBox('userBox');
    final List<UserModel> usersData = [];

    for (var i = 0; i < box.length; i++) {
      final userMap = box.getAt(i);

      if (userMap != null) {
        final List<Map<String, dynamic>> details = _decodeDetails(userMap['details']);

        print("These Is The Details ............$details");

        final userModel = UserModel(
          phoneNumber: userMap['phoneNumber'] ?? 'N/A',
          userName: userMap['userName'],
          details: details,
          totalAmount: userMap['totalAmount'],
        );

        usersData.add(userModel);
      }
    }
    return usersData;
  }

  List<Map<String, dynamic>> _decodeDetails(dynamic details) {
    if (details is List && details.isNotEmpty) {
      List<Map<String, dynamic>> decodedList = [];

      for (var item in details) {
        if (item is Map<dynamic, dynamic>) {
          // Convert the inner map to Map<String, dynamic>
          Map<String, dynamic> convertedItem = {};
          item.forEach((key, value) {
            convertedItem[key.toString()] = value;
          });

          decodedList.add(convertedItem);
        } else {
          print('Unexpected format for detail item: $item');
        }
      }

      return decodedList;
    } else {
      print('Unexpected format for details: $details');
      return [];
    }
  }

  Future<void> _deleteUserData(BuildContext context, int index) async {
    final box = await Hive.openBox('userBox');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this user data?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await box.deleteAt(index);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: primaryColor,
                    content: Text('User data deleted !'),
                  ),
                );
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
