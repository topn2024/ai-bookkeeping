import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel_pkg;

/// 水印配置
class WatermarkConfig {
  /// 水印文本
  final String text;

  /// 水印位置
  final WatermarkPosition position;

  /// 字体大小
  final double fontSize;

  /// 字体颜色
  final Color color;

  /// 透明度（0-1）
  final double opacity;

  /// 旋转角度（度数）
  final double rotation;

  const WatermarkConfig({
    required this.text,
    this.position = WatermarkPosition.bottomRight,
    this.fontSize = 12.0,
    this.color = Colors.grey,
    this.opacity = 0.5,
    this.rotation = 0.0,
  });
}

/// 水印位置
enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

/// 图表截图选项
class ChartCaptureOptions {
  /// 图片格式
  final ImageFormat format;

  /// 图片质量（仅PNG有效，0-100）
  final int quality;

  /// 背景颜色（null表示透明）
  final Color? backgroundColor;

  /// 是否添加水印
  final bool addWatermark;

  /// 水印配置
  final WatermarkConfig? watermarkConfig;

  /// 图片缩放比例
  final double pixelRatio;

  const ChartCaptureOptions({
    this.format = ImageFormat.png,
    this.quality = 100,
    this.backgroundColor,
    this.addWatermark = false,
    this.watermarkConfig,
    this.pixelRatio = 3.0,
  });
}

/// 图片格式
enum ImageFormat {
  png,
  jpg,
}

/// 分享选项
class ShareOptions {
  /// 分享文本
  final String? text;

  /// 分享主题
  final String? subject;

  /// MIME类型
  final String? mimeType;

  const ShareOptions({
    this.text,
    this.subject,
    this.mimeType,
  });
}

/// 截图结果
class CaptureResult {
  /// 是否成功
  final bool success;

  /// 图片文件路径
  final String? filePath;

  /// 图片数据
  final Uint8List? imageBytes;

  /// 错误信息
  final String? error;

  const CaptureResult({
    required this.success,
    this.filePath,
    this.imageBytes,
    this.error,
  });

  factory CaptureResult.success(String filePath, Uint8List bytes) {
    return CaptureResult(
      success: true,
      filePath: filePath,
      imageBytes: bytes,
    );
  }

  factory CaptureResult.failure(String error) {
    return CaptureResult(
      success: false,
      error: error,
    );
  }
}

