
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Widget buildPagination({
  required int currentPage,
  required int totalPages,
  required int totalItems,
  required int itemsPerPage,
  required ValueChanged<int> onPageChanged,
  required ValueChanged<int> onItemsPerPageChanged,
  required String item,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;
      bool isTablet = screenWidth >= 600 && screenWidth < 1100;

      if (totalItems <= 0) {
        return const SizedBox.shrink();
      }

      int safeCurrentPage = currentPage.clamp(1, totalPages);
      int startItem = ((safeCurrentPage - 1) * itemsPerPage) + 1;
      int endItem = (safeCurrentPage * itemsPerPage).clamp(
        startItem,
        totalItems,
      );

      int maxVisiblePages = isMobile ? 3 : 5;
      int startPage = (safeCurrentPage - (maxVisiblePages ~/ 2)).clamp(
        1,
        totalPages,
      );
      int endPage = (startPage + maxVisiblePages - 1).clamp(1, totalPages);

      if (endPage - startPage + 1 < maxVisiblePages) {
        startPage = (endPage - maxVisiblePages + 1).clamp(1, totalPages);
      }

      List<int> visiblePages = [];
      for (int i = startPage; i <= endPage; i++) {
        visiblePages.add(i);
      }

      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 16,
          horizontal: isMobile ? 8 : 16,
        ),
        child:
            isMobile
                ? Column(
                  children: [
                    // Items per page selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items per page:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        DropdownButton<int>(
                          value: itemsPerPage,
                          items:
                              [5, 10, 15, 20, 25].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              onItemsPerPageChanged(newValue);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Page info
                    Text(
                      'Showing $startItem to $endItem of $totalItems $item',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    // Page controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed:
                              safeCurrentPage > 1
                                  ? () => onPageChanged(safeCurrentPage - 1)
                                  : null,
                          icon: const Icon(Icons.chevron_left),
                          iconSize: 20,
                        ),
                        ...visiblePages.map(
                          (page) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () => onPageChanged(page),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      page == safeCurrentPage
                                          ? Colors.green
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        page == safeCurrentPage
                                            ? Colors.green
                                            : Colors.grey[300]!,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    page.toString(),
                                    style: TextStyle(
                                      color:
                                          page == safeCurrentPage
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              safeCurrentPage < totalPages
                                  ? () => onPageChanged(safeCurrentPage + 1)
                                  : null,
                          icon: const Icon(Icons.chevron_right),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Items per page and info
                    Row(
                      children: [
                        Text(
                          'Items per page:',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: itemsPerPage,
                          items:
                              [5, 10, 15, 20, 25].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              onItemsPerPageChanged(newValue);
                            }
                          },
                        ),
                        const SizedBox(width: 24),
                        Text(
                          'Showing $startItem to $endItem of $totalItems $item',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    // Right side: Pagination controls
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              safeCurrentPage > 1
                                  ? () => onPageChanged(safeCurrentPage - 1)
                                  : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        ...visiblePages.map(
                          (page) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () => onPageChanged(page),
                              child: Container(
                                width: isTablet ? 36 : 40,
                                height: isTablet ? 36 : 40,
                                decoration: BoxDecoration(
                                  color:
                                      page == safeCurrentPage
                                          ? Colors.green
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        page == safeCurrentPage
                                            ? Colors.green
                                            : Colors.grey[300]!,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    page.toString(),
                                    style: TextStyle(
                                      color:
                                          page == safeCurrentPage
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: isTablet ? 12 : 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              safeCurrentPage < totalPages
                                  ? () => onPageChanged(safeCurrentPage + 1)
                                  : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
      );
    },
  );
}
