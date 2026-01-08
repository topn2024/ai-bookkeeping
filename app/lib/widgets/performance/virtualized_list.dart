import 'package:flutter/material.dart';

/// 虚拟化列表配置
class VirtualizedListConfig {
  /// 每项的预估高度
  final double estimatedItemHeight;

  /// 缓冲区大小（屏幕外保留的项数）
  final int bufferCount;

  /// 是否启用占位符
  final bool enablePlaceholder;

  /// 加载更多阈值
  final int loadMoreThreshold;

  /// 是否启用项缓存
  final bool enableItemCache;

  /// 缓存最大数量
  final int maxCacheCount;

  const VirtualizedListConfig({
    this.estimatedItemHeight = 60,
    this.bufferCount = 5,
    this.enablePlaceholder = true,
    this.loadMoreThreshold = 5,
    this.enableItemCache = true,
    this.maxCacheCount = 50,
  });
}

/// 虚拟化列表控制器
class VirtualizedListController extends ChangeNotifier {
  /// 当前可见范围
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;

  /// 滚动控制器
  final ScrollController scrollController = ScrollController();

  /// 获取第一个可见项索引
  int get firstVisibleIndex => _firstVisibleIndex;

  /// 获取最后一个可见项索引
  int get lastVisibleIndex => _lastVisibleIndex;

  /// 更新可见范围
  void updateVisibleRange(int first, int last) {
    if (_firstVisibleIndex != first || _lastVisibleIndex != last) {
      _firstVisibleIndex = first;
      _lastVisibleIndex = last;
      notifyListeners();
    }
  }

  /// 滚动到指定索引
  void scrollToIndex(int index, {Duration duration = const Duration(milliseconds: 300)}) {
    // 需要与具体实现配合
  }

  /// 刷新
  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

/// 高性能虚拟化列表
///
/// 核心功能：
/// 1. 只渲染可见区域的项
/// 2. 智能缓冲区管理
/// 3. 滚动性能优化
/// 4. 大数据集支持
///
/// 对应设计文档：第19章 性能设计与优化
/// 对应实施方案：轨道L 性能优化模块
class VirtualizedList<T> extends StatefulWidget {
  /// 数据列表
  final List<T> items;

  /// 项构建器
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 配置
  final VirtualizedListConfig config;

  /// 控制器
  final VirtualizedListController? controller;

  /// 加载更多回调
  final Future<void> Function()? onLoadMore;

  /// 是否正在加载
  final bool isLoading;

  /// 是否还有更多数据
  final bool hasMore;

  /// 加载指示器构建器
  final Widget Function(BuildContext context)? loadingBuilder;

  /// 空数据构建器
  final Widget Function(BuildContext context)? emptyBuilder;

  /// 占位符构建器
  final Widget Function(BuildContext context, int index)? placeholderBuilder;

  /// 分隔符构建器
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// 头部组件
  final Widget? header;

  /// 尾部组件
  final Widget? footer;

  /// 滚动物理效果
  final ScrollPhysics? physics;

  /// 内边距
  final EdgeInsets? padding;

  const VirtualizedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.config = const VirtualizedListConfig(),
    this.controller,
    this.onLoadMore,
    this.isLoading = false,
    this.hasMore = true,
    this.loadingBuilder,
    this.emptyBuilder,
    this.placeholderBuilder,
    this.separatorBuilder,
    this.header,
    this.footer,
    this.physics,
    this.padding,
  });

  @override
  State<VirtualizedList<T>> createState() => _VirtualizedListState<T>();
}

class _VirtualizedListState<T> extends State<VirtualizedList<T>> {
  late VirtualizedListController _controller;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VirtualizedListController();
    _controller.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    _checkLoadMore();
  }

  void _checkLoadMore() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) return;

    final position = _controller.scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // 计算是否接近底部
    final threshold = widget.config.estimatedItemHeight * widget.config.loadMoreThreshold;
    if (maxScroll - currentScroll <= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && !widget.isLoading) {
      return widget.emptyBuilder?.call(context) ??
          const Center(child: Text('暂无数据'));
    }

    return CustomScrollView(
      controller: _controller.scrollController,
      physics: widget.physics,
      slivers: [
        // 头部
        if (widget.header != null)
          SliverToBoxAdapter(child: widget.header),

        // 内边距
        if (widget.padding != null)
          SliverPadding(
            padding: EdgeInsets.only(
              top: widget.padding!.top,
              left: widget.padding!.left,
              right: widget.padding!.right,
            ),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

        // 主列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // 处理分隔符
              if (widget.separatorBuilder != null) {
                final itemIndex = index ~/ 2;
                if (index.isOdd) {
                  return widget.separatorBuilder!(context, itemIndex);
                }
                if (itemIndex >= widget.items.length) return null;
                return _buildItem(context, itemIndex);
              }

              if (index >= widget.items.length) return null;
              return _buildItem(context, index);
            },
            childCount: widget.separatorBuilder != null
                ? widget.items.length * 2 - 1
                : widget.items.length,
            addRepaintBoundaries: true,
            addAutomaticKeepAlives: false,
          ),
        ),

        // 加载指示器
        if (widget.isLoading || _isLoadingMore)
          SliverToBoxAdapter(
            child: widget.loadingBuilder?.call(context) ??
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
          ),

        // 底部内边距
        if (widget.padding != null)
          SliverPadding(
            padding: EdgeInsets.only(bottom: widget.padding!.bottom),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

        // 尾部
        if (widget.footer != null)
          SliverToBoxAdapter(child: widget.footer),
      ],
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = widget.items[index];

    return RepaintBoundary(
      child: widget.itemBuilder(context, item, index),
    );
  }
}