/// 图表截图与分享服务
///
/// 核心功能：
/// 1. 截取Widget为图片
/// 2. 添加水印
/// 3. 保存到本地
/// 4. 分享到其他应用
///
/// 对应设计文档：第12.8节 数据导出与分享
///
/// 使用示例：
/// ```dart
/// // 1. 给Widget添加GlobalKey
/// final chartKey = GlobalKey();
/// Container(
///   key: chartKey,
///   child: PieChart(...),
/// );
///
/// // 2. 截图并分享
/// final service = ChartCaptureService();
/// final result = await service.captureWidget(
///   key: chartKey,
///   options: ChartCaptureOptions(
///     addWatermark: true,
///     watermarkConfig: WatermarkConfig(
///       text: 'AI智能记账',
///     ),
///   ),
/// );
///
/// if (result.success) {
///   await service.shareImage(
///     filePath: result.filePath!,
///     options: ShareOptions(
///       text: '我的消费分析',
///     ),
///   );
/// }
/// ```
class ChartCaptureService {
  /// 截取Widget
  Future<CaptureResult> captureWidget({
    required GlobalKey key,
    ChartCaptureOptions? options,
  }) async {
    final opts = options ?? const ChartCaptureOptions();

    try {
      // 获取RenderObject
      final RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        return CaptureResult.failure('无法找到要截图的组件');
      }

      // 等待渲染完成
      await Future.delayed(const Duration(milliseconds: 50));

      // 截图
      final ui.Image image = await boundary.toImage(
        pixelRatio: opts.pixelRatio,
      );

      // 添加背景色
      ui.Image finalImage = image;
      if (opts.backgroundColor != null) {
        finalImage = await _addBackgroundColor(image, opts.backgroundColor!);
      }

      // 添加水印
      if (opts.addWatermark && opts.watermarkConfig != null) {
        finalImage = await _addWatermark(finalImage, opts.watermarkConfig!);
      }

      // 转换为字节
      final ByteData? byteData = await finalImage.toByteData(
        format: opts.format == ImageFormat.png
            ? ui.ImageByteFormat.png
            : ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        return CaptureResult.failure('图片转换失败');
      }

      final Uint8List bytes = byteData.buffer.asUint8List();

      // 保存到临时目录
      final filePath = await _saveToFile(bytes, opts.format);

      return CaptureResult.success(filePath, bytes);
    } catch (e) {
      return CaptureResult.failure('截图失败: $e');
    }
  }

  /// 添加背景色
  Future<ui.Image> _addBackgroundColor(ui.Image image, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Paint()..color = color,
    );

    // 绘制原图
    canvas.drawImage(image, Offset.zero, Paint());

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }

  /// 添加水印
  Future<ui.Image> _addWatermark(
    ui.Image image,
    WatermarkConfig config,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制原图
    canvas.drawImage(image, Offset.zero, Paint());

    // 计算水印位置
    final textPainter = TextPainter(
      text: TextSpan(
        text: config.text,
        style: TextStyle(
          color: config.color.withOpacity(config.opacity),
          fontSize: config.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final offset = _calculateWatermarkOffset(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      textSize: textPainter.size,
      position: config.position,
    );

    // 保存画布状态
    canvas.save();

    // 移动到水印位置
    canvas.translate(offset.dx, offset.dy);

    // 旋转
    if (config.rotation != 0) {
      canvas.rotate(config.rotation * (3.14159 / 180)); // 转换为弧度
    }

    // 绘制水印
    textPainter.paint(canvas, Offset.zero);

    // 恢复画布状态
    canvas.restore();

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }

  /// 计算水印位置
  Offset _calculateWatermarkOffset({
    required Size imageSize,
    required Size textSize,
    required WatermarkPosition position,
  }) {
    const padding = 10.0;

    switch (position) {
      case WatermarkPosition.topLeft:
        return Offset(padding, padding);

      case WatermarkPosition.topRight:
        return Offset(
          imageSize.width - textSize.width - padding,
          padding,
        );

      case WatermarkPosition.bottomLeft:
        return Offset(
          padding,
          imageSize.height - textSize.height - padding,
        );

      case WatermarkPosition.bottomRight:
        return Offset(
          imageSize.width - textSize.width - padding,
          imageSize.height - textSize.height - padding,
        );

      case WatermarkPosition.center:
        return Offset(
          (imageSize.width - textSize.width) / 2,
          (imageSize.height - textSize.height) / 2,
        );
    }
  }

  /// 保存到文件
  Future<String> _saveToFile(Uint8List bytes, ImageFormat format) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == ImageFormat.png ? 'png' : 'jpg';
    final fileName = 'chart_$timestamp.$extension';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  /// 分享图片
  Future<void> shareImage({
    required String filePath,
    ShareOptions? options,
  }) async {
    final opts = options ?? const ShareOptions();

    try {
      final xFile = XFile(filePath);

      await Share.shareXFiles(
        [xFile],
        text: opts.text,
        subject: opts.subject,
      );
    } catch (e) {
      throw Exception('分享失败: $e');
    }
  }

  /// 保存到相册
  Future<bool> saveToGallery(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result != null && result['isSuccess'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 保存图片字节到相册
  Future<bool> saveImageBytesToGallery(Uint8List bytes, {String? name}) async {
    try {
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: name ?? 'chart_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result != null && result['isSuccess'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 批量截图
  Future<List<CaptureResult>> captureMultiple({
    required List<GlobalKey> keys,
    ChartCaptureOptions? options,
  }) async {
    final results = <CaptureResult>[];

    for (final key in keys) {
      final result = await captureWidget(key: key, options: options);
      results.add(result);

      // 添加延迟避免性能问题
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return results;
  }

  /// 创建带数据的分享图片
  Future<CaptureResult> createShareableChart({
    required GlobalKey chartKey,
    required String title,
    required Map<String, String> dataPoints,
    ChartCaptureOptions? options,
  }) async {
    // 先截取原图
    final chartResult = await captureWidget(
      key: chartKey,
      options: options,
    );

    if (!chartResult.success || chartResult.imageBytes == null) {
      return chartResult;
    }

    try {
      // 解码原图
      final codec = await ui.instantiateImageCodec(chartResult.imageBytes!);
      final frame = await codec.getNextFrame();
      final chartImage = frame.image;

      // 创建新画布（增加顶部空间用于标题和数据）
      final headerHeight = 100.0;
      final totalHeight = chartImage.height.toDouble() + headerHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 绘制背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, chartImage.width.toDouble(), totalHeight),
        Paint()..color = Colors.white,
      );

      // 绘制标题
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      titlePainter.layout();
      titlePainter.paint(canvas, const Offset(20, 20));

      // 绘制数据点
      double yOffset = 60;
      for (final entry in dataPoints.entries) {
        final dataPainter = TextPainter(
          text: TextSpan(
            text: '${entry.key}: ${entry.value}',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        dataPainter.layout();
        dataPainter.paint(canvas, Offset(20, yOffset));
        yOffset += 20;
      }

      // 绘制原图
      canvas.drawImage(
        chartImage,
        Offset(0, headerHeight),
        Paint(),
      );

      // 转换为图片
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        chartImage.width,
        totalHeight.toInt(),
      );

      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return CaptureResult.failure('图片生成失败');
      }

      final bytes = byteData.buffer.asUint8List();
      final filePath = await _saveToFile(bytes, ImageFormat.png);

      return CaptureResult.success(filePath, bytes);
    } catch (e) {
      return CaptureResult.failure('创建分享图片失败: $e');
    }
  }

  /// 清理临时文件
  Future<void> cleanupTempFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();

      for (final file in files) {
        if (file is File && file.path.contains('chart_')) {
          try {
            await file.delete();
          } catch (e) {
            // 忽略删除错误
          }
        }
      }
    } catch (e) {
      // 忽略清理错误
    }
  }

  /// 导出图表为PDF
  Future<String> exportToPDF({
    required GlobalKey chartKey,
    required String title,
    Map<String, String>? dataPoints,
    ChartCaptureOptions? options,
  }) async {
    // 先截取图表
    final chartResult = await captureWidget(
      key: chartKey,
      options: options,
    );

    if (!chartResult.success || chartResult.imageBytes == null) {
      throw Exception('图表截图失败: ${chartResult.error}');
    }

    // 创建PDF文档
    final pdf = pw.Document();

    // 转换为PDF图片格式
    final image = pw.MemoryImage(chartResult.imageBytes!);

    // 添加页面
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 标题
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // 数据点（如果有）
              if (dataPoints != null && dataPoints.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: dataPoints.entries.map((entry) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          '${entry.key}: ${entry.value}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // 图表图片
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),

              // 页脚
              pw.SizedBox(height: 10),
              pw.Text(
                '生成时间: ${DateTime.now().toString().substring(0, 19)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.Text(
                '由 AI智能记账 生成',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    // 保存PDF文件
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/chart_$timestamp.pdf';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// 批量导出为PDF
  Future<String> exportMultipleToPDF({
    required List<GlobalKey> chartKeys,
    required List<String> titles,
    required String documentTitle,
    Map<String, String>? summary,
    ChartCaptureOptions? options,
  }) async {
    if (chartKeys.length != titles.length) {
      throw ArgumentError('chartKeys and titles must have the same length');
    }

    final pdf = pw.Document();

    // 添加封面
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  documentTitle,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  DateTime.now().toString().substring(0, 10),
                  style: const pw.TextStyle(fontSize: 16),
                ),
                if (summary != null && summary.isNotEmpty) ...[
                  pw.SizedBox(height: 40),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: summary.entries.map((entry) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text(
                            '${entry.key}: ${entry.value}',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    // 为每个图表添加页面
    for (int i = 0; i < chartKeys.length; i++) {
      final chartResult = await captureWidget(
        key: chartKeys[i],
        options: options,
      );

      if (chartResult.success && chartResult.imageBytes != null) {
        final image = pw.MemoryImage(chartResult.imageBytes!);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    titles[i],
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // 添加延迟避免性能问题
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 保存PDF文件
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/charts_$timestamp.pdf';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }
}

/// 图表导出服务
/// 支持导出为Excel、PDF等格式
class ChartExportService {
  /// 导出为CSV
  Future<String> exportToCSV({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final buffer = StringBuffer();

    // 添加BOM for Excel
    buffer.write('\uFEFF');

    // 标题
    buffer.writeln(title);
    buffer.writeln('');

    // 表头
    buffer.writeln(headers.join(','));

    // 数据行
    for (final row in rows) {
      buffer.writeln(row.map((cell) => _escapeCSV(cell.toString())).join(','));
    }

    // 保存文件
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/export_$timestamp.csv';

    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 导出为JSON
  Future<String> exportToJSON(Map<String, dynamic> data) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/export_$timestamp.json';

    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );

    return filePath;
  }

  /// 导出为Excel（带格式）
  Future<String> exportToExcel({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? sheetName,
  }) async {
    final excel = excel_pkg.Excel.createExcel();

    // 删除默认的Sheet1
    excel.delete('Sheet1');

    // 创建工作表
    final sheet = excel[sheetName ?? 'Data'];

    // 设置列宽
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15);
    }

    // 添加标题行（合并单元格）
    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: headers.length - 1,
        rowIndex: 0,
      ),
    );

    final titleCell = sheet.cell(
      excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = excel_pkg.TextCellValue(title);
    titleCell.cellStyle = excel_pkg.CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
    );

    // 添加表头
    for (int i = 0; i < headers.length; i++) {
      final headerCell = sheet.cell(
        excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
      headerCell.value = excel_pkg.TextCellValue(headers[i]);
      headerCell.cellStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: excel_pkg.ExcelColor.blue200,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
        verticalAlign: excel_pkg.VerticalAlign.Center,
      );
    }

    // 添加数据行
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        final dataCell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 3,
          ),
        );

        final value = row[colIndex];

        // 根据数据类型设置单元格值
        if (value is num) {
          dataCell.value = excel_pkg.DoubleCellValue(value.toDouble());
          dataCell.cellStyle = excel_pkg.CellStyle(
            horizontalAlign: excel_pkg.HorizontalAlign.Right,
          );
        } else if (value is DateTime) {
          dataCell.value = excel_pkg.DateTimeCellValue(
            year: value.year,
            month: value.month,
            day: value.day,
            hour: value.hour,
            minute: value.minute,
            second: value.second,
          );
        } else {
          dataCell.value = excel_pkg.TextCellValue(value.toString());
        }

        // 斑马纹效果
        if (rowIndex % 2 == 1) {
          dataCell.cellStyle = excel_pkg.CellStyle(
            backgroundColorHex: excel_pkg.ExcelColor.gray100,
          );
        }
      }
    }

    // 添加页脚（生成时间）
    final footerRow = rows.length + 4;
    final footerCell = sheet.cell(
      excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerRow),
    );
    footerCell.value = excel_pkg.TextCellValue(
      '生成时间: ${DateTime.now().toString().substring(0, 19)}',
    );
    footerCell.cellStyle = excel_pkg.CellStyle(
      fontSize: 10,
      fontColorHex: excel_pkg.ExcelColor.gray,
      italic: true,
    );

    // 保存文件
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/export_$timestamp.xlsx';

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    } else {
      throw Exception('Excel文件生成失败');
    }
  }

  /// 导出多表格Excel
  Future<String> exportToExcelMultiSheet({
    required String title,
    required Map<String, Map<String, dynamic>> sheets,
  }) async {
    final excel = excel_pkg.Excel.createExcel();

    // 删除默认的Sheet1
    excel.delete('Sheet1');

    for (final entry in sheets.entries) {
      final sheetName = entry.key;
      final sheetData = entry.value;
      final headers = sheetData['headers'] as List<String>;
      final rows = sheetData['rows'] as List<List<dynamic>>;

      // 创建工作表
      final sheet = excel[sheetName];

      // 设置列宽
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      // 添加表头
      for (int i = 0; i < headers.length; i++) {
        final headerCell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        headerCell.value = excel_pkg.TextCellValue(headers[i]);
        headerCell.cellStyle = excel_pkg.CellStyle(
          bold: true,
          fontSize: 12,
          backgroundColorHex: excel_pkg.ExcelColor.blue200,
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
        );
      }

      // 添加数据行
      for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        for (int colIndex = 0; colIndex < row.length; colIndex++) {
          final dataCell = sheet.cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1,
            ),
          );

          final value = row[colIndex];

          if (value is num) {
            dataCell.value = excel_pkg.DoubleCellValue(value.toDouble());
            dataCell.cellStyle = excel_pkg.CellStyle(
              horizontalAlign: excel_pkg.HorizontalAlign.Right,
            );
          } else {
            dataCell.value = excel_pkg.TextCellValue(value.toString());
          }

          // 斑马纹效果
          if (rowIndex % 2 == 1) {
            dataCell.cellStyle = excel_pkg.CellStyle(
              backgroundColorHex: excel_pkg.ExcelColor.gray100,
            );
          }
        }
      }
    }

    // 保存文件
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/${title}_$timestamp.xlsx';

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    } else {
      throw Exception('Excel文件生成失败');
    }
  }
}
