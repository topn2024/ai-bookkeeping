import 'dart:math' show min;
import 'dart:typed_data';

/// 音频环形缓冲区
///
/// 用于优化音频流处理，防止内存溢出和数据丢失
class AudioCircularBuffer {
  final int maxSize;
  final Uint8List _buffer;
  int _writePos = 0;
  int _readPos = 0;
  int _availableBytes = 0;

  AudioCircularBuffer({this.maxSize = 32000}) : _buffer = Uint8List(maxSize);

  /// 当前可读数据量
  int get available => _availableBytes;

  /// 缓冲区是否已满
  bool get isFull => _availableBytes >= maxSize;

  /// 缓冲区是否为空
  bool get isEmpty => _availableBytes == 0;

  /// 写入数据到缓冲区
  ///
  /// 如果缓冲区满，会覆盖最旧的数据
  void write(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      _buffer[_writePos] = data[i];
      _writePos = (_writePos + 1) % maxSize;

      if (_availableBytes < maxSize) {
        _availableBytes++;
      } else {
        // 缓冲区满，移动读取位置（丢弃最旧数据）
        _readPos = (_readPos + 1) % maxSize;
      }
    }
  }

  /// 读取指定长度的数据
  ///
  /// 返回实际读取的数据（可能少于请求的长度）
  Uint8List read(int length) {
    final actualLength = min(length, _availableBytes);
    final result = Uint8List(actualLength);

    for (var i = 0; i < actualLength; i++) {
      result[i] = _buffer[_readPos];
      _readPos = (_readPos + 1) % maxSize;
    }

    _availableBytes -= actualLength;
    return result;
  }

  /// 查看数据但不移动读取位置
  Uint8List peek(int length) {
    final actualLength = min(length, _availableBytes);
    final result = Uint8List(actualLength);
    var tempPos = _readPos;

    for (var i = 0; i < actualLength; i++) {
      result[i] = _buffer[tempPos];
      tempPos = (tempPos + 1) % maxSize;
    }

    return result;
  }

  /// 清空缓冲区
  void clear() {
    _writePos = 0;
    _readPos = 0;
    _availableBytes = 0;
  }

  /// 获取所有可用数据
  Uint8List readAll() {
    return read(_availableBytes);
  }
}

/// 音频列表缓冲区
///
/// 简单的列表缓冲区，用于缓存音频块
class AudioListBuffer {
  final List<Uint8List> _chunks = [];
  final int maxChunks;
  int _totalBytes = 0;

  AudioListBuffer({this.maxChunks = 100});

  /// 添加音频块
  void add(Uint8List chunk) {
    if (_chunks.length >= maxChunks) {
      // 移除最旧的块
      final removed = _chunks.removeAt(0);
      _totalBytes -= removed.length;
    }
    _chunks.add(chunk);
    _totalBytes += chunk.length;
  }

  /// 获取所有缓冲的数据
  Uint8List getAll() {
    if (_chunks.isEmpty) return Uint8List(0);

    final result = Uint8List(_totalBytes);
    var offset = 0;
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  /// 获取缓冲块列表
  List<Uint8List> get chunks => List.unmodifiable(_chunks);

  /// 总字节数
  int get totalBytes => _totalBytes;

  /// 块数量
  int get length => _chunks.length;

  /// 是否为空
  bool get isEmpty => _chunks.isEmpty;

  /// 清空缓冲区
  void clear() {
    _chunks.clear();
    _totalBytes = 0;
  }
}
