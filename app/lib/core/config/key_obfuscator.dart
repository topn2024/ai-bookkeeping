/// 密钥运行时解混淆工具
///
/// 使用多层XOR + 字节分散存储，避免密钥以明文形式出现在二进制中。
/// 配合 Flutter 的 --obfuscate 编译选项和 Android ProGuard 使用。
library;

import 'dart:typed_data';

/// 运行时密钥解混淆器
class KeyDeobfuscator {
  KeyDeobfuscator._();

  /// 多层XOR解密
  /// [encBytes] 加密后的字节数组
  /// [mask1] 第一层掩码
  /// [mask2] 第二层掩码
  static String decode(List<int> encBytes, List<int> mask1, List<int> mask2) {
    final len = encBytes.length;
    final result = Uint8List(len);
    for (int i = 0; i < len; i++) {
      // 双层XOR: original = enc ^ mask1[i%len1] ^ mask2[i%len2]
      result[i] = encBytes[i] ^ mask1[i % mask1.length] ^ mask2[i % mask2.length];
    }
    return String.fromCharCodes(result);
  }
}
