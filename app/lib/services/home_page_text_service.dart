import 'dart:math';

/// 首页动态文案服务
///
/// 功能特性：
/// 1. 千人千面：基于用户ID生成个性化文案，不同用户看到不同文案
/// 2. 定期刷新：支持定时刷新，同一用户在不同时间段看到不同文案
/// 3. 情境感知：根据用户表现（好/一般/差）展示不同风格的文案
/// 4. 丰富文案库：每种场景有多条文案，保证内容多样性
class HomePageTextService {
  /// 生成基于用户和时间的随机种子
  /// 同一用户在同一小时内会得到相同的种子，保证文案稳定
  /// 不同用户会得到不同的种子，实现千人千面
  static int _generateSeed({String? userId, String? category}) {
    final now = DateTime.now();
    // 使用 用户ID + 日期 + 小时 + 分类 生成种子
    // 这样同一用户在同一小时内看到的文案是稳定的
    final seedString = '${userId ?? 'guest'}_${now.year}${now.month}${now.day}${now.hour}_${category ?? ''}';
    return seedString.hashCode;
  }

  /// 从列表中基于用户ID稳定地选择一个元素
  static T _pickForUser<T>(List<T> items, {String? userId, String? category}) {
    if (items.isEmpty) throw ArgumentError('items cannot be empty');
    if (items.length == 1) return items.first;

    final seed = _generateSeed(userId: userId, category: category);
    final random = Random(seed);
    return items[random.nextInt(items.length)];
  }

  /// 获取结余趋势文案
  /// [growthPercent] 同比增长百分比，正数表示提升，负数表示下降
  /// [userId] 用户ID，用于千人千面
  static String getBalanceGrowthText(double growthPercent, {String? userId}) {
    // 处理NaN和Infinity
    if (growthPercent.isNaN || growthPercent.isInfinite) {
      return getNoGrowthDataText(userId: userId);
    }

    // 限制显示范围，超出范围时不显示具体数字
    final clampedGrowth = growthPercent.clamp(-500.0, 500.0);
    final absGrowth = clampedGrowth.abs().toStringAsFixed(1);
    final isExtreme = growthPercent.abs() > 500;

    List<String> candidates;

    // 处理极端值情况
    if (isExtreme) {
      if (growthPercent > 0) {
        candidates = [
          '本月结余大幅提升，做得非常好！💪',
          '本月收支表现出色，继续保持！🎉',
          '本月财务状况明显改善！✨',
        ];
      } else {
        candidates = [
          '本月有较大支出，建议查看明细',
          '本月花销较多，一起分析一下？',
          '本月支出增加明显，需要关注一下',
        ];
      }
      return _pickForUser(candidates, userId: userId, category: 'balance_extreme');
    }

    if (clampedGrowth >= 20) {
      // 大幅提升 - 热烈庆祝
      candidates = [
        '太厉害了！较上月提升$absGrowth%，理财达人就是你！💪',
        '厉害！较上月提升$absGrowth%，继续保持！🎉',
        '进步明显！较上月提升$absGrowth%，你做得很棒！✨',
        '优秀！较上月提升$absGrowth%，财务管理越来越好了！💰',
        '惊人的进步！提升$absGrowth%，你是理财高手！🏆',
        '完美！较上月大涨$absGrowth%，继续这个势头！🚀',
        '太赞了！$absGrowth%的提升，你的努力有回报了！🌟',
      ];
    } else if (clampedGrowth >= 5) {
      // 小幅提升 - 肯定鼓励
      candidates = [
        '不错！较上月提升$absGrowth%，继续加油！💪',
        '有进步！较上月提升$absGrowth%，坚持就是胜利～',
        '稳步提升$absGrowth%，每一点进步都值得肯定！',
        '较上月提升$absGrowth%，你的努力正在见效！',
        '好样的！提升$absGrowth%，保持这个节奏！',
        '进步$absGrowth%，稳扎稳打，继续前进！',
        '小有成就！提升$absGrowth%，积少成多～',
      ];
    } else if (clampedGrowth >= -5) {
      // 基本持平 - 平和描述
      candidates = [
        '本月结余与上月基本持平，保持稳定也是一种进步～',
        '收支基本稳定，继续保持良好的记账习惯！',
        '与上月持平，稳定的财务状况是好事～',
        '财务状况稳定，这就是最好的状态！',
        '收支平衡，稳中求进～',
        '保持平稳，这是财务健康的表现！',
      ];
    } else if (clampedGrowth >= -20) {
      // 小幅下降 - 理解支持
      candidates = [
        '较上月下降$absGrowth%，可能有些计划外支出？没关系～',
        '这个月支出多了一些，下个月调整一下就好～',
        '较上月下降$absGrowth%，偶尔波动很正常，继续加油！',
        '结余有所下降，我们一起看看哪里可以优化～',
        '下降$absGrowth%，可能有必要支出，别太担心～',
        '小幅波动很正常，下个月一起努力！',
        '这个月花费多了些，没关系，我们一起调整～',
      ];
    } else {
      // 大幅下降 - 关心建议
      candidates = [
        '这个月开销较大，需要看看消费明细吗？',
        '结余下降较多，可能需要调整一下预算规划～',
        '较上月下降$absGrowth%，别担心，我们一起想办法！',
        '这个月花费较多，下个月一起努力节省一些～',
        '看起来这个月有大额支出，要不要一起分析下？',
        '花销有点大，不过没关系，我们可以一起优化～',
        '这个月挑战不小，下个月我们一起加油！',
      ];
    }

    return _pickForUser(candidates, userId: userId, category: 'balance_${clampedGrowth.toInt()}');
  }

