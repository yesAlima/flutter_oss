import 'package:flutter/material.dart';

class DateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const DateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Start Date'),
            subtitle: Text(_startDate != null
                ? '${_startDate!.year}-${_startDate!.month}-${_startDate!.day}'
                : 'Not selected'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, true),
          ),
          ListTile(
            title: const Text('End Date'),
            subtitle: Text(_endDate != null
                ? '${_endDate!.year}-${_endDate!.month}-${_endDate!.day}'
                : 'Not selected'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_startDate != null && _endDate != null) {
              Navigator.pop(
                context,
                DateTimeRange(start: _startDate!, end: _endDate!),
              );
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
} 