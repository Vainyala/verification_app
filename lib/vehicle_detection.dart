import 'package:flutter/material.dart';
import 'package:id_verification_app/stolen_vehicle_page/capture_stolen_vehicle.dart';

import 'stolen_vehicle_page/add_stolen_vehicle.dart';


class VehicleDetectionScreen extends StatelessWidget {
  const VehicleDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Title Section
                const Text(
                  'Vehicle Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose an option below to continue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),

                // 🔹 Option 1
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StolenVehiclePage(),
                      ),
                    );
                  },
                  child: _buildOptionCard(
                    icon: Icons.add_box_outlined,
                    title: "Add Stolen Vehicle",
                    subtitle: "Register new stolen vehicle details",
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Option 2
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StolenVehicleDetectedPage(),
                      ),
                    );
                  },
                  child: _buildOptionCard(
                    icon: Icons.camera_alt_outlined,
                    title: "Send Capture Stolen Vehicle",
                    subtitle: "Upload or capture vehicle image",
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color,
          child: Icon(icon, color: Colors.black87, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      ),
    );
  }
}