  /// 获取连续记账庆祝文案
  /// [consecutiveDays] 连续记账天数
  /// [userId] 用户ID，用于千人千面
  static String getStreakCelebrationText(int consecutiveDays, {String? userId}) {
    List<String> candidates;

    if (consecutiveDays >= 365) {
      candidates = [
        '太震撼了！连续记账$consecutiveDays天，你是真正的理财大师！🏆',
        '一年以上的坚持！$consecutiveDays天连续记账，传奇级成就！🌟',
        '$consecutiveDays天！你的坚持令人敬佩，你是最棒的！👑',
        '难以置信！$consecutiveDays天的坚持，你创造了奇迹！🎖️',
        '$consecutiveDays天！这份毅力值得所有人学习！💎',
      ];
    } else if (consecutiveDays >= 100) {
      candidates = [
        '厉害！连续记账$consecutiveDays天，百日成就达成！🎖️',
        '了不起！$consecutiveDays天的坚持，你已经是记账高手了！🏅',
        '连续$consecutiveDays天！这份自律太令人佩服了！💎',
        '百日达成！$consecutiveDays天的努力，值得骄傲！🌟',
        '$consecutiveDays天！你的坚持已经成为习惯了！✨',
      ];
    } else if (consecutiveDays >= 30) {
      candidates = [
        '太棒了！连续记账$consecutiveDays天，习惯已养成！🎉',
        '恭喜！$consecutiveDays天坚持记账，你做到了！🌈',
        '连续$consecutiveDays天！记账已成为你的日常习惯！⭐',
        '月度成就！连续$consecutiveDays天，给自己点赞！👍',
        '$consecutiveDays天的坚持，你越来越厉害了！💪',
      ];
    } else if (consecutiveDays >= 7) {
      candidates = [
        '真棒！连续记账$consecutiveDays天，继续保持！💪',
        '连续$consecutiveDays天记账，好习惯正在养成！👍',
        '$consecutiveDays天的坚持，你越来越厉害了！✨',
        '周成就达成！连续$consecutiveDays天，加油！🌟',
        '不错！$consecutiveDays天连续记账，继续冲！💪',
      ];
    } else {
      candidates = [
        '连续记账$consecutiveDays天，继续加油！💪',
        '已经坚持$consecutiveDays天了，每天都是进步！',
        '连续$consecutiveDays天，好的开始是成功的一半！',
        '$consecutiveDays天啦！坚持下去会越来越好！',
        '第$consecutiveDays天，你正在养成好习惯！',
      ];
    }

    return _pickForUser(candidates, userId: userId, category: 'streak_$consecutiveDays');
  }

