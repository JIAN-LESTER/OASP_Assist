import 'package:flutter/material.dart';

class DateRangeFilter extends StatefulWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const DateRangeFilter({
    Key? key,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  }) : super(key: key);

  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _displayText {
    if (widget.selectedDateRange == null) {
      return 'Select Date Range';
    }

    final startDate = widget.selectedDateRange!.start;
    final endDate = widget.selectedDateRange!.end;

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return _formatDate(startDate);
    }

    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Future<void> _selectDateRange() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return _DateRangePickerDialog(
          initialDateRange: widget.selectedDateRange,
        );
      },
    );

    if (result != null) {
      widget.onDateRangeChanged(result);
    }
  }

  void _clearDateRange() {
    widget.onDateRangeChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        double width = isMobile ? double.infinity : (isTablet ? 220 : 240);
        double height = isMobile ? 48 : 44;
        double fontSize = isMobile ? 14 : 14;
        double horizontalPadding = isMobile ? 14 : 16;
        double iconSize = 18;
        double borderRadius = 8;

        final hasSelection = widget.selectedDateRange != null;

        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: hasSelection ? const Color(0xFFF8FAFB) : Colors.white,
              border: Border.all(
                color:
                    hasSelection
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _animationController.forward().then((_) {
                    _animationController.reverse();
                  });
                  _selectDateRange();
                },
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: const Color(0xFF1E293B).withOpacity(0.05),
                highlightColor: const Color(0xFF1E293B).withOpacity(0.02),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color:
                            hasSelection
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF94A3B8),
                        size: iconSize,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _displayText,
                          style: TextStyle(
                            color:
                                hasSelection
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF64748B),
                            fontSize: fontSize,
                            fontWeight:
                                hasSelection
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasSelection) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _clearDateRange,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.arrow_drop_down,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const _DateRangePickerDialog({this.initialDateRange});

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _displayedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialDateRange != null) {
      _startDate = widget.initialDateRange!.start;
      _endDate = widget.initialDateRange!.end;
      _displayedMonth = _startDate!;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  void _applyDateRange() {
    if (_startDate != null && _endDate != null) {
      if (_startDate!.isAfter(_endDate!)) {
        final temp = _startDate;
        _startDate = _endDate;
        _endDate = temp;
      }
      Navigator.of(
        context,
      ).pop(DateTimeRange(start: _startDate!, end: _endDate!));
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  bool _isDateInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );
    final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    final current = DateTime(date.year, date.month, date.day);

    return (current.isAfter(start) || current.isAtSameMomentAs(start)) &&
        (current.isBefore(end) || current.isAtSameMomentAs(end));
  }

  bool _isStartDate(DateTime date) {
    if (_startDate == null) return false;
    return date.year == _startDate!.year &&
        date.month == _startDate!.month &&
        date.day == _startDate!.day;
  }

  bool _isEndDate(DateTime date) {
    if (_endDate == null) return false;
    return date.year == _endDate!.year &&
        date.month == _endDate!.month &&
        date.day == _endDate!.day;
  }

  Widget _buildQuickSelectList() {
    final quickSelects = [
      {'label': 'Today', 'days': 0},
      {'label': 'Yesterday', 'days': 1},
      {'label': 'Last 7 days', 'days': 7},
      {'label': 'Last 30 days', 'days': 30},
      {'label': 'Last 90 days', 'days': 90},
    ];

    return Column(
      children:
          quickSelects.map((item) {
            return _buildQuickSelectButton(
              item['label'] as String,
              item['days'] as int,
            );
          }).toList(),
    );
  }

  Widget _buildQuickSelectButton(String label, int days) {
    final isToday = days == 0;
    final endDate = DateTime.now();
    final startDate =
        isToday ? endDate : endDate.subtract(Duration(days: days));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final range = DateTimeRange(start: startDate, end: endDate);
          Navigator.of(context).pop(range);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCalendar() {
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final isToday =
          DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;
      final isStart = _isStartDate(date);
      final isEnd = _isEndDate(date);
      final isInRange = _isDateInRange(date);

      dayWidgets.add(_buildDayWidget(date, isToday, isStart, isEnd, isInRange));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF1E293B),
                      size: 20,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: _displayedMonth,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: const Color(0xFF1E293B),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: const Color(0xFF1E293B),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _displayedMonth = selectedDate;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${_getMonthName(_displayedMonth.month)} ${_displayedMonth.year}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF1E293B),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children:
                ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            mainAxisSpacing: 2,
            crossAxisSpacing: 0,
            children: dayWidgets,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  Widget _buildDayWidget(
    DateTime date,
    bool isToday,
    bool isStart,
    bool isEnd,
    bool isInRange,
  ) {
    final isDisabled = date.isAfter(DateTime.now());

    return GestureDetector(
      onTap:
          isDisabled
              ? null
              : () {
                setState(() {
                  if (_startDate == null ||
                      (_startDate != null && _endDate != null)) {
                    _startDate = date;
                    _endDate = null;
                  } else {
                    _endDate = date;
                  }
                });
              },
      child: Stack(
        children: [
          if (isInRange ||
              (isStart && _endDate != null) ||
              (isEnd && _startDate != null))
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1E293B).withOpacity(0.08),
              ),
            ),
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    (isStart || isEnd)
                        ? const Color(0xFF1E293B)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border:
                    isToday && !isStart && !isEnd
                        ? Border.all(color: const Color(0xFF1E293B), width: 1)
                        : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isStart || isEnd ? FontWeight.w500 : FontWeight.w400,
                    color:
                        isDisabled
                            ? const Color(0xFFCBD5E1)
                            : (isStart || isEnd)
                            ? Colors.white
                            : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    final dialogMaxWidth =
        isMobile ? screenWidth - 32 : (isTablet ? 480.0 : 540.0);
    final dialogMaxHeight =
        isMobile
            ? MediaQuery.of(context).size.height - 100
            : (isTablet ? 540.0 : 560.0);
    final sidebarWidth = isMobile ? 0.0 : (isTablet ? 130.0 : 140.0);
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth,
          maxHeight: dialogMaxHeight,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!isMobile)
              Container(
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border(
                    right: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildQuickSelectList(),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(color: Color(0xFFE2E8F0), height: 16),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        isMobile ? 16 : 20,
                        isMobile ? 16 : 20,
                        isMobile ? 16 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child:
                                isMobile
                                    ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildDateColumn('Start', _startDate),
                                        const SizedBox(height: 10),
                                        _buildDateColumn('End', _endDate),
                                      ],
                                    )
                                    : Row(
                                      children: [
                                        Expanded(
                                          child: _buildDateColumn(
                                            'Start',
                                            _startDate,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward,
                                            color: const Color(0xFF94A3B8),
                                            size: 16,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDateColumn(
                                            'End',
                                            _endDate,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                          SizedBox(height: isMobile ? 16 : 20),
                          _buildCustomCalendar(),
                          if (isMobile) ...[
                            const SizedBox(height: 20),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            _buildQuickSelectList(),
                            const SizedBox(height: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      isMobile ? 16 : 20,
                      isMobile ? 16 : 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: _cancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed:
                                  _startDate != null && _endDate != null
                                      ? _applyDateRange
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFE2E8F0,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF94A3B8,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateColumn(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date != null ? _formatDate(date) : 'Not selected',
          style: TextStyle(
            fontSize: 13,
            color:
                date != null
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
