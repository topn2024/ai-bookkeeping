# -*- coding: utf-8 -*-
"""生成专利04的附图：零基预算动态分配方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_04'
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


def figure1_vault_architecture():
    """图1：小金库模型架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图1  小金库模型架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 收入池
    income_box = FancyBboxPatch((5.5, 8.5), 3, 1.3, boxstyle="round,pad=0.02",
                                facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(income_box)
    ax.text(7, 9.3, '收入池', ha='center', va='center', fontsize=12, weight='bold')
    ax.text(7, 8.8, '(待分配资金)', ha='center', va='center', fontsize=9)

    # 分配箭头
    draw_arrow(ax, (7, 8.5), (7, 7.8))
    ax.text(7.5, 8.15, '零基分配', ha='left', va='center', fontsize=9, color='#666')

    # 小金库层
    ax.text(7, 7.3, '小金库层 (预算单元)', ha='center', va='center', fontsize=11, weight='bold')

    vaults = [
        (2, 5.8, '餐饮金库\n预算:2000\n已用:800', '#FFECB3', '#FF9800'),
        (5, 5.8, '交通金库\n预算:500\n已用:200', '#BBDEFB', '#1976D2'),
        (8, 5.8, '娱乐金库\n预算:1000\n已用:600', '#F8BBD9', '#C2185B'),
        (11, 5.8, '储蓄金库\n预算:3000\n已用:0', '#C8E6C9', '#388E3C'),
    ]
    for x, y, text, facecolor, edgecolor in vaults:
        box = FancyBboxPatch((x - 1.3, y - 0.9), 2.6, 1.8, boxstyle="round,pad=0.02",
                             facecolor=facecolor, edgecolor=edgecolor, linewidth=2)
        ax.add_patch(box)
        ax.text(x, y, text, ha='center', va='center', fontsize=9)

    # 分配连接
    ax.plot([2, 11], [7, 7], 'k-', lw=1.5)
    for x in [2, 5, 8, 11]:
        draw_arrow(ax, (x, 7), (x, 6.7))

    # 进度条
    progress_data = [
        (2, 4.5, 0.4, '#FF9800'),  # 40%
        (5, 4.5, 0.4, '#1976D2'),   # 40%
        (8, 4.5, 0.6, '#C2185B'),   # 60%
        (11, 4.5, 0.0, '#388E3C'),  # 0%
    ]
    for x, y, ratio, color in progress_data:
        # 背景
        bg = Rectangle((x - 1.1, y - 0.15), 2.2, 0.3, facecolor='#E0E0E0', edgecolor='#999')
        ax.add_patch(bg)
        # 进度
        if ratio > 0:
            fg = Rectangle((x - 1.1, y - 0.15), 2.2 * ratio, 0.3, facecolor=color)
            ax.add_patch(fg)
        ax.text(x, y, f'{int(ratio*100)}%', ha='center', va='center', fontsize=8)

    # 消费拦截层
    ax.text(7, 3.5, '消费拦截层', ha='center', va='center', fontsize=11, weight='bold')

    intercept_box = FancyBboxPatch((3, 2.2), 8, 1, boxstyle="round,pad=0.02",
                                   facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(intercept_box)
    ax.text(7, 2.7, '预算超支拦截 | 透支预警 | 调拨建议', ha='center', va='center', fontsize=10)

    # 连接
    ax.plot([2, 11], [4.2, 4.2], 'k--', lw=1, alpha=0.5)
    draw_arrow(ax, (7, 4.2), (7, 3.2))

    # 报表输出
    draw_box(ax, 7, 1, 5, 0.8, '预算执行报表 | 分析建议', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (7, 2.2), (7, 1.4))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_小金库模型架构图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_four_layer_allocation():
    """图2：四层零基分配流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图2  四层零基分配流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 第一层：必要支出
    layer1 = FancyBboxPatch((1, 9), 12, 1.8, boxstyle="round,pad=0.02",
                            facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(layer1)
    ax.text(2, 10.3, '第一层', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(2, 9.8, '必要支出', ha='center', va='center', fontsize=9)
    ax.text(2, 9.4, '(优先级1)', ha='center', va='center', fontsize=8, color='#666')

    layer1_items = ['房租/房贷', '水电燃气', '基本餐饮', '通勤交通']
    for i, item in enumerate(layer1_items):
        draw_box(ax, 5 + i*2.2, 9.9, 2, 0.7, item, '#EF9A9A', 'black', 8)

    # 第二层：重要支出
    layer2 = FancyBboxPatch((1, 6.5), 12, 1.8, boxstyle="round,pad=0.02",
                            facecolor='#FFE0B2', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(layer2)
    ax.text(2, 7.8, '第二层', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(2, 7.3, '重要支出', ha='center', va='center', fontsize=9)
    ax.text(2, 6.9, '(优先级2)', ha='center', va='center', fontsize=8, color='#666')

    layer2_items = ['医疗保险', '教育培训', '通讯费用', '日用品']
    for i, item in enumerate(layer2_items):
        draw_box(ax, 5 + i*2.2, 7.4, 2, 0.7, item, '#FFCC80', 'black', 8)

    # 第三层：可选支出
    layer3 = FancyBboxPatch((1, 4), 12, 1.8, boxstyle="round,pad=0.02",
                            facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(layer3)
    ax.text(2, 5.3, '第三层', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(2, 4.8, '可选支出', ha='center', va='center', fontsize=9)
    ax.text(2, 4.4, '(优先级3)', ha='center', va='center', fontsize=8, color='#666')

    layer3_items = ['餐饮升级', '娱乐休闲', '服装购物', '社交活动']
    for i, item in enumerate(layer3_items):
        draw_box(ax, 5 + i*2.2, 4.9, 2, 0.7, item, '#A5D6A7', 'black', 8)

    # 第四层：储蓄投资
    layer4 = FancyBboxPatch((1, 1.5), 12, 1.8, boxstyle="round,pad=0.02",
                            facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer4)
    ax.text(2, 2.8, '第四层', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(2, 2.3, '储蓄投资', ha='center', va='center', fontsize=9)
    ax.text(2, 1.9, '(优先级4)', ha='center', va='center', fontsize=8, color='#666')

    layer4_items = ['应急基金', '定期储蓄', '理财投资', '目标储蓄']
    for i, item in enumerate(layer4_items):
        draw_box(ax, 5 + i*2.2, 2.4, 2, 0.7, item, '#90CAF9', 'black', 8)

    # 分配方向箭头
    for y in [8.8, 6.3, 3.8]:
        draw_arrow(ax, (7, y + 0.2), (7, y - 0.2))
    ax.text(7.5, 8.5, '剩余资金', ha='left', va='center', fontsize=8, color='#666')
    ax.text(7.5, 6.0, '剩余资金', ha='left', va='center', fontsize=8, color='#666')
    ax.text(7.5, 3.5, '剩余资金', ha='left', va='center', fontsize=8, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_四层零基分配流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_consumption_intercept():
    """图3：消费拦截流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 12.5, '图3  消费拦截流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 消费请求
    draw_box(ax, 6, 10.3, 4, 0.9, '检测到消费请求', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.75))

    # 匹配小金库
    draw_box(ax, 6, 9.0, 4, 0.9, '匹配对应小金库', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.85), (6, 9.45))

    # 判断1：余额是否充足
    diamond1 = Polygon([(6, 8.1), (7.5, 7.4), (6, 6.7), (4.5, 7.4)],
                       facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond1)
    ax.text(6, 7.4, '余额\n充足?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.55), (6, 8.1))

    # 是 - 允许消费
    draw_box(ax, 9.5, 7.4, 2.5, 0.7, '允许消费', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (7.5, 7.4), (8.25, 7.4))
    ax.text(7.9, 7.65, '是', ha='center', va='center', fontsize=8)

    # 否 - 透支预警
    draw_box(ax, 6, 5.8, 3.5, 0.8, '触发透支预警', '#FFCDD2', 'black', 10)
    draw_arrow(ax, (6, 6.7), (6, 6.2))
    ax.text(6.2, 6.4, '否', ha='center', va='center', fontsize=8)

    # 提供选项
    ax.text(6, 4.9, '用户选择', ha='center', va='center', fontsize=10, weight='bold')

    options = [
        (3, 3.8, '取消消费', '#FFCDD2'),
        (6, 3.8, '从其他金库\n调拨资金', '#FFE0B2'),
        (9, 3.8, '标记为\n计划外支出', '#E1BEE7'),
    ]
    for x, y, text, color in options:
        draw_box(ax, x, y, 2.5, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (6, 5.4), (6, 4.5))
    ax.plot([3, 9], [4.5, 4.5], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 4.5), (x, 4.3))

    # 调拨流程
    draw_box(ax, 6, 2.3, 4, 0.8, '执行资金调拨', '#FFE0B2', 'black', 10)
    draw_arrow(ax, (6, 3.3), (6, 2.7))

    # 更新记录
    draw_box(ax, 6, 1.2, 4, 0.8, '更新预算记录', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (6, 1.9), (6, 1.6))

    # 结束连接
    ax.plot([3, 3], [3.3, 0.5], 'k-', lw=1.5)
    ax.plot([9, 9], [3.3, 0.5], 'k-', lw=1.5)
    ax.plot([9.5, 9.5], [7.05, 0.5], 'k-', lw=1.5)
    ax.plot([3, 9.5], [0.5, 0.5], 'k-', lw=1.5)
    draw_arrow(ax, (6, 0.8), (6, 0.5))

    # 结束
    circle_end = Circle((6, 0.2), 0.25, facecolor='#333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(6, 0.2, '结束', ha='center', va='center', fontsize=8, color='white')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_消费拦截流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


if __name__ == '__main__':
    print('开始生成专利04附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_vault_architecture()
    figure2_four_layer_allocation()
    figure3_consumption_intercept()
    print('专利04全部附图生成完成!')