  /// 获取连续记账鼓励语
  /// [consecutiveDays] 连续记账天数
  /// [userId] 用户ID，用于千人千面
  static String getStreakEncouragementText(int consecutiveDays, {String? userId}) {
    List<String> candidates;

    if (consecutiveDays >= 100) {
      candidates = [
        '你已经是传说了！',
        '坚持的力量真伟大！',
        '未来可期，继续前行！',
        '你是榜样！',
        '无人能及的毅力！',
      ];
    } else if (consecutiveDays >= 30) {
      candidates = [
        '习惯已养成，继续保持！',
        '你的坚持令人钦佩！',
        '继续加油，更高目标等着你！',
        '下一个里程碑在前方！',
        '你做得太好了！',
      ];
    } else if (consecutiveDays >= 7) {
      candidates = [
        '继续保持这个势头！',
        '每一天都是新的进步！',
        '你做得很好，继续加油！',
        '坚持就是胜利！',
        '保持节奏，冲向30天！',
      ];
    } else {
      candidates = [
        '继续保持！',
        '加油！',
        '坚持就是胜利！',
        '你可以的！',
        '每天进步一点点！',
      ];
    }

    return _pickForUser(candidates, userId: userId, category: 'encouragement_$consecutiveDays');
  }

  /// 获取钱龄趋势文案
  /// [trendDays] 趋势变化天数，正数表示提升，负数表示下降
  /// [trend] 趋势方向 'up', 'down', 或 'stable'
  /// [userId] 用户ID，用于千人千面
  /// [moneyAgeDays] 钱龄天数，用于判断是否为0
  static String getMoneyAgeTrendText(int trendDays, String trend, {String? userId, int? moneyAgeDays}) {
    // 如果钱龄为0，显示警告信息
    if (moneyAgeDays != null && moneyAgeDays == 0) {
      return '当前钱龄为0，建议关注收支平衡';
    }

    final absDays = trendDays.abs();
    List<String> candidates;

    if (trend == 'up' || trendDays > 0) {
      if (absDays >= 10) {
        candidates = [
          '较上月增加$absDays天，资金周转效率大幅提升！💪',
          '钱龄增加$absDays天，财务状况明显改善！✨',
          '太棒了！钱龄增加$absDays天，继续保持！🎉',
          '进步显著！钱龄提升$absDays天！🌟',
          '钱龄大幅改善，你的理财越来越棒了！',
        ];
      } else {
        candidates = [
          '较上月增加$absDays天，继续保持！',
          '钱龄有所改善，做得不错！',
          '增加$absDays天，稳步向好～',
          '小有进步，继续加油！',
          '钱龄在改善，保持这个趋势！',
        ];
      }
    } else if (trend == 'down' || trendDays < 0) {
      if (absDays >= 10) {
        candidates = [
          '较上月下降$absDays天，可能需要关注一下收支情况',
          '钱龄变化较大，看看是否有大额支出？',
          '下降$absDays天，我们一起分析一下原因～',
          '钱龄有些波动，要不要看看明细？',
          '变化有点大，一起优化一下？',
        ];
      } else {
        candidates = [
          '较上月下降$absDays天，正常波动',
          '小幅波动是正常的，不必担心',
          '钱龄略有变化，继续观察～',
          '正常范围内的波动，无需担心',
          '小波动，大局稳定～',
        ];
      }
    } else {
      candidates = [
        '钱龄保持稳定，财务状况良好',
        '与上月持平，稳定也是一种成功',
        '保持平稳，继续保持良好习惯～',
        '财务状况稳定，继续保持！',
        '钱龄稳定，你做得很好！',
      ];
    }

    return _pickForUser(candidates, userId: userId, category: 'moneyage_$trend');
  }

