import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceHistoryNotifier extends ChangeNotifier {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isListView = true;
  DateTime _selectedDate = DateTime.now();

  DateTime get currentMonth => _currentMonth;
  bool get isListView => _isListView;
  DateTime get selectedDate => _selectedDate;

  void previousMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    notifyListeners();
  }

  void toggleListView(bool value) {
    _isListView = value;
    notifyListeners();
  }

  void selectDate(DateTime selectedDay, DateTime focusedDay) {
    _selectedDate = selectedDay;
    _currentMonth = focusedDay;
    notifyListeners();
  }
}