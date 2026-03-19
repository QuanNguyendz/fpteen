import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/feedback/providers/store_feedback_provider.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _feedbackScreenStoreProvider =
    FutureProvider.family.autoDispose<StoreModel, String>((ref, storeId) {
  return ref.watch(storeRepositoryProvider).fetchStore(storeId);
});

class StoreFeedbackScreen extends ConsumerWidget {
  const StoreFeedbackScreen({super.key, required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(_feedbackScreenStoreProvider(storeId));
    final dataAsync = ref.watch(storeFeedbackScreenDataProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: storeAsync.when(
          data: (s) => Text(s.name),
          loading: () => const Text('Đánh giá cửa hàng'),
          error: (_, _) => const Text('Đánh giá cửa hàng'),
        ),
      ),
      body: dataAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Đang tải đánh giá...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(storeFeedbackScreenDataProvider(storeId)),
        ),
        data: (data) => _FeedbackBody(
          storeAsync: storeAsync,
          data: data,
          onRetryStore: () =>
              ref.invalidate(_feedbackScreenStoreProvider(storeId)),
        ),
      ),
    );
  }
}

class _FeedbackBody extends StatefulWidget {
  const _FeedbackBody({
    required this.storeAsync,
    required this.data,
    required this.onRetryStore,
  });

  final AsyncValue<StoreModel> storeAsync;
  final StoreFeedbackScreenData data;
  final VoidCallback onRetryStore;

  @override
  State<_FeedbackBody> createState() => _FeedbackBodyState();
}

class _FeedbackBodyState extends State<_FeedbackBody> {
  int? _selectedStar; // null = tất cả
  String? _selectedMenuItemId; // null = tất cả món