  /// 获取时间问候语
  /// [userId] 用户ID，用于千人千面
  static HomeGreeting getTimeGreeting({String? userId}) {
    final hour = DateTime.now().hour;
    List<HomeGreeting> candidates;

    if (hour >= 5 && hour < 12) {
      candidates = [
        const HomeGreeting(
          emoji: '☀️',
          text: '早安，美好的一天开始了',
          motivation: '今天也要加油哦！',
        ),
        const HomeGreeting(
          emoji: '🌅',
          text: '早上好，新的一天充满希望',
          motivation: '元气满满地开始记账吧！',
        ),
        const HomeGreeting(
          emoji: '☀️',
          text: '早安，阳光正好',
          motivation: '让我们一起理好今天的财！',
        ),
        const HomeGreeting(
          emoji: '🌤️',
          text: '早上好，精神抖擞',
          motivation: '记账从早开始！',
        ),
        const HomeGreeting(
          emoji: '🌻',
          text: '早安，活力满满',
          motivation: '新的一天，新的开始！',
        ),
        const HomeGreeting(
          emoji: '☀️',
          text: '早上好，今天会更好',
          motivation: '一起管好钱袋子！',
        ),
      ];
    } else if (hour >= 12 && hour < 14) {
      candidates = [
        const HomeGreeting(
          emoji: '🌤️',
          text: '中午好，记得吃午饭',
          motivation: '休息一下再继续！',
        ),
        const HomeGreeting(
          emoji: '🍚',
          text: '午安，补充能量的时候',
          motivation: '吃饱了才有力气理财～',
        ),
        const HomeGreeting(
          emoji: '☀️',
          text: '中午好，辛苦了半天',
          motivation: '好好休息一下！',
        ),
        const HomeGreeting(
          emoji: '🥗',
          text: '午餐时间到',
          motivation: '顺便看看今天的账～',
        ),
        const HomeGreeting(
          emoji: '😊',
          text: '中午好，忙碌的上午结束了',
          motivation: '下午继续加油！',
        ),
      ];
    } else if (hour >= 14 && hour < 18) {
      candidates = [
        const HomeGreeting(
          emoji: '⛅',
          text: '下午好，保持好心情',
          motivation: '继续加油！',
        ),
        const HomeGreeting(
          emoji: '☕',
          text: '下午好，来杯下午茶',
          motivation: '顺便看看今天的收支～',
        ),
        const HomeGreeting(
          emoji: '🌤️',
          text: '下午好，保持专注',
          motivation: '理财达人就是你！',
        ),
        const HomeGreeting(
          emoji: '💪',
          text: '下午好，继续冲',
          motivation: '今天的目标要完成！',
        ),
        const HomeGreeting(
          emoji: '🍵',
          text: '下午好，放松一下',
          motivation: '喝口茶，看看账～',
        ),
      ];
    } else if (hour >= 18 && hour < 22) {
      candidates = [
        const HomeGreeting(
          emoji: '🌙',
          text: '晚上好，辛苦了一天',
          motivation: '好好放松一下！',
        ),
        const HomeGreeting(
          emoji: '🌆',
          text: '晚上好，忙碌的一天结束了',
          motivation: '记完账就好好休息吧！',
        ),
        const HomeGreeting(
          emoji: '✨',
          text: '晚上好，今天过得怎么样',
          motivation: '来记录一下今天的收支～',
        ),
        const HomeGreeting(
          emoji: '🌃',
          text: '晚上好，夜色真美',
          motivation: '记完账享受美好夜晚！',
        ),
        const HomeGreeting(
          emoji: '🏠',
          text: '晚上好，欢迎回家',
          motivation: '今天的账记了吗？',
        ),
      ];
    } else {
      candidates = [
        const HomeGreeting(
          emoji: '🌟',
          text: '夜深了，注意休息',
          motivation: '早点休息哦！',
        ),
        const HomeGreeting(
          emoji: '🌙',
          text: '夜深了，还在忙吗',
          motivation: '照顾好自己！',
        ),
        const HomeGreeting(
          emoji: '💫',
          text: '深夜了，辛苦了',
          motivation: '记完账就去睡觉吧～',
        ),
        const HomeGreeting(
          emoji: '😴',
          text: '夜已深，该休息了',
          motivation: '明天继续加油！',
        ),
        const HomeGreeting(
          emoji: '🌙',
          text: '夜猫子你好',
          motivation: '记得早点休息～',
        ),
      ];
    }

    return _pickForUser(candidates, userId: userId, category: 'greeting_$hour');
  }

  /// 获取无增长数据时的文案
  /// [userId] 用户ID，用于千人千面
  static String getNoGrowthDataText({String? userId}) {
    final candidates = [
      '这是记账的第一个月，一起加油！',
      '刚开始记账，坚持下去会越来越好！',
      '记账之旅刚刚开始，期待你的进步！',
      '新的开始，新的希望！',
      '开启理财之旅，从这里起步！',
      '万事开头难，你已经迈出第一步了！',
    ];

    return _pickForUser(candidates, userId: userId, category: 'no_growth');
  }
}

/// 首页问候语数据模型
class HomeGreeting {
  final String emoji;
  final String text;
  final String motivation;

  const HomeGreeting({
    required this.emoji,
    required this.text,
    required this.motivation,
  });
}
