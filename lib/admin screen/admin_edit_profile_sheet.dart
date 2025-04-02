import 'package:flutter/material.dart';

class AdminEditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialRole;
  final String initialDepartment;
  final String initialLocation;
  final String initialMobile;
  final String initialAdminLevel;

  const AdminEditProfileSheet({
    Key? key,
    required this.initialName,
    required this.initialRole,
    required this.initialDepartment,
    required this.initialLocation,
    required this.initialMobile,
    required this.initialAdminLevel,
  }) : super(key: key);

  @override
  _AdminEditProfileSheetState createState() => _AdminEditProfileSheetState();
}

class _AdminEditProfileSheetState extends State<AdminEditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _departmentController;
  late TextEditingController _locationController;
  late TextEditingController _mobileController;
  late String _selectedAdminLevel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _roleController = TextEditingController(text: widget.initialRole);
    _departmentController = TextEditingController(text: widget.initialDepartment);
    _locationController = TextEditingController(text: widget.initialLocation);
    _mobileController = TextEditingController(text: widget.initialMobile);
    _selectedAdminLevel = widget.initialAdminLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Admin Profile",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: "Name",
              icon: Icons.person,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _roleController,
              label: "Role",
              icon: Icons.work,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _departmentController,
              label: "Firm",
              icon: Icons.apartment,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _locationController,
              label: "Location",
              icon: Icons.location_on,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _mobileController,
              label: "Mobile Number",
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'name': _nameController.text,
                        'role': _roleController.text,
                        'department': _departmentController.text,
                        'location': _locationController.text,
                        'mobile': _mobileController.text,
                        'adminLevel': _selectedAdminLevel,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}