  @override
  Widget build(BuildContext context) {
    final stats = widget.data.stats;
    final ratingCount = stats.ratingCount;

    final starFilteredReviews = _selectedStar == null
        ? widget.data.reviews
        : widget.data.reviews.where((r) => r.rating == _selectedStar).toList();

    // Tạo danh sách menu item theo kết quả sau khi lọc star để dropdown hợp lệ.
    final starGrouped = _groupByMenuItem(starFilteredReviews);
    final menuFilteredReviews = _selectedMenuItemId == null
        ? starFilteredReviews
        : starFilteredReviews
            .where((r) => (r.menuItemId.isEmpty ? r.menuItemName : r.menuItemId) == _selectedMenuItemId)
            .toList();

    final grouped = _groupByMenuItem(menuFilteredReviews);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        widget.storeAsync.when(
          data: (store) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: store.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: store.logoUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.storefront_outlined,
                            color: Colors.grey.shade400),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ratingCount == 0
                          ? 'Chưa có điểm trung bình'
                          : 'Điểm trung bình: ${stats.avgRating.toStringAsFixed(1)} ★ ($ratingCount lượt)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: widget.onRetryStore,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Phân bố đánh giá',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (ratingCount == 0)
          Text(
            'Chưa có đánh giá nào.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          Column(
            children: [
              for (int star = 5; star >= 1; star--)
                _FeedbackStarBar(
                  star: star,
                  count: stats.starCount(star),
                  total: ratingCount,
                ),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          'Phản hồi theo món',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        // UX: khi có nhiều phản hồi, lọc theo sao + món để giảm việc phải
        // nhìn/đọc quá nhiều icon sao và nội dung.
        Row(
          children: [
            SizedBox(
              width: 170,
              child: _StarAutocomplete(
                selectedStar: _selectedStar,
                onSelectedStar: (value) {
                  setState(() {
                    _selectedStar = value;
                    // Đổi filter sao thì reset món để tránh trạng thái rỗng khó hiểu.
                    _selectedMenuItemId = null;
                  });
                },
                onClear: () {
                  setState(() => _selectedStar = null);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MenuAutocomplete(
                menuGroups: starGrouped,
                selectedMenuItemId: _selectedMenuItemId,
                onSelectedMenuItemId: (id) =>
                    setState(() => _selectedMenuItemId = id),
                onClear: () {
                  setState(() => _selectedMenuItemId = null);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        if (widget.data.reviews.isEmpty)
          Text(
            'Chưa có phản hồi nào.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else if (menuFilteredReviews.isEmpty)
          Text(
            'Không có phản hồi phù hợp bộ lọc.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...grouped.map((g) => _MenuItemFeedbackSection(group: g)),
      ],
    );
  }
}

class _MenuOption {
  const _MenuOption({required this.name, this.id});
  final String name;
  final String? id; // null = Tất cả
}

class _StarOption {
  const _StarOption({required this.name, this.value});
  final String name;
  final int? value; // null = tất cả
}

class _StarAutocomplete extends StatefulWidget {
  const _StarAutocomplete({
    required this.selectedStar,
    required this.onSelectedStar,
    required this.onClear,
  });

  final int? selectedStar;
  final ValueChanged<int?> onSelectedStar;
  final VoidCallback onClear;

  @override
  State<_StarAutocomplete> createState() => _StarAutocompleteState();
}

class _StarAutocompleteState extends State<_StarAutocomplete> {
  @override
  Widget build(BuildContext context) {
    final allOptions = <_StarOption>[
      const _StarOption(name: 'Tất cả', value: null),
      for (int star = 5; star >= 1; star--)
        _StarOption(name: '$star sao', value: star),
    ];

    return Autocomplete<_StarOption>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return allOptions;
        // UX: gõ chữ/số thì chỉ hiển thị các lựa chọn có tên bắt đầu bằng q.
        return allOptions
            .where((o) => o.name.toLowerCase().startsWith(q));
      },
      displayStringForOption: (option) => option.name,
      onSelected: (option) => widget.onSelectedStar(option.value),
      fieldViewBuilder: (context, textEditingController, focusNode,
          onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Sao',
            labelStyle: const TextStyle(color: Colors.black),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: widget.selectedStar == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, color: Colors.black54),
                    onPressed: () {
                      widget.onClear();
                      textEditingController.clear();
                      focusNode.unfocus();
                    },
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(
                  dense: true,
                  title: Text(
                    option.name,
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MenuAutocomplete extends StatefulWidget {
  const _MenuAutocomplete({
    required this.menuGroups,
    required this.selectedMenuItemId,
    required this.onSelectedMenuItemId,
    required this.onClear,
  });

  final List<_MenuItemReviewGroup> menuGroups;
  final String? selectedMenuItemId;
  final ValueChanged<String?> onSelectedMenuItemId;
  final VoidCallback onClear;

  @override
  State<_MenuAutocomplete> createState() => _MenuAutocompleteState();
}

class _MenuAutocompleteState extends State<_MenuAutocomplete> {
  @override
  Widget build(BuildContext context) {
    final allOptions = <_MenuOption>[
      const _MenuOption(name: 'Tất cả', id: null),
      ...widget.menuGroups.map(
        (g) => _MenuOption(name: g.menuItemName, id: g.menuItemId),
      ),
    ];

    return Autocomplete<_MenuOption>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return allOptions;
        // UX: gõ chữ thì dropdown chỉ hiển thị các món có tên bắt đầu bằng chữ đó.
        return allOptions.where((o) => o.name.toLowerCase().startsWith(q));
      },
      displayStringForOption: (option) => option.name,
      onSelected: (option) => widget.onSelectedMenuItemId(option.id),
      fieldViewBuilder: (context, textEditingController, focusNode,
          onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Món ăn',
            labelStyle: const TextStyle(color: Colors.black),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: widget.selectedMenuItemId == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, color: Colors.black54),
                    onPressed: () {
                      widget.onClear();
                      textEditingController.clear();
                      focusNode.unfocus();
                    },
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option.name,
                      style: const TextStyle(color: Colors.black),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItemReviewGroup {
  _MenuItemReviewGroup({
    required this.menuItemId,
    required this.menuItemName,
    required this.reviews,
  });

  final String menuItemId;
  final String menuItemName;
  final List<StoreReviewItem> reviews;
}

List<_MenuItemReviewGroup> _groupByMenuItem(List<StoreReviewItem> reviews) {
  final map = <String, List<StoreReviewItem>>{};
  final order = <String>[];
  for (final r in reviews) {
    final id = r.menuItemId.isEmpty ? r.menuItemName : r.menuItemId;
    if (!map.containsKey(id)) {
      order.add(id);
      map[id] = [];
    }
    map[id]!.add(r);
  }
  return order.map((id) {
    final list = map[id]!;
    final name = list.first.menuItemName;
    return _MenuItemReviewGroup(
      menuItemId: id,
      menuItemName: name,
      reviews: list,
    );
  }).toList();
}

class _MenuItemFeedbackSection extends StatefulWidget {
  const _MenuItemFeedbackSection({required this.group});
  final _MenuItemReviewGroup group;

  @override
  State<_MenuItemFeedbackSection> createState() =>
      _MenuItemFeedbackSectionState();
}

class _MenuItemFeedbackSectionState extends State<_MenuItemFeedbackSection> {
  static const int _maxVisible = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final avg = group.reviews.isEmpty
        ? 0.0
        : group.reviews.map((e) => e.rating).reduce((a, b) => a + b) /
            group.reviews.length;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final visibleReviews = _expanded
        ? group.reviews
        : group.reviews.take(_maxVisible).toList(growable: false);
    final hiddenCount = group.reviews.length - visibleReviews.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.menuItemName,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${avg.toStringAsFixed(1)} ★ • ${group.reviews.length} đánh giá (trong danh sách)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          for (final r in visibleReviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${r.rating} ★',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fmt.format(r.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (r.content == null || r.content!.trim().isEmpty)
                        ? 'Không có nội dung'
                        : r.content!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

          if (hiddenCount > 0)
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Xem thêm $hiddenCount phản hồi'),
            ),
        ],
      ),
    );
  }
}

class _FeedbackStarBar extends StatelessWidget {
  const _FeedbackStarBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$star ⭐',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              color: Colors.amber.shade700,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
