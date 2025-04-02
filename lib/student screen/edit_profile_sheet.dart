import 'package:flutter/material.dart';

class EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialJob;
  final String initialLocation;
  final int initialProjects;
  final String initialMobile; // Added mobile field

  const EditProfileSheet({
    Key? key,
    required this.initialName,
    required this.initialJob,
    required this.initialLocation,
    required this.initialProjects,
    required this.initialMobile, // Added to constructor
  }) : super(key: key);

  @override
  _EditProfileSheetState createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _jobController;
  late TextEditingController _locationController;
  late TextEditingController _projectsController;
  late TextEditingController _mobileController; // Added mobile controller

  String? _nameError;
  String? _jobError;
  String? _locationError;
  String? _projectsError;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _jobController = TextEditingController(text: widget.initialJob);
    _locationController = TextEditingController(text: widget.initialLocation);
    _projectsController = TextEditingController(text: widget.initialProjects.toString());
    _mobileController = TextEditingController(text: widget.initialMobile); // Initialize mobile
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    _locationController.dispose();
    _projectsController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'Name cannot be empty' : null;
      _jobError = _jobController.text.trim().isEmpty ? 'Job cannot be empty' : null;
      _locationError = _locationController.text.trim().isEmpty ? 'Location cannot be empty' : null;
      _mobileError = _mobileController.text.trim().isEmpty
          ? 'Mobile cannot be empty'
          : !_mobileController.text.trim().startsWith(RegExp(r'[0-9]')) || _mobileController.text.trim().length != 10
          ? 'Enter a valid 10-digit mobile number'
          : null;
      _projectsError = int.tryParse(_projectsController.text) == null || int.parse(_projectsController.text) < 0
          ? 'Enter a valid number of projects'
          : null;
    });

    return _nameError == null &&
        _jobError == null &&
        _locationError == null &&
        _mobileError == null &&
        _projectsError == null;
  }

  void _saveChanges() {
    if (_validateInputs()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'job': _jobController.text.trim(),
        'location': _locationController.text.trim(),
        'projects': int.tryParse(_projectsController.text) ?? widget.initialProjects,
        'mobile': _mobileController.text.trim(), // Return mobile
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: 'Name',
              icon: Icons.person_outline,
              errorText: _nameError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _jobController,
              label: 'Job Profile',
              icon: Icons.work_outline,
              errorText: _jobError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on_outlined,
              errorText: _locationError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _mobileController,
              label: 'Mobile',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              errorText: _mobileError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _projectsController,
              label: 'Projects',
              icon: Icons.folder_open,
              keyboardType: TextInputType.number,
              errorText: _projectsError,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          errorText: errorText,
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }
}