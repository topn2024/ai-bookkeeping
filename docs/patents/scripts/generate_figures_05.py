# -*- coding: utf-8 -*-
"""生成专利05的附图：四维语音交互方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon, Wedge
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_05'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    """绘制带文字的方框"""
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize, wrap=True)

def draw_arrow(ax, start, end, color='black'):
    """绘制箭头"""
    ax.annotate('', xy=end, xytext=start,
                arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_four_dimension_classification():
    """图1：四维意图分类体系示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图1  四维意图分类体系示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 中心：语音输入
    center_circle = Circle((7, 6), 1.2, facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=3)
    ax.add_patch(center_circle)
    ax.text(7, 6, '语音\n输入', ha='center', va='center', fontsize=12, weight='bold')

    # 四个维度
    dimensions = [
        (7, 10, '第一维度：记账', '#FFCDD2', '#C62828',
         ['快捷记账', '语音录入', '批量记账', '定时记账']),
        (12, 6, '第二维度：配置', '#C8E6C9', '#388E3C',
         ['预算设置', '类别管理', '账户配置', '提醒设置']),
        (7, 2, '第三维度：导航', '#BBDEFB', '#1976D2',
         ['页面跳转', '功能切换', '返回操作', '刷新更新']),
        (2, 6, '第四维度：查询', '#FFE0B2', '#EF6C00',
         ['余额查询', '账单查询', '统计报表', '钱龄分析']),
    ]

    for x, y, title, facecolor, edgecolor, items in dimensions:
        # 维度标题框
        main_box = FancyBboxPatch((x - 2, y - 0.5), 4, 1, boxstyle="round,pad=0.02",
                                  facecolor=facecolor, edgecolor=edgecolor, linewidth=2)
        ax.add_patch(main_box)
        ax.text(x, y, title, ha='center', va='center', fontsize=11, weight='bold')

        # 子项
        if y > 6:  # 上方
            for i, item in enumerate(items):
                draw_box(ax, x - 1.5 + i*1, y + 1.5, 0.9, 0.6, item, facecolor, edgecolor, 7)
        elif y < 6:  # 下方
            for i, item in enumerate(items):
                draw_box(ax, x - 1.5 + i*1, y - 1.5, 0.9, 0.6, item, facecolor, edgecolor, 7)
        elif x > 7:  # 右侧
            for i, item in enumerate(items):
                draw_box(ax, x + 2.5, y + 1.5 - i*1, 1.5, 0.6, item, facecolor, edgecolor, 8)
        else:  # 左侧
            for i, item in enumerate(items):
                draw_box(ax, x - 2.5, y + 1.5 - i*1, 1.5, 0.6, item, facecolor, edgecolor, 8)

    # 连接线
    draw_arrow(ax, (7, 7.2), (7, 9.5))
    draw_arrow(ax, (8.2, 6), (10, 6))
    draw_arrow(ax, (7, 4.8), (7, 2.5))
    draw_arrow(ax, (5.8, 6), (4, 6))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_四维意图分类体系示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_intent_recognition():
    """图2：意图识别流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图2  意图识别流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 语音输入
    draw_box(ax, 7, 10.3, 3.5, 0.9, '语音输入', '#E3F2FD', 'black', 11)

    # ASR转文本
    draw_box(ax, 7, 9.0, 3.5, 0.9, 'ASR语音转文本', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (7, 9.85), (7, 9.45))

    # 意图分类器
    draw_box(ax, 7, 7.5, 4, 1.0, '四维意图分类器', '#C5CAE9', 'black', 11)
    draw_arrow(ax, (7, 8.55), (7, 8))

    # 四维分支
    ax.text(7, 6.3, '意图类别', ha='center', va='center', fontsize=10, weight='bold')

    intents = [
        (2, 5, '记账意图', '#FFCDD2'),
        (5, 5, '配置意图', '#C8E6C9'),
        (9, 5, '导航意图', '#BBDEFB'),
        (12, 5, '查询意图', '#FFE0B2'),
    ]
    for x, y, text, color in intents:
        draw_box(ax, x, y, 2.2, 0.8, text, color, 'black', 9)

    ax.plot([2, 12], [6, 6], 'k-', lw=1.5)
    draw_arrow(ax, (7, 7), (7, 6.3))
    for x in [2, 5, 9, 12]:
        draw_arrow(ax, (x, 6), (x, 5.4))

    # 槽位填充
    slots = [
        (2, 3.5, '金额/类别/\n商户/日期', '#EF9A9A'),
        (5, 3.5, '配置项/\n参数值', '#A5D6A7'),
        (9, 3.5, '目标页面/\n操作类型', '#90CAF9'),
        (12, 3.5, '查询条件/\n时间范围', '#FFCC80'),
    ]
    for x, y, text, color in slots:
        draw_box(ax, x, y, 2.2, 1.0, text, color, 'black', 9)
        draw_arrow(ax, (x, 4.6), (x, 4))

    ax.text(7, 4.3, '槽位填充', ha='center', va='center', fontsize=10, weight='bold', color='#666')

    # 执行动作
    actions = [
        (2, 2, '创建交易', '#FFCDD2'),
        (5, 2, '修改设置', '#C8E6C9'),
        (9, 2, '页面跳转', '#BBDEFB'),
        (12, 2, '返回结果', '#FFE0B2'),
    ]
    for x, y, text, color in actions:
        draw_box(ax, x, y, 2.2, 0.8, text, color, 'black', 9)
        draw_arrow(ax, (x, 3), (x, 2.4))

    ax.text(7, 2.7, '执行动作', ha='center', va='center', fontsize=10, weight='bold', color='#666')

    # 反馈
    draw_box(ax, 7, 0.7, 4, 0.8, '语音/视觉反馈', '#E8F5E9', 'black', 10)
    ax.plot([2, 12], [1.6, 1.6], 'k-', lw=1.5)
    draw_arrow(ax, (7, 1.6), (7, 1.1))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_意图识别流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_dialog_state_machine():
    """图3：多轮对话状态机示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图3  多轮对话状态机示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 状态节点
    states = [
        (2, 8, '空闲状态', '#E0E0E0'),
        (7, 8, '意图识别', '#E3F2FD'),
        (12, 8, '槽位收集', '#BBDEFB'),
        (12, 5, '确认状态', '#FFF3E0'),
        (7, 5, '执行状态', '#C8E6C9'),
        (2, 5, '反馈状态', '#E8F5E9'),
        (7, 2, '结束状态', '#E0E0E0'),
    ]

    for x, y, text, color in states:
        circle = Circle((x, y), 1.0, facecolor=color, edgecolor='#333', linewidth=2)
        ax.add_patch(circle)
        ax.text(x, y, text, ha='center', va='center', fontsize=9, weight='bold')

    # 状态转换箭头和标签
    # 空闲 -> 意图识别
    draw_arrow(ax, (3, 8), (6, 8))
    ax.text(4.5, 8.3, '语音唤醒', ha='center', va='center', fontsize=8, color='#1976D2')

    # 意图识别 -> 槽位收集
    draw_arrow(ax, (8, 8), (11, 8))
    ax.text(9.5, 8.3, '意图明确', ha='center', va='center', fontsize=8, color='#1976D2')

    # 槽位收集 -> 确认状态
    draw_arrow(ax, (12, 7), (12, 6))
    ax.text(12.5, 6.5, '槽位完整', ha='center', va='center', fontsize=8, color='#1976D2')

    # 确认状态 -> 执行状态
    draw_arrow(ax, (11, 5), (8, 5))
    ax.text(9.5, 5.3, '用户确认', ha='center', va='center', fontsize=8, color='#388E3C')

    # 执行状态 -> 反馈状态
    draw_arrow(ax, (6, 5), (3, 5))
    ax.text(4.5, 5.3, '执行完成', ha='center', va='center', fontsize=8, color='#388E3C')

    # 反馈状态 -> 结束/空闲
    draw_arrow(ax, (2, 4), (2, 2.5))
    ax.plot([2, 7], [2.5, 2.5], 'k-', lw=1.5)
    draw_arrow(ax, (7, 2.5), (7, 3))
    ax.text(4.5, 2.3, '对话结束', ha='center', va='center', fontsize=8, color='#666')

    # 反馈状态 -> 空闲（继续）
    ax.annotate('', xy=(2, 7), xytext=(2, 6),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1.5))
    ax.text(1.3, 6.5, '继续\n对话', ha='center', va='center', fontsize=7, color='#666')

    # 槽位收集循环
    ax.annotate('', xy=(12.8, 8.8), xytext=(12.8, 7.2),
                arrowprops=dict(arrowstyle='->', color='#EF6C00', lw=1.5,
                                connectionstyle='arc3,rad=0.5'))
    ax.text(13.5, 8, '追问\n槽位', ha='center', va='center', fontsize=7, color='#EF6C00')

    # 确认状态取消
    ax.annotate('', xy=(7, 8.8), xytext=(11.2, 5.8),
                arrowprops=dict(arrowstyle='->', color='#C62828', lw=1,
                                connectionstyle='arc3,rad=0.3'))
    ax.text(10, 7.2, '取消', ha='center', va='center', fontsize=7, color='#C62828')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_多轮对话状态机示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


if __name__ == '__main__':
    print('开始生成专利05附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_four_dimension_classification()
    figure2_intent_recognition()
    figure3_dialog_state_machine()
    print('专利05全部附图生成完成!')