/// 虚拟化网格
class VirtualizedGrid<T> extends StatefulWidget {
  /// 数据列表
  final List<T> items;

  /// 项构建器
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 网格配置
  final SliverGridDelegate gridDelegate;

  /// 配置
  final VirtualizedListConfig config;

  /// 控制器
  final VirtualizedListController? controller;

  /// 加载更多回调
  final Future<void> Function()? onLoadMore;

  /// 是否正在加载
  final bool isLoading;

  /// 是否还有更多数据
  final bool hasMore;

  /// 内边距
  final EdgeInsets? padding;

  const VirtualizedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.config = const VirtualizedListConfig(),
    this.controller,
    this.onLoadMore,
    this.isLoading = false,
    this.hasMore = true,
    this.padding,
  });

  @override
  State<VirtualizedGrid<T>> createState() => _VirtualizedGridState<T>();
}

class _VirtualizedGridState<T> extends State<VirtualizedGrid<T>> {
  late VirtualizedListController _controller;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VirtualizedListController();
    _controller.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) return;

    final position = _controller.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _controller.scrollController,
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverGrid(
            gridDelegate: widget.gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= widget.items.length) return null;

                return RepaintBoundary(
                  child: widget.itemBuilder(context, widget.items[index], index),
                );
              },
              childCount: widget.items.length,
              addRepaintBoundaries: false, // 手动添加
              addAutomaticKeepAlives: false,
            ),
          ),
        ),

        // 加载指示器
        if (widget.isLoading || _isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// 带索引的虚拟化列表
class IndexedVirtualizedList<T> extends StatefulWidget {
  /// 数据列表
  final List<T> items;

  /// 项构建器
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 索引提取器
  final String Function(T item) indexExtractor;

  /// 索引构建器
  final Widget Function(BuildContext context, String index) indexBuilder;

  /// 配置
  final VirtualizedListConfig config;

  const IndexedVirtualizedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.indexExtractor,
    required this.indexBuilder,
    this.config = const VirtualizedListConfig(),
  });

  @override
  State<IndexedVirtualizedList<T>> createState() => _IndexedVirtualizedListState<T>();
}

class _IndexedVirtualizedListState<T> extends State<IndexedVirtualizedList<T>> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _indexKeys = {};
  String? _currentIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCurrentIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateCurrentIndex() {
    // 根据滚动位置更新当前索引
  }

  void _scrollToIndex(String index) {
    final key = _indexKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 按索引分组
    final groupedItems = <String, List<T>>{};
    for (final item in widget.items) {
      final index = widget.indexExtractor(item);
      groupedItems.putIfAbsent(index, () => []).add(item);
    }

    final indexes = groupedItems.keys.toList()..sort();

    return Row(
      children: [
        // 主列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: indexes.length,
            itemBuilder: (context, sectionIndex) {
              final index = indexes[sectionIndex];
              final items = groupedItems[index]!;

              _indexKeys[index] = GlobalKey();

              return Column(
                key: _indexKeys[index],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 索引头
                  widget.indexBuilder(context, index),
                  // 项列表
                  ...items.asMap().entries.map((entry) {
                    return RepaintBoundary(
                      child: widget.itemBuilder(context, entry.value, entry.key),
                    );
                  }),
                ],
              );
            },
          ),
        ),

        // 索引栏
        SizedBox(
          width: 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indexes.map((index) {
              final isActive = _currentIndex == index;
              return GestureDetector(
                onTap: () => _scrollToIndex(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    index,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 懒加载图片组件
class LazyImage extends StatefulWidget {
  /// 图片 URL
  final String url;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 填充模式
  final BoxFit? fit;

  /// 占位符
  final Widget? placeholder;

  /// 错误占位符
  final Widget? errorWidget;

  /// 是否启用缓存
  final bool enableCache;

  /// 淡入动画时长
  final Duration fadeInDuration;

  const LazyImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.enableCache = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: widget.fadeInDuration,
      crossFadeState: _isLoaded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      secondChild: _hasError
          ? (widget.errorWidget ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey[200],
                child: const Icon(Icons.error_outline, color: Colors.grey),
              ))
          : Image.network(
              widget.url,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null && !_isLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isLoaded = true;
                      });
                    }
                  });
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                if (!_hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasError = true;
                        _isLoaded = true;
                      });
                    }
                  });
                }
                return widget.errorWidget ??
                    Container(
                      width: widget.width,
                      height: widget.height,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error_outline, color: Colors.grey),
                    );
              },
            ),
    );
  }
}
