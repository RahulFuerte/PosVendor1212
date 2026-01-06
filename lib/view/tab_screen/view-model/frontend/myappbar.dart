// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController _controller = TextEditingController();

  MyAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: blueGrey.shade50,
      automaticallyImplyLeading: false,
      title: TextField(
        controller: _controller,
        cursorColor: Colors.black,
        decoration: InputDecoration(
          hintText: "Search",
          hintStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _controller.clear();
          },
        ),
      ],
    );
  }
}
