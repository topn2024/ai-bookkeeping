import 'dart:math';

/// 首页动态文案服务
///
/// 根据用户表现动态生成不同的激励文字
/// - 表现好时：庆祝、鼓励、肯定
/// - 表现一般时：温和提醒、正面引导
/// - 表现不佳时：理解、支持、建议
class HomePageTextService {
  static final _random = Random();

  /// 获取结余趋势文案
  /// [growthPercent] 同比增长百分比，正数表示提升，负数表示下降
  static String getBalanceGrowthText(double growthPercent) {
    final absGrowth = growthPercent.abs().toStringAsFixed(1);

    if (growthPercent >= 20) {
      // 大幅提升 - 热烈庆祝
      return _pickRandom([
        '太厉害了！较上月提升$absGrowth%，理财达人就是你！💪',
        '厉害！较上月提升$absGrowth%，继续保持！🎉',
        '进步明显！较上月提升$absGrowth%，你做得很棒！✨',
        '优秀！较上月提升$absGrowth%，财务管理越来越好了！💰',
      ]);
    } else if (growthPercent >= 5) {
      // 小幅提升 - 肯定鼓励
      return _pickRandom([
        '不错！较上月提升$absGrowth%，继续加油！💪',
        '有进步！较上月提升$absGrowth%，坚持就是胜利～',
        '稳步提升$absGrowth%，每一点进步都值得肯定！',
        '较上月提升$absGrowth%，你的努力正在见效！',
      ]);
    } else if (growthPercent >= -5) {
      // 基本持平 - 平和描述
      return _pickRandom([
        '本月结余与上月基本持平，保持稳定也是一种进步～',
        '收支基本稳定，继续保持良好的记账习惯！',
        '与上月持平，稳定的财务状况是好事～',
      ]);
    } else if (growthPercent >= -20) {
      // 小幅下降 - 理解支持
      return _pickRandom([
        '较上月下降$absGrowth%，可能有些计划外支出？没关系～',
        '这个月支出多了一些，下个月调整一下就好～',
        '较上月下降$absGrowth%，偶尔波动很正常，继续加油！',
        '结余有所下降，我们一起看看哪里可以优化～',
      ]);
    } else {
      // 大幅下降 - 关心建议
      return _pickRandom([
        '这个月开销较大，需要看看消费明细吗？',
        '结余下降较多，可能需要调整一下预算规划～',
        '较上月下降$absGrowth%，别担心，我们一起想办法！',
        '这个月花费较多，下个月一起努力节省一些～',
      ]);
    }
  }

  /// 获取连续记账庆祝文案
  /// [consecutiveDays] 连续记账天数
  static String getStreakCelebrationText(int consecutiveDays) {
    if (consecutiveDays >= 365) {
      return _pickRandom([
        '太震撼了！连续记账$consecutiveDays天，你是真正的理财大师！🏆',
        '一年以上的坚持！$consecutiveDays天连续记账，传奇级成就！🌟',
        '$consecutiveDays天！你的坚持令人敬佩，你是最棒的！👑',
      ]);
    } else if (consecutiveDays >= 100) {
      return _pickRandom([
        '厉害！连续记账$consecutiveDays天，百日成就达成！🎖️',
        '了不起！$consecutiveDays天的坚持，你已经是记账高手了！🏅',
        '连续$consecutiveDays天！这份自律太令人佩服了！💎',
      ]);
    } else if (consecutiveDays >= 30) {
      return _pickRandom([
        '太棒了！连续记账$consecutiveDays天，习惯已养成！🎉',
        '恭喜！$consecutiveDays天坚持记账，你做到了！🌈',
        '连续$consecutiveDays天！记账已成为你的日常习惯！⭐',
      ]);
    } else if (consecutiveDays >= 7) {
      return _pickRandom([
        '真棒！连续记账$consecutiveDays天，继续保持！💪',
        '连续$consecutiveDays天记账，好习惯正在养成！👍',
        '$consecutiveDays天的坚持，你越来越厉害了！✨',
      ]);
    } else {
      return _pickRandom([
        '连续记账$consecutiveDays天，继续加油！💪',
        '已经坚持$consecutiveDays天了，每天都是进步！',
        '连续$consecutiveDays天，好的开始是成功的一半！',
      ]);
    }
  }

  /// 获取连续记账鼓励语
  /// [consecutiveDays] 连续记账天数
  static String getStreakEncouragementText(int consecutiveDays) {
    if (consecutiveDays >= 100) {
      return _pickRandom([
        '你已经是传说了！',
        '坚持的力量真伟大！',
        '未来可期，继续前行！',
      ]);
    } else if (consecutiveDays >= 30) {
      return _pickRandom([
        '习惯已养成，继续保持！',
        '你的坚持令人钦佩！',
        '继续加油，更高目标等着你！',
      ]);
    } else if (consecutiveDays >= 7) {
      return _pickRandom([
        '继续保持这个势头！',
        '每一天都是新的进步！',
        '你做得很好，继续加油！',
      ]);
    } else {
      return _pickRandom([
        '继续保持！',
        '加油！',
        '坚持就是胜利！',
      ]);
    }
  }

