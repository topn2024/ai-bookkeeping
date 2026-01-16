/// 文本相似度计算器
///
/// 用于打断检测和回声过滤中的文本相似度计算。
/// 使用多种算法综合计算相似度，平衡准确性和性能。
class SimilarityCalculator {
  /// 计算两段文本的相似度
  ///
  /// 返回值：0.0（完全不同）~ 1.0（完全相同）
  ///
  /// 算法优先级：
  /// 1. 子串匹配（最高优先级，直接返回1.0）
  /// 2. Jaccard相似度（字符集合交并比）
  /// 3. 最长公共子串比率
  double calculate(String text1, String text2) {
    final clean1 = _normalize(text1);
    final clean2 = _normalize(text2);

    if (clean1.isEmpty || clean2.isEmpty) return 0.0;
    if (clean1 == clean2) return 1.0;

    // 1. 子串匹配（最高优先级）
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      return 1.0;
    }

    // 2. Jaccard相似度（字符级别）
    final jaccard = _calculateJaccard(clean1, clean2);

    // 3. 最长公共子串比率
    final lcsRatio = _calculateLCSRatio(clean1, clean2);

    // 取最大值
    return jaccard > lcsRatio ? jaccard : lcsRatio;
  }

  /// 快速相似度检查（用于高频调用场景）
  ///
  /// 只做简单检查，性能更好
  bool isHighlySimilar(String text1, String text2, {double threshold = 0.5}) {
    final clean1 = _normalize(text1);
    final clean2 = _normalize(text2);

    if (clean1.isEmpty || clean2.isEmpty) return false;
    if (clean1 == clean2) return true;

    // 快速子串检查
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      return true;
    }

    // 快速Jaccard检查
    final jaccard = _calculateJaccard(clean1, clean2);
    return jaccard > threshold;
  }

  /// 检查是否为前缀匹配（用于回声检测）
  ///
  /// 检查text是否与reference的开头高度相似
  bool isPrefixMatch(String text, String reference, {double threshold = 0.8}) {
    final cleanText = _normalize(text);
    final cleanRef = _normalize(reference);

    if (cleanText.isEmpty || cleanRef.isEmpty) return false;

    // 取reference的前缀（与text等长）
    final prefixLen = cleanText.length < cleanRef.length
        ? cleanText.length
        : cleanRef.length;
    final refPrefix = cleanRef.substring(0, prefixLen);

    // 计算与前缀的相似度
    return calculate(cleanText, refPrefix) > threshold;
  }

  /// 标准化文本
  ///
  /// 移除标点符号和空白字符，转换为小写
  String _normalize(String text) {
    // 移除中英文标点和空白
    // 注意：在字符类中，- 放在开头或结尾避免被解析为范围
    final punctuation = RegExp(r'[-。，！？；、：""''（）【】《》,.!?;:\s\[\]()\'"]');
    return text.replaceAll(punctuation, '').toLowerCase();
  }

  /// 计算Jaccard相似度
  ///
  /// Jaccard = |A ∩ B| / |A ∪ B|
  double _calculateJaccard(String s1, String s2) {
    final set1 = s1.split('').toSet();
    final set2 = s2.split('').toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// 计算最长公共子串比率
  ///
  /// 使用滑动窗口算法，时间复杂度 O(m*n)
  double _calculateLCSRatio(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final m = s1.length;
    final n = s2.length;
    var maxLen = 0;

    // 滑动窗口查找最长公共子串
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var len = 0;
        while (i + len < m && j + len < n && s1[i + len] == s2[j + len]) {
          len++;
        }
        if (len > maxLen) {
          maxLen = len;
        }
      }
    }

    // 返回相对于较短字符串的比率
    final minLen = m < n ? m : n;
    return minLen > 0 ? maxLen / minLen : 0.0;
  }
}
