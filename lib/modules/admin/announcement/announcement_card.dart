import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../icon_and_color.dart';

String? _normalizeAnnouncementImageUrl(dynamic value) {
  if (value == null) return null;

  String rawUrl = '';

  if (value is String) {
    rawUrl = value;
  } else if (value is Map && value['url'] != null) {
    rawUrl = value['url'].toString();
  }

  if (rawUrl.isEmpty) return null;

  final sanitizedUrl = rawUrl.trim().replaceAll('&amp;', '&');
  final uri = Uri.tryParse(sanitizedUrl);

  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  return uri.toString();
}

bool _isFirebaseAnnouncementImageUrl(String url) {
  return url.contains('firebasestorage.googleapis.com');
}

List<String> _selectAnnouncementImageUrls(Iterable<dynamic> values) {
  final normalized =
      values.map(_normalizeAnnouncementImageUrl).whereType<String>().toList();

  if (normalized.isEmpty) return const [];

  final firebaseUrls =
      normalized.where(_isFirebaseAnnouncementImageUrl).toList();

  return firebaseUrls.isNotEmpty ? firebaseUrls : normalized;
}

class AnnouncementCard extends StatefulWidget {
  final DocumentSnapshot announcement;
  final int index;
  final bool isDesktop;
  final Function(DocumentSnapshot)? onEdit;
  final Function(DocumentSnapshot)? onDelete;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.index,
    required this.isDesktop,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _isMessageExpanded = false; // ✅ NEW: Track message expansion state

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.announcement.data() as Map<String, dynamic>;
    final message = data['message'] ?? "";
    final category = data['category'] ?? 'General';
    final deadline = data['deadline'];

    List<String> images = _selectAnnouncementImageUrls(
      (data['images'] as List?) ?? const [],
    );

    if (images.isEmpty) {
      images = _selectAnnouncementImageUrls([data['full_picture']]);
    }

    if (images.isEmpty && data['original_image_urls'] is List) {
      images = _selectAnnouncementImageUrls(data['original_image_urls'] as List);
    }