  /// 获取钱龄趋势文案
  /// [trendDays] 趋势变化天数，正数表示提升，负数表示下降
  /// [trend] 趋势方向 'up', 'down', 或 'stable'
  static String getMoneyAgeTrendText(int trendDays, String trend) {
    final absDays = trendDays.abs();

    if (trend == 'up' || trendDays > 0) {
      if (absDays >= 10) {
        return _pickRandom([
          '较上月提升$absDays天，资金周转效率大幅提升！💪',
          '钱龄降低$absDays天，财务状况明显改善！✨',
          '太棒了！钱龄改善$absDays天，继续保持！🎉',
        ]);
      } else {
        return _pickRandom([
          '较上月提升$absDays天，继续保持！',
          '钱龄有所改善，做得不错！',
          '进步$absDays天，稳步向好～',
        ]);
      }
    } else if (trend == 'down' || trendDays < 0) {
      if (absDays >= 10) {
        return _pickRandom([
          '较上月下降$absDays天，可能需要关注一下收支情况',
          '钱龄变化较大，看看是否有大额支出？',
          '下降$absDays天，我们一起分析一下原因～',
        ]);
      } else {
        return _pickRandom([
          '较上月下降$absDays天，正常波动',
          '小幅波动是正常的，不必担心',
          '钱龄略有变化，继续观察～',
        ]);
      }
    } else {
      return _pickRandom([
        '钱龄保持稳定，财务状况良好',
        '与上月持平，稳定也是一种成功',
        '保持平稳，继续保持良好习惯～',
      ]);
    }
  }

  /// 获取时间问候语
  static HomeGreeting getTimeGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return _pickRandom([
        HomeGreeting(
          emoji: '☀️',
          text: '早安，美好的一天开始了',
          motivation: '今天也要加油哦！',
        ),
        HomeGreeting(
          emoji: '🌅',
          text: '早上好，新的一天充满希望',
          motivation: '元气满满地开始记账吧！',
        ),
        HomeGreeting(
          emoji: '☀️',
          text: '早安，阳光正好',
          motivation: '让我们一起理好今天的财！',
        ),
        HomeGreeting(
          emoji: '🌤️',
          text: '早上好，精神抖擞',
          motivation: '记账从早开始！',
        ),
      ]);
    } else if (hour >= 12 && hour < 14) {
      return _pickRandom([
        HomeGreeting(
          emoji: '🌤️',
          text: '中午好，记得吃午饭',
          motivation: '休息一下再继续！',
        ),
        HomeGreeting(
          emoji: '🍚',
          text: '午安，补充能量的时候',
          motivation: '吃饱了才有力气理财～',
        ),
        HomeGreeting(
          emoji: '☀️',
          text: '中午好，辛苦了半天',
          motivation: '好好休息一下！',
        ),
      ]);
    } else if (hour >= 14 && hour < 18) {
      return _pickRandom([
        HomeGreeting(
          emoji: '⛅',
          text: '下午好，保持好心情',
          motivation: '继续加油！',
        ),
        HomeGreeting(
          emoji: '☕',
          text: '下午好，来杯下午茶',
          motivation: '顺便看看今天的收支～',
        ),
        HomeGreeting(
          emoji: '🌤️',
          text: '下午好，保持专注',
          motivation: '理财达人就是你！',
        ),
      ]);
    } else if (hour >= 18 && hour < 22) {
      return _pickRandom([
        HomeGreeting(
          emoji: '🌙',
          text: '晚上好，辛苦了一天',
          motivation: '好好放松一下！',
        ),
        HomeGreeting(
          emoji: '🌆',
          text: '晚上好，忙碌的一天结束了',
          motivation: '记完账就好好休息吧！',
        ),
        HomeGreeting(
          emoji: '✨',
          text: '晚上好，今天过得怎么样',
          motivation: '来记录一下今天的收支～',
        ),
      ]);
    } else {
      return _pickRandom([
        HomeGreeting(
          emoji: '🌟',
          text: '夜深了，注意休息',
          motivation: '早点休息哦！',
        ),
        HomeGreeting(
          emoji: '🌙',
          text: '夜深了，还在忙吗',
          motivation: '照顾好自己！',
        ),
        HomeGreeting(
          emoji: '💫',
          text: '深夜了，辛苦了',
          motivation: '记完账就去睡觉吧～',
        ),
      ]);
    }
  }

  /// 获取无增长数据时的文案
  static String getNoGrowthDataText() {
    return _pickRandom([
      '这是记账的第一个月，一起加油！',
      '刚开始记账，坚持下去会越来越好！',
      '记账之旅刚刚开始，期待你的进步！',
    ]);
  }

  /// 从列表中随机选择一个
  static T _pickRandom<T>(List<T> items) {
    return items[_random.nextInt(items.length)];
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
