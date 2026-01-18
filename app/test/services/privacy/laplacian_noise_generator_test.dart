import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/privacy/differential_privacy/laplacian_noise_generator.dart';

void main() {
  group('LaplacianNoiseGenerator', () {
    late LaplacianNoiseGenerator generator;

    setUp(() {
      // 使用固定种子以确保测试可重复
      generator = LaplacianNoiseGenerator(seed: 42);
    });

    group('generate', () {
      test('应该生成噪声值', () {
        final noise = generator.generate(
          sensitivity: 1.0,
          epsilon: 1.0,
        );

        expect(noise, isA<double>());
        expect(noise.isFinite, isTrue);
      });

      test('敏感度为0时应返回0', () {
        final noise = generator.generate(
          sensitivity: 0.0,
          epsilon: 1.0,
        );

        expect(noise, equals(0.0));
      });

      test('epsilon为负数时应抛出异常', () {
        expect(
          () => generator.generate(sensitivity: 1.0, epsilon: -1.0),
          throwsArgumentError,
        );
      });

      test('epsilon为0时应抛出异常', () {
        expect(
          () => generator.generate(sensitivity: 1.0, epsilon: 0.0),
          throwsArgumentError,
        );
      });

      test('敏感度为负数时应抛出异常', () {
        expect(
          () => generator.generate(sensitivity: -1.0, epsilon: 1.0),
          throwsArgumentError,
        );
      });

      test('较小的epsilon应产生较大的噪声方差', () {
        // 生成大量样本来估计方差
        const sampleSize = 10000;
        final sensitivity = 1.0;

        // epsilon = 0.1 的噪声
        final smallEpsilonSamples = List.generate(
          sampleSize,
          (_) => generator.generate(sensitivity: sensitivity, epsilon: 0.1),
        );

        // epsilon = 1.0 的噪声
        final largeEpsilonSamples = List.generate(
          sampleSize,
          (_) => generator.generate(sensitivity: sensitivity, epsilon: 1.0),
        );

        final smallEpsilonVariance = _calculateVariance(smallEpsilonSamples);
        final largeEpsilonVariance = _calculateVariance(largeEpsilonSamples);

        // 较小的 epsilon 应该有更大的方差
        expect(smallEpsilonVariance, greaterThan(largeEpsilonVariance));
      });

      test('噪声均值应接近0', () {
        const sampleSize = 10000;
        final samples = List.generate(
          sampleSize,
          (_) => generator.generate(sensitivity: 1.0, epsilon: 1.0),
        );

        final mean = samples.reduce((a, b) => a + b) / sampleSize;

        // 均值应该接近0（允许一些统计误差）
        expect(mean.abs(), lessThan(0.1));
      });
    });

    group('generateBounded', () {
      test('应该将噪声裁剪到指定范围', () {
        for (var i = 0; i < 100; i++) {
          final noise = generator.generateBounded(
            sensitivity: 10.0,
            epsilon: 0.1,
            minBound: -1.0,
            maxBound: 1.0,
          );

          expect(noise, greaterThanOrEqualTo(-1.0));
          expect(noise, lessThanOrEqualTo(1.0));
        }
      });

      test('只设置下界时应该正确裁剪', () {
        for (var i = 0; i < 100; i++) {
          final noise = generator.generateBounded(
            sensitivity: 10.0,
            epsilon: 0.1,
            minBound: 0.0,
          );

          expect(noise, greaterThanOrEqualTo(0.0));
        }
      });

      test('只设置上界时应该正确裁剪', () {
        for (var i = 0; i < 100; i++) {
          final noise = generator.generateBounded(
            sensitivity: 10.0,
            epsilon: 0.1,
            maxBound: 0.0,
          );

          expect(noise, lessThanOrEqualTo(0.0));
        }
      });
    });

    group('addNoise', () {
      test('应该给数值添加噪声', () {
        final originalValue = 0.5;
        final noisyValue = generator.addNoise(
          value: originalValue,
          sensitivity: 1.0,
          epsilon: 1.0,
        );

        // 加噪后的值应该与原值不同（大概率）
        expect(noisyValue, isA<double>());
      });

      test('应该尊重边界约束', () {
        for (var i = 0; i < 100; i++) {
          final noisyValue = generator.addNoise(
            value: 0.5,
            sensitivity: 1.0,
            epsilon: 0.1,
            minValue: 0.0,
            maxValue: 1.0,
          );

          expect(noisyValue, greaterThanOrEqualTo(0.0));
          expect(noisyValue, lessThanOrEqualTo(1.0));
        }
      });
    });

    group('generateBatch', () {
      test('应该生成指定数量的噪声值', () {
        final batch = generator.generateBatch(
          count: 100,
          sensitivity: 1.0,
          epsilon: 1.0,
        );

        expect(batch.length, equals(100));
        for (final noise in batch) {
          expect(noise.isFinite, isTrue);
        }
      });
    });

    group('静态方法', () {
      test('calculateVariance 应该正确计算方差', () {
        final variance = LaplacianNoiseGenerator.calculateVariance(
          sensitivity: 1.0,
          epsilon: 1.0,
        );

        // 拉普拉斯分布方差 = 2 * b^2，其中 b = sensitivity / epsilon = 1
        expect(variance, equals(2.0));
      });

      test('calculateStdDev 应该正确计算标准差', () {
        final stdDev = LaplacianNoiseGenerator.calculateStdDev(
          sensitivity: 1.0,
          epsilon: 1.0,
        );

        expect(stdDev, equals(sqrt(2.0)));
      });
    });
  });
}

double _calculateVariance(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  final squaredDiffs = values.map((v) => pow(v - mean, 2));
  return squaredDiffs.reduce((a, b) => a + b) / values.length;
}
