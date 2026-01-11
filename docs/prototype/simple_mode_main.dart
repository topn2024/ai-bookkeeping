import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SimpleModeApp());
}

class SimpleModeApp extends StatelessWidget {
  const SimpleModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简单模式原型',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SimpleHomePage(),
    );
  }
}

// ==================== 首页 ====================
class SimpleHomePage extends StatelessWidget {
  const SimpleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('简单模式', style: TextStyle(fontSize: 20, color: Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, size: 28, color: Colors.black54),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleProfilePage())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 余额卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('还剩多少钱', style: TextStyle(fontSize: 18, color: Colors.white70)),
                    const SizedBox(height: 8),
                    const Text('¥ 3,280', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Text('这个月花了 ¥720', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 四个大按钮
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildBigButton(context, '🖊️', '记一笔', '花钱了点这里', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleAddPage()))),
                    _buildBigButton(context, '📋', '看看账', '看看花了多少', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleListPage()))),
                    _buildBigButton(context, '🐷', '存钱罐', '看看存了多少', Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleSavingsPage()))),
                    _buildBigButton(context, '👤', '我的', '设置和帮助', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleProfilePage()))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton(BuildContext context, String emoji, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 记账页 ====================
class SimpleAddPage extends StatefulWidget {
  const SimpleAddPage({super.key});
  @override
  State<SimpleAddPage> createState() => _SimpleAddPageState();
}

class _SimpleAddPageState extends State<SimpleAddPage> {
  String _amount = '0';
  int _step = 0; // 0=输入金额, 1=选分类, 2=成功

  final List<Map<String, dynamic>> _categories = [
    {'emoji': '🍜', 'name': '吃饭', 'color': Colors.orange},
    {'emoji': '🛒', 'name': '买东西', 'color': Colors.pink},
    {'emoji': '🚗', 'name': '出行', 'color': Colors.blue},
    {'emoji': '🏠', 'name': '住房', 'color': Colors.brown},
    {'emoji': '🎮', 'name': '玩乐', 'color': Colors.purple},
    {'emoji': '💊', 'name': '看病', 'color': Colors.red},
    {'emoji': '📱', 'name': '话费', 'color': Colors.teal},
    {'emoji': '📦', 'name': '其他', 'color': Colors.grey},
  ];
  String _selectedCategory = '';

  void _onNumberTap(String num) {
    HapticFeedback.lightImpact();
    setState(() {
      if (num == '←') {
        if (_amount.length > 1) _amount = _amount.substring(0, _amount.length - 1);
        else _amount = '0';
      } else if (num == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0') _amount = num;
        else if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
        else _amount += num;
      }
    });
  }

  void _onCategoryTap(String name) {
    HapticFeedback.mediumImpact();
    setState(() { _selectedCategory = name; _step = 2; });
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 2) return _buildSuccessPage();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => _step == 0 ? Navigator.pop(context) : setState(() => _step = 0)),
        title: const Text('记一笔', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: _step == 0 ? _buildAmountInput() : _buildCategorySelect(),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text('花了多少钱？', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text('¥ $_amount', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)))),
        ),
        const SizedBox(height: 12),
        const Text('点下面的数字输入金额', style: TextStyle(fontSize: 16, color: Colors.black45)),
        const Spacer(),
        _buildNumpad(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity, height: 64,
            child: ElevatedButton(
              onPressed: _amount != '0' ? () => setState(() => _step = 1) : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              child: const Text('下一步 →'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    final keys = ['1','2','3','4','5','6','7','8','9','.','0','←'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.8, mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: 12,
        itemBuilder: (_, i) => Material(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _onNumberTap(keys[i]),
            borderRadius: BorderRadius.circular(12),
            child: Center(child: Text(keys[i], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelect() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text('花了 ¥$_amount', style: const TextStyle(fontSize: 22, color: Color(0xFF2196F3), fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Text('花在哪里了？', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.3, mainAxisSpacing: 16, crossAxisSpacing: 16),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              return Material(
                color: Colors.white, borderRadius: BorderRadius.circular(20), elevation: 2,
                child: InkWell(
                  onTap: () => _onCategoryTap(cat['name']),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(color: (cat['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Center(child: Text(cat['emoji'], style: const TextStyle(fontSize: 32))),
                      ),
                      const SizedBox(height: 8),
                      Text(cat['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(padding: EdgeInsets.all(20), child: Text('点一个就行，选错了能改', style: TextStyle(fontSize: 16, color: Colors.black45))),
      ],
    );
  }

  Widget _buildSuccessPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 60, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text('记好了！', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('花了 $_amount 块钱$_selectedCategory', style: const TextStyle(fontSize: 20, color: Colors.black54)),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity, height: 64,
                  child: ElevatedButton(
                    onPressed: () => setState(() { _amount = '0'; _step = 0; _selectedCategory = ''; }),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('再记一笔', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('回到首页', style: TextStyle(fontSize: 18))),
              const SizedBox(height: 40),
              TextButton(onPressed: () {}, child: const Text('← 记错了？点这里改', style: TextStyle(fontSize: 16, color: Colors.black45))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 看账页 ====================
class SimpleListPage extends StatelessWidget {
  const SimpleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'emoji': '🍜', 'name': '吃饭', 'amount': 980, 'percent': 0.45, 'color': Colors.orange},
      {'emoji': '🛒', 'name': '买东西', 'amount': 650, 'percent': 0.30, 'color': Colors.pink},
      {'emoji': '🚗', 'name': '出行', 'amount': 320, 'percent': 0.15, 'color': Colors.blue},
      {'emoji': '🎮', 'name': '玩乐', 'amount': 230, 'percent': 0.10, 'color': Colors.purple},
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => Navigator.pop(context)), title: const Text('看看账', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  const Text('这个月', style: TextStyle(fontSize: 18, color: Colors.black54)),
                  const SizedBox(height: 8),
                  const Text('花了 ¥ 2,180', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('还能花 ¥ 820', style: TextStyle(fontSize: 18, color: Colors.green[600])),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(alignment: Alignment.centerLeft, child: Text('花在哪里了？', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(item['emoji'] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Text(item['name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('¥ ${item['amount']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: item['percent'] as double, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(item['color'] as Color), minHeight: 8),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            const Text('点一个看详细', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

// ==================== 存钱罐页 ====================
class SimpleSavingsPage extends StatelessWidget {
  const SimpleSavingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => Navigator.pop(context)), title: const Text('存钱罐', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐷', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              const Text('存钱罐里有', style: TextStyle(fontSize: 20, color: Colors.black54)),
              const SizedBox(height: 8),
              const Text('¥ 5,000', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
              const SizedBox(height: 16),
              const Text('目标 ¥10,000', style: TextStyle(fontSize: 18, color: Colors.black54)),
              const Text('还差 ¥5,000', style: TextStyle(fontSize: 18, color: Colors.black54)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: 0.5, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFFE91E63)), minHeight: 16)),
                    const SizedBox(height: 8),
                    const Text('50%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(width: double.infinity, height: 64, child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('存钱进去', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 64, child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFFE91E63), width: 2)), child: const Text('取钱出来', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 我的页 ====================
class SimpleProfilePage extends StatelessWidget {
  const SimpleProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.bar_chart, 'title': '看看报表', 'subtitle': '每月花了多少钱', 'color': Colors.blue},
      {'icon': Icons.cloud_upload, 'title': '存到云上', 'subtitle': '数据不会丢', 'color': Colors.green},
      {'icon': Icons.settings, 'title': '设置', 'subtitle': '调整字体大小等', 'color': Colors.grey},
      {'icon': Icons.help, 'title': '帮助', 'subtitle': '不会用？点这里', 'color': Colors.orange},
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, size: 28), onPressed: () => Navigator.pop(context)), title: const Text('我的', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.blue[100], shape: BoxShape.circle),
              child: const Icon(Icons.person, size: 48, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            const Text('用户昵称', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28)),
                title: Text(item['title'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Text(item['subtitle'] as String, style: const TextStyle(fontSize: 14, color: Colors.black45)),
                trailing: const Icon(Icons.chevron_right, size: 28),
                onTap: () {},
              ),
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 64,
              child: OutlinedButton(
                onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('退出简单模式？'), content: const Text('退出后会用回完整版'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('算了')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('退出'))])),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('退出简单模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('用回完整版', style: TextStyle(fontSize: 14, color: Colors.black45))]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
