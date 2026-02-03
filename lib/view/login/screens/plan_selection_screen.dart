import 'package:flutter/material.dart';

// Assuming appbar1 is defined globally or we define it locally if not accessible.
// Ideally we import it, but for now defining it here to match the requested style or importing if I knew the path.
// Based on grep, it's in navigation.dart, but importing that might bring circular deps or unused code.
// I will just use the color directly or import if possible.
// To be safe and quick, I'll use the color value found: Color.fromARGB(255, 12, 107, 15)
const Color appColor = Color.fromARGB(255, 12, 107, 15);

class PlanSelectionScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String email;

  const PlanSelectionScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  int selectedTrialDays = 30; // Default to 30 Days
  String selectedPlan = "Standard"; // Default to Standard

  final List<int> trialOptions = [7, 30, 60];

  // Plans data
  final List<Map<String, dynamic>> plans = [
    {
      "name": "Basic",
      "price": "₹3650",
      "subtitle": "/ year",
      "description":
          "Perfect for starters", // Placeholder as image content is cut off or generic
    },
    {
      "name": "Standard",
      "price": "₹7300",
      "subtitle": "/ year",
      "description": "Perfect for freelancers",
      "isPopular": true,
    },
    {
      "name": "Platinum",
      "price": "₹10950",
      "subtitle": "/ year",
      "description": "For growing teams",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light greyish background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Choose Your Plan",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Unlock Invoice Pro",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                "Start your journey with a free trial.",
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 30),

              const Text(
                "SELECT TRIAL DURATION",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              const SizedBox(height: 15),

              // Trial Duration Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: trialOptions.map((days) {
                  bool isSelected = selectedTrialDays == days;
                  return GestureDetector(
                    onTap: () => setState(() => selectedTrialDays = days),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1ED760)
                            : Colors.white, // Bright green if selected
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: Colors.green.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ]
                            : [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ],
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        "$days Days",
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              // Plan Cards
              // We'll display the "Most Popular" (Standard) prominently if we can, or just list them.
              // The design shows Standard as big, others small.
              // For simplicity and adaptiveness, I will render the selected plan bigger or all same size but highlight selected.
              // However, the prompt image specific layout with Standard sticking out.
              // To match the image exactly requires a custom layout. I'll use a vertical list for now or a horizontal scroll if that fits better?
              // The image looks vertical. Standard is in the middle.
              // I'll make the "Standard" card prominent.

              ...plans.map((plan) {
                bool isPopular = plan['isPopular'] == true;
                bool isSelected = selectedPlan == plan['name'];

                return GestureDetector(
                  onTap: () => setState(() => selectedPlan = plan['name']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected || isPopular
                                ? Border.all(
                                    color: const Color(0xFF1ED760), width: 2)
                                : Border.all(color: Colors.transparent),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan['name'],
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    plan['description'] ?? "",
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    plan['price'],
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    plan['subtitle'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isPopular)
                          Positioned(
                            top: -12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1ED760),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "MOST POPULAR",
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // Features List
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Included in Standard:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              _buildFeatureItem("Unlimited Invoices & Estimates"),
              _buildFeatureItem("Professional PDF Exports"),
              _buildFeatureItem("Cloud Sync Across Devices"),

              const SizedBox(height: 30),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ED760),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 5,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                  onPressed: () {
                    // Final Action
                    debugPrint("Combines Data:");
                    debugPrint("Name: ${widget.name}");
                    debugPrint("Phone: ${widget.phone}");
                    debugPrint("Email: ${widget.email}");
                    debugPrint("Plan: $selectedPlan");
                    debugPrint("Trial: $selectedTrialDays Days");

                    // Here you would typically call your API or Navigate to Home
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Registered for $selectedPlan ($selectedTrialDays days trial)")),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "REGISTER & START TRIAL",
                        style: TextStyle(
                          color: Colors
                              .black, // Dark text on green button per design
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.black),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1ED760), size: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
