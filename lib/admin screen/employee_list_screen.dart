import 'dart:ui';
import 'package:flutter/material.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({Key? key}) : super(key: key);

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final List<Map<String, dynamic>> _allEmployees = [
    {'name': 'John Doe', 'role': 'Developer', 'department': 'IT', 'adminCompany': '', 'teamDepartment': ''},
    {'name': 'Jane Smith', 'role': 'Designer', 'department': 'Creative', 'adminCompany': '', 'teamDepartment': ''},
    {'name': 'Mike Johnson', 'role': 'Manager', 'department': 'Operations', 'adminCompany': '', 'teamDepartment': ''},
    {'name': 'Sarah Williams', 'role': 'Analyst', 'department': 'Finance', 'adminCompany': '', 'teamDepartment': ''},
  ];

  final List<String> _teamDepartments = [
    'Design',
    'Development',
    'Data Science',
    'Marketing',
    'Product Management',
    'Quality Assurance',
    'Research'
  ];

  List<Map<String, dynamic>> _filteredEmployees = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'IT', 'Creative', 'Operations', 'Finance'];
  String _adminCompanyFilter = 'All';
  String _teamDepartmentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _filteredEmployees = List.from(_allEmployees);
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterEmployees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((employee) {
        final name = employee['name']?.toLowerCase() ?? '';
        final role = employee['role']?.toLowerCase() ?? '';
        final department = employee['department']?.toLowerCase() ?? '';
        final adminCompany = employee['adminCompany']?.toLowerCase() ?? '';
        final teamDepartment = employee['teamDepartment']?.toLowerCase() ?? '';

        bool matchesSearch = name.contains(query) ||
            role.contains(query) ||
            department.contains(query) ||
            teamDepartment.contains(query);

        bool matchesDepartmentFilter = _selectedFilter == 'All' ||
            department == _selectedFilter.toLowerCase();

        bool matchesAdminCompany = _adminCompanyFilter == 'All' ||
            adminCompany == _adminCompanyFilter.toLowerCase() ||
            (_adminCompanyFilter == 'None' && adminCompany.isEmpty);

        bool matchesTeamDepartment = _teamDepartmentFilter == 'All' ||
            teamDepartment == _teamDepartmentFilter.toLowerCase() ||
            (_teamDepartmentFilter == 'None' && teamDepartment.isEmpty);

        return matchesSearch && matchesDepartmentFilter && matchesAdminCompany && matchesTeamDepartment;
      }).toList();
    });
  }

  void _setDepartmentFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _filterEmployees();
    });
  }

  void _setTeamDepartmentFilter(String filter) {
    setState(() {
      _teamDepartmentFilter = filter;
      _filterEmployees();
    });
  }

  void _assignTeamDepartment(int employeeIndex, String teamDepartment) {
    setState(() {
      final employeeData = _filteredEmployees[employeeIndex];
      final fullListIndex = _allEmployees.indexWhere((e) =>
      e['name'] == employeeData['name'] &&
          e['role'] == employeeData['role'] &&
          e['department'] == employeeData['department']);

      if (fullListIndex >= 0) {
        _allEmployees[fullListIndex]['teamDepartment'] = teamDepartment;
        _filteredEmployees[employeeIndex]['teamDepartment'] = teamDepartment;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff003300), Color(0xff006600)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        toolbarHeight: 60,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                prefixIcon: Icon(Icons.search, color: Colors.green[700], size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _filterEmployees();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      _setDepartmentFilter(filter);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.green[100],
                    checkmarkColor: Colors.green[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.green[800] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? Colors.green[800]! : Colors.grey[300]!),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredEmployees.length} employees found',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (_teamDepartmentFilter != 'All')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Team: $_teamDepartmentFilter',
                          style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            _setTeamDepartmentFilter('All');
                          },
                          child: Icon(Icons.close, size: 14, color: Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildEmployeeList()),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final teamDepartmentFilterOptions = ['All', 'None', ..._teamDepartments];

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.grey.withAlpha(77),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(242),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filter Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Team Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: teamDepartmentFilterOptions.map((dept) {
                          final isSelected = _teamDepartmentFilter == dept;
                          return FilterChip(
                            label: Text(dept),
                            selected: isSelected,
                            onSelected: (selected) {
                              setSheetState(() {
                                _teamDepartmentFilter = dept;
                              });
                              setState(() {
                                _teamDepartmentFilter = dept;
                                _filterEmployees();
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.green[900],
                            checkmarkColor: Colors.green[800],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blue[800] : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filterOptions.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setSheetState(() {
                                _selectedFilter = filter;
                              });
                              setState(() {
                                _selectedFilter = filter;
                                _filterEmployees();
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.green[100],
                            checkmarkColor: Colors.green[800],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.green[800] : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAssignDepartmentBottomSheet(BuildContext context, int employeeIndex, String employeeName) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.grey.withAlpha(77),
      isScrollControlled: true,
      builder: (context) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(242),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assign $employeeName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('What would you like to assign?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.groups, color: Colors.white),
                        label: const Text('Team Department', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showTeamDepartmentSelectionSheet(context, employeeIndex, employeeName);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTeamDepartmentSelectionSheet(BuildContext context, int employeeIndex, String employeeName) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.grey.withAlpha(77),
      isScrollControlled: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), spreadRadius: 0, blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade900, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Assign $employeeName',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(51),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Select Team Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      shrinkWrap: true,
                      itemCount: _teamDepartments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dept = _teamDepartments[index];
                        final isSelected = _filteredEmployees[employeeIndex]['teamDepartment'] == dept;

                        return Card(
                          elevation: isSelected ? 2 : 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSelected ? Colors.green.shade700 : Colors.grey.withAlpha(51), width: isSelected ? 2 : 1),
                          ),
                          color: isSelected ? Colors.green.shade50 : Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _assignTeamDepartment(employeeIndex, dept);
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.green.shade700 : Colors.green.shade700.withAlpha(26),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.groups,
                                      color: isSelected ? Colors.white : Colors.green.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      dept,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.green.shade700 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeList() {
    if (_filteredEmployees.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No employees found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Try adjusting your search or filters', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        final name = employee['name'] ?? 'Unknown';
        final role = employee['role'] ?? 'No Role';
        final department = employee['department'] ?? 'No Department';
        final teamDepartment = employee['teamDepartment'] ?? '';

        Color departmentColor;
        switch (department.toLowerCase()) {
          case 'it':
            departmentColor = Colors.blue;
            break;
          case 'creative':
            departmentColor = Colors.pink;
            break;
          case 'operations':
            departmentColor = Colors.amber;
            break;
          case 'finance':
            departmentColor = Colors.purple;
            break;
          default:
            departmentColor = Colors.grey;
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: InkWell(
            onTap: () => _showAssignDepartmentBottomSheet(context, index, name),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: departmentColor.withAlpha(51),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: departmentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(role),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: departmentColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: departmentColor.withAlpha(77), width: 1),
                              ),
                              child: Text(
                                department,
                                style: TextStyle(color: departmentColor, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (teamDepartment.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.groups, size: 10, color: Colors.blue[700]),
                                    const SizedBox(width: 4),
                                    Text(teamDepartment, style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}