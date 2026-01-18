import 'dart:math';

/// 拉普拉斯噪声生成器
///
/// 实现差分隐私中的拉普拉斯机制，用于为敏感数据添加噪声。
/// 使用逆变换采样方法生成符合拉普拉斯分布的随机噪声。
///
/// 拉普拉斯分布公式：
/// ```
/// X = μ - b * sign(U - 0.5) * ln(1 - 2|U - 0.5|)
/// ```
/// 其中：
/// - μ (mu) 是分布的位置参数（中心）
/// - b 是尺度参数，b = Δf/ε (敏感度/epsilon)
/// - U 是均匀分布 [0, 1) 的随机数
class LaplacianNoiseGenerator {
  final Random _random;

  /// 创建拉普拉斯噪声生成器
  ///
  /// [seed] 可选的随机种子，用于可重复的测试
  LaplacianNoiseGenerator({int? seed}) : _random = Random(seed);

  /// 生成单个拉普拉斯噪声值
  ///
  /// [sensitivity] 查询的敏感度 Δf
  /// [epsilon] 隐私参数 ε（越小隐私保护越强）
  /// [mu] 分布中心，默认为 0
  ///
  /// 返回符合 Laplace(μ, Δf/ε) 分布的随机噪声
  double generate({
    required double sensitivity,
    required double epsilon,
    double mu = 0.0,
  }) {
    if (epsilon <= 0) {
      throw ArgumentError('epsilon must be positive, got $epsilon');
    }
    if (sensitivity < 0) {
      throw ArgumentError('sensitivity must be non-negative, got $sensitivity');
    }

    // 如果敏感度为0，不需要添加噪声
    if (sensitivity == 0) {
      return 0.0;
    }

    // 计算尺度参数 b = Δf/ε
    final b = sensitivity / epsilon;

    // 生成均匀分布随机数 U ∈ (0, 1)
    // 避免 U = 0 或 U = 1 导致 ln(0) 的问题
    double u;
    do {
      u = _random.nextDouble();
    } while (u == 0.0 || u == 1.0);

    // 逆变换采样
    // X = μ - b * sign(U - 0.5) * ln(1 - 2|U - 0.5|)
    final diff = u - 0.5;
    final sign = diff < 0 ? -1.0 : 1.0;
    final noise = mu - b * sign * log(1 - 2 * diff.abs());

    return noise;
  }

  /// 生成带边界约束的拉普拉斯噪声
  ///
  /// 噪声会被裁剪到 [minBound, maxBound] 范围内
  /// 注意：这会稍微影响差分隐私保证
  double generateBounded({
    required double sensitivity,
    required double epsilon,
    double mu = 0.0,
    double? minBound,
    double? maxBound,
  }) {
    final noise = generate(
      sensitivity: sensitivity,
      epsilon: epsilon,
      mu: mu,
    );

    double result = noise;
    if (minBound != null && result < minBound) {
      result = minBound;
    }
    if (maxBound != null && result > maxBound) {
      result = maxBound;
    }

    return result;
  }

  /// 为数值添加拉普拉斯噪声
  ///
  /// [value] 原始数值
  /// [sensitivity] 查询敏感度
  /// [epsilon] 隐私参数
  /// [minValue] 可选的最小值约束
  /// [maxValue] 可选的最大值约束
  double addNoise({
    required double value,
    required double sensitivity,
    required double epsilon,
    double? minValue,
    double? maxValue,
  }) {
    final noise = generate(
      sensitivity: sensitivity,
      epsilon: epsilon,
    );

    double result = value + noise;

    // 应用边界约束
    if (minValue != null && result < minValue) {
      result = minValue;
    }
    if (maxValue != null && result > maxValue) {
      result = maxValue;
    }

    return result;
  }

  /// 批量生成噪声
  ///
  /// [count] 需要生成的噪声数量
  /// [sensitivity] 查询敏感度
  /// [epsilon] 隐私参数
  List<double> generateBatch({
    required int count,
    required double sensitivity,
    required double epsilon,
  }) {
    return List.generate(
      count,
      (_) => generate(sensitivity: sensitivity, epsilon: epsilon),
    );
  }

  /// 计算给定参数下的噪声方差
  ///
  /// 拉普拉斯分布的方差为 2b²
  static double calculateVariance({
    required double sensitivity,
    required double epsilon,
  }) {
    final b = sensitivity / epsilon;
    return 2 * b * b;
  }

  /// 计算给定参数下的噪声标准差
  static double calculateStdDev({
    required double sensitivity,
    required double epsilon,
  }) {
    return sqrt(calculateVariance(sensitivity: sensitivity, epsilon: epsilon));
  }

  /// 计算达到 (ε, δ)-差分隐私所需的噪声尺度
  ///
  /// 对于纯 ε-差分隐私，δ = 0
  /// 对于近似差分隐私，δ > 0 允许更小的噪声
  static double calculateRequiredScale({
    required double sensitivity,
    required double epsilon,
    double delta = 0.0,
  }) {
    if (delta == 0) {
      // 纯 ε-差分隐私
      return sensitivity / epsilon;
    } else {
      // (ε, δ)-差分隐私，可以使用更小的尺度
      // 这里使用简化的计算
      return sensitivity / (epsilon + log(1 / delta));
    }
  }
}
