import 'package:flutter/material.dart';
import '../services/multimodal_wakeup_service.dart';
import '../services/gesture_wake_service.dart';

/// 多模态唤醒设置页面
class MultimodalWakeUpSettingsPage extends StatefulWidget {
  const MultimodalWakeUpSettingsPage({Key? key}) : super(key: key);

  @override
  State<MultimodalWakeUpSettingsPage> createState() => _MultimodalWakeUpSettingsPageState();
}

class _MultimodalWakeUpSettingsPageState extends State<MultimodalWakeUpSettingsPage> {
  final _wakeUpService = MultimodalWakeUpService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('多模态唤醒设置'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('语音唤醒'),
          _buildVoiceWakeSection(),
          const Divider(height: 32),
          _buildSectionHeader('手势快捷方式'),
          _buildGestureSection(),
          const Divider(height: 32),
          _buildSectionHeader('桌面小组件'),
          _buildWidgetSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVoiceWakeSection() {
    final voiceService = _wakeUpService.voiceWakeService;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('启用语音唤醒'),
          subtitle: const Text('说出唤醒词即可开始记账'),
          value: voiceService.isListening,
          onChanged: (value) {
            setState(() {
              if (value) {
                voiceService.startListening();
              } else {
                voiceService.stopListening();
              }
            });
          },
        ),
        ListTile(
          title: const Text('唤醒词设置'),
          subtitle: Text('当前: ${voiceService.enabledWakeWords.join('、')}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showWakeWordsDialog(),
        ),
        SwitchListTile(
          title: const Text('声纹识别'),
          subtitle: const Text('只响应主人声音'),
          value: voiceService.voiceprintEnabled,
          onChanged: (value) {
            setState(() {
              voiceService.setVoiceprintEnabled(value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildGestureSection() {
    final gestureService = _wakeUpService.gestureWakeService;

    return Column(
      children: [
        for (var gesture in GestureWakeType.values)
          SwitchListTile(
            title: Text(_getGestureName(gesture)),
            subtitle: Text(_getGestureDescription(gesture)),
            value: gestureService.isGestureEnabled(gesture),
            onChanged: (value) {
              setState(() {
                gestureService.setGestureEnabled(gesture, value);
              });
            },
          ),
      ],
    );
  }

  Widget _buildWidgetSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.widgets),
          title: const Text('添加桌面小组件'),
          subtitle: const Text('长按桌面空白处添加'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 打开系统小组件设置
          },
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('小组件说明'),
          subtitle: Text('支持1×1极简版和2×2标准版\n点击小组件可快速启动语音记账'),
        ),
      ],
    );
  }

  String _getGestureName(GestureWakeType gesture) {
    switch (gesture) {
      case GestureWakeType.shake:
        return '摇一摇';
      case GestureWakeType.doubleTapBack:
        return '双击背面';
      case GestureWakeType.threeFingerSwipe:
        return '三指下滑';
      case GestureWakeType.flipDown:
        return '翻转放下';
      case GestureWakeType.volumeLongPress:
        return '长按音量键';
    }
  }

  String _getGestureDescription(GestureWakeType gesture) {
    switch (gesture) {
      case GestureWakeType.shake:
        return '连续摇晃手机2次';
      case GestureWakeType.doubleTapBack:
        return '轻敲手机背面2下（支持机型）';
      case GestureWakeType.threeFingerSwipe:
        return '屏幕内三指下滑';
      case GestureWakeType.flipDown:
        return '翻转手机屏幕朝下';
      case GestureWakeType.volumeLongPress:
        return '长按音量上键1.5秒';
    }
  }

  void _showWakeWordsDialog() {
    final voiceService = _wakeUpService.voiceWakeService;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('唤醒词设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var word in voiceService.enabledWakeWords)
              ListTile(
                title: Text(word),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    voiceService.removeWakeWord(word);
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              ),
            const Divider(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加自定义唤醒词'),
              onPressed: () => _showAddWakeWordDialog(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAddWakeWordDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加唤醒词'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入2-4个字的唤醒词',
          ),
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final word = controller.text.trim();
              if (word.length >= 2 && word.length <= 4) {
                _wakeUpService.voiceWakeService.addCustomWakeWord(word);
                Navigator.pop(context);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
