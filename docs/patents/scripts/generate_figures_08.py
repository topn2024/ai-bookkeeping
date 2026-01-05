# -*- coding: utf-8 -*-
"""生成专利08的附图：财务数据可视化交互方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_08'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_visualization_components():
    """图1：钱龄可视化组件体系示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图1  钱龄可视化组件体系示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 仪表盘组件
    ax.text(3, 10.3, '仪表盘组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 3, 9, 3.5, 1.8, '钱龄仪表盘\n- 当前钱龄值\n- 健康等级指示\n- 趋势箭头', '#E3F2FD', '#1976D2', 9)

    # 趋势图组件
    ax.text(7.5, 10.3, '趋势图组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 7.5, 9, 3.5, 1.8, '钱龄趋势图\n- 30/90/365天视图\n- 移动平均线\n- 关键节点标注', '#C8E6C9', '#388E3C', 9)

    # 瀑布图组件
    ax.text(12, 10.3, '瀑布图组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 12, 9, 3.5, 1.8, '资金流瀑布图\n- 收入增量(绿)\n- 支出减量(红)\n- 结余连接', '#FFE0B2', '#EF6C00', 9)

    # 桑基图组件
    ax.text(3, 6.3, '桑基图组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 3, 5, 3.5, 1.8, '资金流向图\n- 收入来源\n- 支出去向\n- 流量宽度', '#E1BEE7', '#7B1FA2', 9)

    # 热力图组件
    ax.text(7.5, 6.3, '热力图组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 7.5, 5, 3.5, 1.8, '消费热力图\n- 时间×类别矩阵\n- 颜色深度映射\n- 异常点标识', '#FFCDD2', '#C62828', 9)

    # 饼图组件
    ax.text(12, 6.3, '饼图组件', ha='center', va='center', fontsize=11, weight='bold')
    draw_box(ax, 12, 5, 3.5, 1.8, '分类占比图\n- 支出类别分布\n- 收入来源分布\n- 交互式钻取', '#B2DFDB', '#00796B', 9)

    # 统一交互层
    interact_box = FancyBboxPatch((1.5, 1.5), 11, 2, boxstyle="round,pad=0.02",
                                  facecolor='#F5F5F5', edgecolor='#333', linewidth=2)
    ax.add_patch(interact_box)
    ax.text(7, 3, '统一交互层', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 2.2, '手势操作 | 数据联动 | 下钻导航 | 导出分享', ha='center', va='center', fontsize=10)

    # 连接线
    for x in [3, 7.5, 12]:
        draw_arrow(ax, (x, 8.1), (x, 7))
        ax.plot([x, x], [7, 3.5], 'k--', lw=1, alpha=0.5)

    for x in [3, 7.5, 12]:
        draw_arrow(ax, (x, 4.1), (x, 3.5))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_钱龄可视化组件体系示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_drilldown_interaction():
    """图2：多维度下钻交互流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图2  多维度下钻交互流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 顶层视图
    draw_box(ax, 7, 9, 5, 1.2, '顶层概览\n总体钱龄/收支总览', '#E3F2FD', '#1976D2', 10)

    # 下钻维度
    ax.text(7, 7.5, '下钻维度选择', ha='center', va='center', fontsize=10, weight='bold')

    dimensions = [
        (2.5, 6, '时间维度\n年→月→周→日', '#FFCDD2'),
        (5.5, 6, '类别维度\n大类→子类→商户', '#C8E6C9'),
        (8.5, 6, '账户维度\n全部→单账户→交易', '#BBDEFB'),
        (11.5, 6, '钱龄维度\n等级→区间→单笔', '#FFE0B2'),
    ]
    for x, y, text, color in dimensions:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    ax.plot([2.5, 11.5], [8.4, 8.4], 'k-', lw=1.5)
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_arrow(ax, (x, 8.4), (x, 6.6))

    # 详细视图
    draw_box(ax, 7, 3.5, 6, 1.5, '详细视图\n交易列表 | 详情卡片 | 关联分析', '#E1BEE7', '#7B1FA2', 10)

    ax.plot([2.5, 11.5], [5.4, 5.4], 'k-', lw=1.5)
    draw_arrow(ax, (7, 5.4), (7, 4.25))

    # 交互操作
    ax.text(7, 2, '交互操作', ha='center', va='center', fontsize=10, weight='bold')

    operations = [
        (3.5, 1, '点击下钻', '#E8F5E9'),
        (7, 1, '手势缩放', '#E8F5E9'),
        (10.5, 1, '长按详情', '#E8F5E9'),
    ]
    for x, y, text, color in operations:
        draw_box(ax, x, y, 2.5, 0.7, text, color, 'black', 9)

    # 返回箭头
    ax.annotate('', xy=(12.5, 9), xytext=(12.5, 3.5),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1.5,
                                connectionstyle='arc3,rad=-0.3'))
    ax.text(13.2, 6, '返回\n上层', ha='center', va='center', fontsize=8, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_多维度下钻交互流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_data_linkage():
    """图3：数据联动机制架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图3  数据联动机制架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 数据层
    data_layer = FancyBboxPatch((1, 8), 12, 1.8, boxstyle="round,pad=0.02",
                                facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(data_layer)
    ax.text(7, 9.3, '数据层', ha='center', va='center', fontsize=11, weight='bold')

    data_items = ['交易数据', '钱龄数据', '预算数据', '统计数据']
    for i, text in enumerate(data_items):
        draw_box(ax, 2.5 + i*3, 8.5, 2.2, 0.6, text, '#BBDEFB', 'black', 9)

    # 状态管理层
    state_layer = FancyBboxPatch((1, 5.2), 12, 2, boxstyle="round,pad=0.02",
                                 facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(state_layer)
    ax.text(7, 6.7, '状态管理层 (Provider)', ha='center', va='center', fontsize=11, weight='bold')

    state_items = ['筛选状态', '时间范围', '选中项', '视图模式']
    for i, text in enumerate(state_items):
        draw_box(ax, 2.5 + i*3, 5.7, 2.2, 0.6, text, '#A5D6A7', 'black', 9)

    draw_arrow(ax, (7, 8), (7, 7.2))

    # 联动引擎
    engine_box = FancyBboxPatch((4, 3), 6, 1.5, boxstyle="round,pad=0.02",
                                facecolor='#FFE0B2', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(engine_box)
    ax.text(7, 4, '联动引擎', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 3.4, '事件分发 | 状态同步 | 变更通知', ha='center', va='center', fontsize=9)

    draw_arrow(ax, (7, 5.2), (7, 4.5))

    # 视图层
    ax.text(7, 2, '视图层 (自动刷新)', ha='center', va='center', fontsize=10, weight='bold')

    views = [
        (2.5, 1, '仪表盘', '#E1BEE7'),
        (5, 1, '趋势图', '#E1BEE7'),
        (7.5, 1, '列表', '#E1BEE7'),
        (10, 1, '详情', '#E1BEE7'),
    ]
    for x, y, text, color in views:
        draw_box(ax, x, y, 2, 0.7, text, color, 'black', 9)

    ax.plot([2.5, 10], [1.7, 1.7], 'k-', lw=1.5)
    draw_arrow(ax, (7, 3), (7, 2.3))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_数据联动机制架构图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_insight_generation():
    """图4：智能洞察生成流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图4  智能洞察生成流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '数据聚合分析', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    draw_box(ax, 6, 8.8, 4, 0.9, '模式识别引擎', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.75), (6, 9.25))

    # 洞察类型
    ax.text(6, 7.5, '洞察类型生成', ha='center', va='center', fontsize=10, weight='bold')

    insights = [
        (3, 6.3, '趋势洞察\n钱龄上升/下降', '#C8E6C9'),
        (6, 6.3, '异常洞察\n超支/突增消费', '#FFCDD2'),
        (9, 6.3, '建议洞察\n优化建议', '#FFE0B2'),
    ]
    for x, y, text, color in insights:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (6, 8.35), (6, 7.8))
    ax.plot([3, 9], [7.8, 7.8], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 7.8), (x, 6.9))

    draw_box(ax, 6, 4.5, 4.5, 1, '自然语言生成\n(NLG模板)', '#E1BEE7', 'black', 10)
    ax.plot([3, 9], [5.7, 5.7], 'k-', lw=1.5)
    draw_arrow(ax, (6, 5.7), (6, 5))

    draw_box(ax, 6, 3, 4.5, 1, '优先级排序\n(重要性/时效性)', '#FFF3E0', 'black', 10)
    draw_arrow(ax, (6, 4), (6, 3.5))

    output_box = FancyBboxPatch((3, 1), 6, 1.2, boxstyle="round,pad=0.02",
                                facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(output_box)
    ax.text(6, 1.6, '智能洞察卡片输出', ha='center', va='center', fontsize=10, weight='bold')
    draw_arrow(ax, (6, 2.5), (6, 2.2))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_智能洞察生成流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利08附图...')
    figure1_visualization_components()
    figure2_drilldown_interaction()
    figure3_data_linkage()
    figure4_insight_generation()
    print('专利08全部附图生成完成!')
