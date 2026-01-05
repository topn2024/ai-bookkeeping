# -*- coding: utf-8 -*-
"""生成专利09的附图：渐进式披露界面设计方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_09'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_three_layer_info():
    """图1：三层信息架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图1  三层信息架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 第一层：核心信息
    layer1 = FancyBboxPatch((2, 8.5), 10, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=3)
    ax.add_patch(layer1)
    ax.text(7, 10.2, '第一层：核心信息 (始终可见)', ha='center', va='center', fontsize=12, weight='bold')

    core_items = ['当前钱龄', '今日收支', '账户余额']
    for i, text in enumerate(core_items):
        draw_box(ax, 4 + i*3, 9, 2.5, 0.8, text, '#A5D6A7', 'black', 10)

    # 第二层：扩展信息
    layer2 = FancyBboxPatch((2, 5.3), 10, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer2)
    ax.text(7, 7, '第二层：扩展信息 (交互展开)', ha='center', va='center', fontsize=12, weight='bold')

    expand_items = ['趋势图表', '分类统计', '预算进度']
    for i, text in enumerate(expand_items):
        draw_box(ax, 4 + i*3, 5.8, 2.5, 0.8, text, '#90CAF9', 'black', 10)

    # 第三层：详细信息
    layer3 = FancyBboxPatch((2, 2.1), 10, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#FFE0B2', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(layer3)
    ax.text(7, 3.8, '第三层：详细信息 (深度探索)', ha='center', va='center', fontsize=12, weight='bold')

    detail_items = ['完整账单', '高级分析', '原始数据']
    for i, text in enumerate(detail_items):
        draw_box(ax, 4 + i*3, 2.6, 2.5, 0.8, text, '#FFCC80', 'black', 10)

    # 用户交互指示
    ax.text(13, 9.5, '默认展示', ha='center', va='center', fontsize=9, color='#388E3C')
    ax.text(13, 6.3, '点击展开', ha='center', va='center', fontsize=9, color='#1976D2')
    ax.text(13, 3.1, '深入查看', ha='center', va='center', fontsize=9, color='#EF6C00')

    # 箭头
    draw_arrow(ax, (7, 8.5), (7, 7.5))
    draw_arrow(ax, (7, 5.3), (7, 4.3))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_三层信息架构示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_user_level_assessment():
    """图2：用户水平评估流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图2  用户水平评估流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '用户行为数据采集', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    # 评估维度
    ax.text(6, 8.8, '多维度评估', ha='center', va='center', fontsize=10, weight='bold')

    dimensions = [
        (3, 7.5, '使用时长\n累计天数', '#FFCDD2'),
        (6, 7.5, '功能使用\n深度广度', '#C8E6C9'),
        (9, 7.5, '操作熟练\n响应速度', '#BBDEFB'),
    ]
    for x, y, text, color in dimensions:
        draw_box(ax, x, y, 2.5, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (6, 9.75), (6, 9.2))
    ax.plot([3, 9], [9.2, 9.2], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 9.2), (x, 8.1))

    draw_box(ax, 6, 5.8, 4.5, 1, '综合评分计算\n加权公式', '#E1BEE7', 'black', 10)
    ax.plot([3, 9], [6.9, 6.9], 'k-', lw=1.5)
    draw_arrow(ax, (6, 6.9), (6, 6.3))

    # 用户等级
    ax.text(6, 4.6, '用户等级判定', ha='center', va='center', fontsize=10, weight='bold')

    levels = [
        (3, 3.3, '新手用户\n简化界面', '#C8E6C9'),
        (6, 3.3, '普通用户\n标准界面', '#BBDEFB'),
        (9, 3.3, '专家用户\n完整界面', '#FFE0B2'),
    ]
    for x, y, text, color in levels:
        draw_box(ax, x, y, 2.5, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (6, 5.3), (6, 4.9))
    ax.plot([3, 9], [4.9, 4.9], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 4.9), (x, 3.9))

    draw_box(ax, 6, 1.5, 4.5, 1, '界面自适应配置\n动态调整', '#E8F5E9', 'black', 10)
    ax.plot([3, 9], [2.7, 2.7], 'k-', lw=1.5)
    draw_arrow(ax, (6, 2.7), (6, 2))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_用户水平评估流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_progressive_loading():
    """图3：渐进加载时序图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图3  渐进加载时序图', ha='center', va='center', fontsize=14, weight='bold')

    # 时间轴
    ax.annotate('', xy=(13, 9), xytext=(1, 9),
                arrowprops=dict(arrowstyle='->', color='#666', lw=2))
    ax.text(13.2, 9, '时间', ha='left', va='center', fontsize=10, color='#666')

    # 阶段标记
    phases = [
        (2, '0ms', '骨架屏'),
        (5, '100ms', '核心数据'),
        (8, '300ms', '图表渲染'),
        (11, '500ms', '完整加载'),
    ]
    for x, time, phase in phases:
        ax.plot([x, x], [8.8, 8.2], 'k-', lw=1.5)
        ax.text(x, 8, time, ha='center', va='center', fontsize=9, color='#666')
        ax.text(x, 7.5, phase, ha='center', va='center', fontsize=9, weight='bold')

    # 加载内容
    ax.text(1.5, 6, '用户界面:', ha='right', va='center', fontsize=10, weight='bold')

    # 阶段1：骨架屏
    skel_box = FancyBboxPatch((2.5, 4.5), 2, 2.5, boxstyle="round,pad=0.02",
                              facecolor='#E0E0E0', edgecolor='#999', linewidth=1.5)
    ax.add_patch(skel_box)
    ax.text(3.5, 5.75, '骨架屏\n占位符', ha='center', va='center', fontsize=8, color='#666')

    # 阶段2：核心数据
    core_box = FancyBboxPatch((5.5, 4.5), 2, 2.5, boxstyle="round,pad=0.02",
                              facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=1.5)
    ax.add_patch(core_box)
    ax.text(6.5, 6.2, '钱龄: 45天', ha='center', va='center', fontsize=8)
    ax.text(6.5, 5.6, '余额显示', ha='center', va='center', fontsize=8)
    ax.text(6.5, 5, '[加载中...]', ha='center', va='center', fontsize=7, color='#666')

    # 阶段3：图表
    chart_box = FancyBboxPatch((8.5, 4.5), 2, 2.5, boxstyle="round,pad=0.02",
                               facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=1.5)
    ax.add_patch(chart_box)
    ax.text(9.5, 6.2, '钱龄: 45天', ha='center', va='center', fontsize=8)
    ax.text(9.5, 5.6, '趋势图表', ha='center', va='center', fontsize=8)
    ax.text(9.5, 5, '统计数据', ha='center', va='center', fontsize=8)

    # 阶段4：完整
    full_box = FancyBboxPatch((11.5, 4.5), 2, 2.5, boxstyle="round,pad=0.02",
                              facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(full_box)
    ax.text(12.5, 6.5, '完整界面', ha='center', va='center', fontsize=8, weight='bold')
    ax.text(12.5, 5.8, '全部功能', ha='center', va='center', fontsize=8)
    ax.text(12.5, 5.2, '交互就绪', ha='center', va='center', fontsize=8)

    # 用户体验曲线
    ax.text(1.5, 2.5, '体验曲线:', ha='right', va='center', fontsize=10, weight='bold')

    # 绘制体验曲线
    import numpy as np
    x_curve = np.linspace(2, 12, 100)
    y_curve = 1.5 + 1.5 * (1 - np.exp(-(x_curve - 2) / 3))
    ax.plot(x_curve, y_curve, 'g-', lw=2)
    ax.text(12.5, 3, '满意', ha='left', va='center', fontsize=9, color='#388E3C')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_渐进加载时序图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_context_aware():
    """图4：上下文感知适配示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图4  上下文感知适配示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 上下文感知输入
    ax.text(3, 9.5, '上下文输入', ha='center', va='center', fontsize=11, weight='bold')

    contexts = [
        (3, 8.3, '时间上下文\n(早/中/晚)', '#E3F2FD'),
        (3, 6.8, '场景上下文\n(家/公司/商圈)', '#C8E6C9'),
        (3, 5.3, '操作上下文\n(记账/查询/分析)', '#FFE0B2'),
        (3, 3.8, '设备上下文\n(屏幕/网络/电量)', '#E1BEE7'),
    ]
    for x, y, text, color in contexts:
        draw_box(ax, x, y, 3, 1, text, color, 'black', 9)

    # 适配引擎
    engine_box = FancyBboxPatch((6, 4), 3, 5, boxstyle="round,pad=0.02",
                                facecolor='#F5F5F5', edgecolor='#333', linewidth=2)
    ax.add_patch(engine_box)
    ax.text(7.5, 8.5, '适配引擎', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7.5, 7.5, '规则匹配', ha='center', va='center', fontsize=9)
    ax.text(7.5, 6.5, '↓', ha='center', va='center', fontsize=12)
    ax.text(7.5, 5.8, '优先级计算', ha='center', va='center', fontsize=9)
    ax.text(7.5, 5, '↓', ha='center', va='center', fontsize=12)
    ax.text(7.5, 4.3, '界面生成', ha='center', va='center', fontsize=9)

    for y in [8.3, 6.8, 5.3, 3.8]:
        draw_arrow(ax, (4.5, y), (6, 6.5))

    # 适配输出
    ax.text(11, 9.5, '界面适配', ha='center', va='center', fontsize=11, weight='bold')

    outputs = [
        (11, 8, '早晨: 快捷记账优先', '#C8E6C9'),
        (11, 6.5, '商圈: 显示预算提醒', '#FFE0B2'),
        (11, 5, '弱网: 简化加载内容', '#BBDEFB'),
        (11, 3.5, '低电: 减少动画效果', '#E1BEE7'),
    ]
    for x, y, text, color in outputs:
        draw_box(ax, x, y, 3.5, 1, text, color, 'black', 9)

    draw_arrow(ax, (9, 6.5), (9.25, 6.5))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_上下文感知适配示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利09附图...')
    figure1_three_layer_info()
    figure2_user_level_assessment()
    figure3_progressive_loading()
    figure4_context_aware()
    print('专利09全部附图生成完成!')