    final hasImages = images.isNotEmpty;
    final imageCount = data['image_count'] ?? images.length;
    final createdTime = _formatDate(data['created_time']);
    final hasOCR = data['has_image_text'] == true;
    final ocrProcessedCount = data['ocr_processed_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            category,
            createdTime,
            imageCount,
            hasOCR,
            ocrProcessedCount,
          ),
          if (deadline != null) _buildDeadline(deadline),
          if (message.isNotEmpty) _buildMessage(message),
          if (hasImages) _buildImageGallery(images),
          _buildActionButtons(data),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child:
          images.length == 1
              ? _buildSingleImage(images[0])
              : _buildImageCollage(images),
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, [imageUrl], 0),
        child: Container(
          height: widget.isDesktop ? 400 : 300,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildAnnouncementImage(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => _buildImageError(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildImageLoading(loadingProgress);
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _buildFullscreenButton([imageUrl], 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCollage(List<String> images) {
    final imageCount = images.length;

    // Different layouts based on number of images
    if (imageCount == 2) {
      return _buildTwoImageLayout(images);
    } else if (imageCount == 3) {
      return _buildThreeImageLayout(images);
    } else if (imageCount == 4) {
      return _buildFourImageLayout(images);
    } else {
      // 5 or more images
      return _buildMultiImageLayout(images);
    }
  }

  // Layout for 2 images (side by side)
  Widget _buildTwoImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Row(
          children: [
            Expanded(child: _buildCollageImage(images[0], 0, images)),
            const SizedBox(width: 4),
            Expanded(child: _buildCollageImage(images[1], 1, images)),
          ],
        ),
      ),
    );
  }

  // Layout for 3 images (1 large on left, 2 stacked on right)
  Widget _buildThreeImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Row(
          children: [
            Expanded(flex: 2, child: _buildCollageImage(images[0], 0, images)),
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildCollageImage(images[1], 1, images)),
                  const SizedBox(height: 4),
                  Expanded(child: _buildCollageImage(images[2], 2, images)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout for 4 images (2x2 grid)
  Widget _buildFourImageLayout(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCollageImage(images[0], 0, images)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildCollageImage(images[1], 1, images)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCollageImage(images[2], 2, images)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildCollageImage(images[3], 3, images)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout for 5+ images (2x2 grid with "+N" overlay on last image)
  Widget _buildMultiImageLayout(List<String> images) {
    final displayImages = images.take(4).toList();
    final remainingCount = images.length - 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.isDesktop ? 400 : 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCollageImage(displayImages[0], 0, images),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildCollageImage(displayImages[1], 1, images),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCollageImage(displayImages[2], 2, images),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildCollageImage(
                      displayImages[3],
                      3,
                      images,
                      showOverlay: true,
                      overlayText: '+$remainingCount',
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

  Widget _buildCollageImage(
    String imageUrl,
    int index,
    List<String> allImages, {
    bool showOverlay = false,
    String? overlayText,
  }) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, allImages, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildAnnouncementImage(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[100],
                child: Center(
                  child: CircularProgressIndicator(
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green[600]!,
                    ),
                  ),
                ),
              );
            },
          ),
          if (showOverlay && overlayText != null)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Text(
                  overlayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Fullscreen button on hover
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenButton(List<String> images, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFullScreenImage(context, images, index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageGallery(
              images: images,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, images, index),
              child: Image.network(
                images[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain, // ✅ Changed from cover to contain
                errorBuilder:
                    (context, error, stackTrace) => _buildImageError(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImageLoading(loadingProgress);
                },
              ),
            );
          },
        ),

        if (images.length > 1) ...[
          _buildNavigationArrow(
            alignment: Alignment.centerLeft,
            icon: Icons.chevron_left,
            onTap: () {
              if (_currentImageIndex > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            enabled: _currentImageIndex > 0,
          ),
          _buildNavigationArrow(
            alignment: Alignment.centerRight,
            icon: Icons.chevron_right,
            onTap: () {
              if (_currentImageIndex < images.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            enabled: _currentImageIndex < images.length - 1,
          ),
        ],

        if (images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_currentImageIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          top: 12,
          left: 12,
          child: _buildFullscreenButton(images, _currentImageIndex),
        ),
      ],
    );
  }

  Widget _buildNavigationArrow({
    required AlignmentGeometry alignment,
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    if (!enabled) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    String category,
    String createdTime,
    int imageCount,
    bool hasOCR,
    int ocrProcessedCount,
  ) {
    return Padding(
      padding: EdgeInsets.all(widget.isDesktop ? 24 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  getColorForCategory(category).withOpacity(0.9),
                  getColorForCategory(category),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              getCategoryIcon(category),
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            getColorForCategory(category).withOpacity(0.15),
                            getColorForCategory(category).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: getColorForCategory(category),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdTime,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadline(dynamic deadline) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEADLINE',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'MMMM d, yyyy',
                  ).format((deadline as Timestamp).toDate()),
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Message widget with See More/Less functionality
  Widget _buildMessage(String message) {
    // Count the number of lines
    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
        style: TextStyle(
          fontSize: widget.isDesktop ? 15 : 14,
          height: 1.7,
          color: Colors.grey[700],
        ),
      ),
      maxLines: null,
      textDirection: Directionality.of(context),
    )..layout(
      maxWidth:
          MediaQuery.of(context).size.width - (widget.isDesktop ? 48 : 40),
    );

    final lineCount = textPainter.computeLineMetrics().length;
    final needsExpansion = lineCount > 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 24 : 20,
        0,
        widget.isDesktop ? 24 : 20,
        widget.isDesktop ? 20 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: widget.isDesktop ? 15 : 14,
              height: 1.7,
              color: Colors.grey[700],
            ),
            maxLines: needsExpansion && !_isMessageExpanded ? 3 : null,
            overflow:
                needsExpansion && !_isMessageExpanded
                    ? TextOverflow.ellipsis
                    : null,
          ),
          if (needsExpansion) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _isMessageExpanded = !_isMessageExpanded;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isMessageExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isMessageExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.green[700],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[200]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageLoading(ImageChunkEvent loadingProgress) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: CircularProgressIndicator(
          value:
              loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
        ),
      ),
    );
  }

  Widget _buildAnnouncementImage(
    String imageUrl, {
    required BoxFit fit,
    ImageErrorWidgetBuilder? errorBuilder,
    ImageLoadingBuilder? loadingBuilder,
  }) {
    final normalizedUrl = _normalizeAnnouncementImageUrl(imageUrl);

    if (normalizedUrl == null) {
      return errorBuilder?.call(context, StateError('Invalid image URL'), null) ??
          _buildImageError();
    }

    return Image.network(
      normalizedUrl,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }


  Widget _buildActionButtons(Map<String, dynamic> data) {
  return Container(
    padding: EdgeInsets.all(widget.isDesktop ? 24 : 20),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),

    ),
    child: FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: _buildActionButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'View on Facebook',
                  onTap: () => _launchUrl(data['permalink_url']),
                  isPrimary: true,
                ),
              ),
            ],
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final role = userData?['role'] ?? 'user';

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: _buildActionButton(
                icon: Icons.open_in_new_rounded,
                label: 'View on Facebook',
                onTap: () => _launchUrl(data['permalink_url']),
                isPrimary: true,
              ),
            ),

            // 🔥 Only show Edit/Delete for admins
            if (role == 'admin') ...[
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.edit_rounded,
                onTap: () => widget.onEdit!(widget.announcement),
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.delete_rounded,
                onTap: () => widget.onDelete!(widget.announcement),
                color: Colors.red,
              ),
            ],
          ],
        );
      },
    ),
  );
}


  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient:
                isPrimary
                    ? LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[700]!],
                    )
                    : null,
            color: isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? Colors.green[700]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isPrimary ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : Colors.grey[700],
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  void _launchUrl(String? url) {
    if (url != null) {
      launchUrl(Uri.parse(url));
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }
}

// ============================================================================
// ✅ UPDATED: Full Screen Image Gallery with Navigation Arrows
// ============================================================================

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    _images =
        widget.images
            .map(_normalizeAnnouncementImageUrl)
            .whereType<String>()
            .toList();
    _currentIndex =
        _images.isEmpty
            ? 0
            : widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_images.isEmpty)
            const Center(
              child: Icon(Icons.error, color: Colors.white, size: 64),
            )
          else
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    _images[index],
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.error,
                        color: Colors.white,
                        size: 64,
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // ✅ NEW: Navigation arrows in fullscreen
          if (_images.length > 1) ...[
            _buildFullscreenNavigationArrow(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onTap: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              enabled: _currentIndex > 0,
            ),
            _buildFullscreenNavigationArrow(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onTap: () {
                if (_currentIndex < _images.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              enabled: _currentIndex < _images.length - 1,
            ),
          ],

          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Image counter
          if (_images.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  //  NEW: Navigation arrow for fullscreen mode
  Widget _buildFullscreenNavigationArrow({
    required AlignmentGeometry alignment,
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    if (!enabled) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
