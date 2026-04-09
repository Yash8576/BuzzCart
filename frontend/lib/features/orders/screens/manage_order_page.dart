import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';

class ManageOrderPage extends StatefulWidget {
  const ManageOrderPage({super.key, required this.product});

  final ProductModel product;

  @override
  State<ManageOrderPage> createState() => _ManageOrderPageState();
}

class _ManageOrderPageState extends State<ManageOrderPage> {
  final ApiService _api = ApiService();

  int _selectedRating = 0;
  int? _savedRating;
  int? _pendingUpdatedRating;
  ReviewModel? _savedReview;
  double _globalAverage = 0;
  int _globalCount = 0;
  bool _isLoadingReview = true;
  bool _isSubmitting = false;
  bool _didChangeRating = false;

  @override
  void initState() {
    super.initState();
    _globalAverage = widget.product.rating;
    _globalCount = widget.product.reviewsCount;
    _loadReviewState();
  }

  Future<void> _loadReviewState() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingReview = false);
      return;
    }

    try {
      final reviews = await _api.getProductReviews(widget.product.id);
      ProductModel latestProduct = widget.product;
      try {
        latestProduct = await _api.getProduct(widget.product.id);
      } catch (_) {
        latestProduct = widget.product;
      }

      ReviewModel? savedReview;
      for (final review in reviews) {
        if (review.userId == userId) {
          savedReview = review;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _savedReview = savedReview;
        _savedRating = savedReview?.rating;
        _selectedRating = savedReview?.rating ?? 0;
        _globalAverage = latestProduct.rating;
        _globalCount = latestProduct.reviewsCount;
        _isLoadingReview = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _refreshGlobalRating() async {
    try {
      final latestProduct = await _api.getProduct(widget.product.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _globalAverage = latestProduct.rating;
        _globalCount = latestProduct.reviewsCount;
      });
    } catch (_) {
      // Keep the existing values if the refresh fails.
    }
  }

  String _saveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    }
    return 'Failed to save rating';
  }

  Future<void> _submitRating(int rating) async {
    if (_isSubmitting) {
      return;
    }

    final hadExistingReview = _savedReview != null;
    setState(() => _isSubmitting = true);
    try {
      final savedReview = _savedReview == null
          ? await _api.createReview(
              productId: widget.product.id,
              rating: rating,
            )
          : await _api.updateReview(
              reviewId: _savedReview!.id,
              productId: widget.product.id,
              rating: rating,
              reviewTitle: _savedReview!.reviewTitle,
              reviewText: _savedReview!.reviewText,
              isPrivate: _savedReview!.isPrivate,
            );

      await _refreshGlobalRating();

      if (!mounted) {
        return;
      }

      setState(() {
        _savedReview = savedReview;
        _savedRating = savedReview.rating;
        _selectedRating = savedReview.rating;
        _pendingUpdatedRating = null;
        _didChangeRating = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadExistingReview
                ? 'Rating updated to ${savedReview.rating}/5 for ${widget.product.title}'
                : 'Rating ${savedReview.rating}/5 saved for ${widget.product.title}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saveErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<int?> _askForNewRating() async {
    var tempRating = _savedRating ?? 0;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select New Rating'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => tempRating = value),
                    icon: Icon(
                      value <= tempRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color:
                          value <= tempRating ? Colors.amber[700] : Colors.grey,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: tempRating == 0
                      ? null
                      : () => Navigator.of(context).pop(tempRating),
                  child: const Text('Use This Rating'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';
    final isInitialRatingFlow = _savedRating == null;
    final isReadOnlyMode =
        _savedRating != null && _pendingUpdatedRating == null;
    final ratingToDisplay =
        _pendingUpdatedRating ?? _savedRating ?? _selectedRating;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_didChangeRating),
        ),
        title: const Text('Manage Order'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    UrlHelper.getPlatformUrl(imageUrl),
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 68,
                      height: 68,
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Rate this order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoadingReview
                ? 'Loading your saved rating...'
                : isReadOnlyMode
                    ? 'Your rating is saved. Tap Update to change it.'
                    : 'Give a rating out of 5. Review text will be added later.',
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: isReadOnlyMode || _isLoadingReview || _isSubmitting
                    ? null
                    : () {
                        setState(() => _selectedRating = starValue);
                      },
                icon: Icon(
                  starValue <= ratingToDisplay
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: starValue <= ratingToDisplay
                      ? Colors.amber[700]
                      : Colors.grey,
                  size: 34,
                ),
                tooltip: '$starValue star${starValue == 1 ? '' : 's'}',
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            ratingToDisplay == 0
                ? 'No rating selected'
                : _pendingUpdatedRating != null
                    ? 'New rating selected: $ratingToDisplay / 5'
                    : 'Selected rating: $ratingToDisplay / 5',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _savedRating == null
                ? 'Your rating: not rated yet'
                : 'Your rating: $_savedRating / 5',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _globalCount <= 0
                ? 'Global rating: No ratings'
                : 'Global rating: ${_globalAverage.toStringAsFixed(1)} ($_globalCount)',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoadingReview || _isSubmitting
                ? null
                : isInitialRatingFlow
                    ? (_selectedRating == 0
                        ? null
                        : () => _submitRating(_selectedRating))
                    : (_pendingUpdatedRating == null
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final newRating = await _askForNewRating();
                            if (!mounted || newRating == null) {
                              return;
                            }
                            if (newRating == _savedRating) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please choose a different rating'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _pendingUpdatedRating = newRating;
                            });
                          }
                        : () {
                            final updated = _pendingUpdatedRating;
                            if (updated == null) {
                              return;
                            }
                            _submitRating(updated);
                          }),
            child: Text(
              _isSubmitting
                  ? 'Saving...'
                  : isInitialRatingFlow
                      ? 'Save Rating'
                      : (_pendingUpdatedRating == null
                          ? 'Update'
                          : 'Update Rating'),
            ),
          ),
        ],
      ),
    );
  }
}
