import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? selectedPackage;

  final List<String> packages = [
    "Basic Plan",
    "Standard Plan",
    "Premium Plan",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔥 TOP IMAGE / COLOR
          const SizedBox(height: 15,),
          Container(
            color: Colors.white,
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Image.asset(
                "assets/images/myBillLogo.jpeg",
                fit: BoxFit.contain,
                height: 150,
              ),
            ),
          ),

          // ⬜ SIGN UP CARD
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
          
                    // 🧾 TITLE
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Register to start using Invoice Pro",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
          
                    const SizedBox(height: 30),
          
                    // 👤 NAME FIELD
                    _inputLabel("Name"),
                    _inputField(
                      controller: nameController,
                      hint: "Enter your name",
                      icon: Icons.person,
                    ),
          
                    const SizedBox(height: 20),
          
                    // 📱 PHONE FIELD
                    _inputLabel("Phone"),
                    _inputField(
                      controller: phoneController,
                      hint: "Enter your phone number",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
          
                    const SizedBox(height: 20),
          
                    // 📦 PACKAGE DROPDOWN
                    _inputLabel("Select Package"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          value: selectedPackage,
                          hint: const Text("Choose a package"),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: packages.map((pkg) {
                            return DropdownMenuItem(
                              value: pkg,
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium, color: Colors.green),
                                  const SizedBox(width: 10),
                                  Text(pkg),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedPackage = value);
                          },
                        ),
                      ),
                    ),
          
                    const SizedBox(height: 35),
          
                    // 🟢 REGISTER BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbar1,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: () {
                          debugPrint("Name: ${nameController.text}");
                          debugPrint("Phone: ${phoneController.text}");
                          debugPrint("Package: $selectedPackage");
                        },
                        child: const Text(
                          "REGISTER",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 15),
                        ),
                      ),
                    ),
          
                    const SizedBox(height: 20),
          
                    // 🔙 BACK TO LOGIN
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Already have an account? Sign In",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Reusable widgets
  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: appbar1,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
      ),
    );
  }
}
