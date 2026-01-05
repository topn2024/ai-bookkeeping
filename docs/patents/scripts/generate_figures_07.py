# -*- coding: utf-8 -*-
"""生成专利07的附图：多因子交易去重方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_07'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_three_layer_dedup():
    """图1：三层去重架构流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图1  三层去重架构流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入
    draw_box(ax, 7, 10.3, 4, 0.9, '待导入交易记录', '#E3F2FD', 'black', 11)

    # 第一层
    layer1 = FancyBboxPatch((1.5, 7.8), 11, 2, boxstyle="round,pad=0.02",
                            facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(layer1)
    ax.text(7, 9.4, '第一层：精确匹配', ha='center', va='center', fontsize=11, weight='bold')

    items1 = [('金额', 3.5), ('时间戳', 6), ('商户名', 8.5), ('交易号', 11)]
    for text, x in items1:
        draw_box(ax, x, 8.4, 1.8, 0.6, text, '#EF9A9A', 'black', 9)

    draw_arrow(ax, (7, 9.85), (7, 9.8))

    # 第二层
    layer2 = FancyBboxPatch((1.5, 5), 11, 2, boxstyle="round,pad=0.02",
                            facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(layer2)
    ax.text(7, 6.6, '第二层：特征匹配', ha='center', va='center', fontsize=11, weight='bold')

    items2 = [('金额容差', 3.5), ('时间窗口', 6), ('商户相似', 8.5), ('类别匹配', 11)]
    for text, x in items2:
        draw_box(ax, x, 5.6, 1.8, 0.6, text, '#A5D6A7', 'black', 9)

    draw_arrow(ax, (7, 7.8), (7, 7))

    # 第三层
    layer3 = FancyBboxPatch((1.5, 2.2), 11, 2, boxstyle="round,pad=0.02",
                            facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer3)
    ax.text(7, 3.8, '第三层：语义匹配', ha='center', va='center', fontsize=11, weight='bold')

    items3 = [('备注相似度', 4), ('消费模式', 7), ('上下文关联', 10)]
    for text, x in items3:
        draw_box(ax, x, 2.8, 2.2, 0.6, text, '#90CAF9', 'black', 9)

    draw_arrow(ax, (7, 5), (7, 4.2))

    # 输出
    draw_box(ax, 7, 1, 4, 0.8, '去重后交易列表', '#E8F5E9', 'black', 11)
    draw_arrow(ax, (7, 2.2), (7, 1.4))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_三层去重架构流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_multi_factor_scoring():
    """图2：多因子评分模型示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图2  多因子评分模型示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 评分因子
    ax.text(3, 9.5, '评分因子', ha='center', va='center', fontsize=12, weight='bold')

    factors = [
        (3, 8.3, '金额相似度', '权重: 0.25', '#FFCDD2'),
        (3, 7.1, '时间接近度', '权重: 0.20', '#C8E6C9'),
        (3, 5.9, '商户匹配度', '权重: 0.20', '#BBDEFB'),
        (3, 4.7, '类别一致性', '权重: 0.15', '#FFE0B2'),
        (3, 3.5, '备注相似度', '权重: 0.10', '#E1BEE7'),
        (3, 2.3, '来源一致性', '权重: 0.05', '#B2DFDB'),
        (3, 1.1, '频率匹配度', '权重: 0.05', '#F0F4C3'),
    ]
    for x, y, name, weight, color in factors:
        draw_box(ax, x, y, 2.8, 0.8, f'{name}\n{weight}', color, 'black', 8)

    # 评分计算
    calc_box = FancyBboxPatch((6, 3.5), 3.5, 5, boxstyle="round,pad=0.02",
                              facecolor='#E8EAF6', edgecolor='#3F51B5', linewidth=2)
    ax.add_patch(calc_box)
    ax.text(7.75, 8, '加权评分计算', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7.75, 7, 'Score = ', ha='center', va='center', fontsize=10)
    ax.text(7.75, 6.2, 'Sum(Fi × Wi)', ha='center', va='center', fontsize=10)
    ax.text(7.75, 5, '归一化处理', ha='center', va='center', fontsize=9)
    ax.text(7.75, 4.2, '[0, 1]', ha='center', va='center', fontsize=10)

    for y in [8.3, 7.1, 5.9, 4.7, 3.5, 2.3, 1.1]:
        draw_arrow(ax, (4.4, y), (6, 6))

    # 阈值判定
    ax.text(11.5, 9, '阈值判定', ha='center', va='center', fontsize=11, weight='bold')

    thresholds = [
        (11.5, 7.5, 'Score >= 0.9', '确认重复', '#FFCDD2'),
        (11.5, 6, '0.7 <= S < 0.9', '疑似重复', '#FFF3E0'),
        (11.5, 4.5, 'Score < 0.7', '非重复', '#C8E6C9'),
    ]
    for x, y, cond, result, color in thresholds:
        draw_box(ax, x, y, 3, 1, f'{cond}\n→ {result}', color, 'black', 9)

    draw_arrow(ax, (9.5, 6), (10, 6))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_多因子评分模型示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_adaptive_learning():
    """图3：自适应学习流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图3  自适应学习流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '系统识别疑似重复', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    draw_box(ax, 6, 8.8, 4, 0.9, '提交用户确认', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.75), (6, 9.25))

    diamond = Polygon([(6, 7.9), (7.5, 7.2), (6, 6.5), (4.5, 7.2)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 7.2, '用户\n反馈?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.35), (6, 7.9))

    draw_box(ax, 3, 7.2, 2.2, 0.7, '确认重复', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (4.5, 7.2), (4.1, 7.2))

    draw_box(ax, 9, 7.2, 2.2, 0.7, '非重复', '#FFCDD2', 'black', 9)
    draw_arrow(ax, (7.5, 7.2), (7.9, 7.2))

    draw_box(ax, 3, 5.5, 3, 0.9, '正向样本收集', '#A5D6A7', 'black', 9)
    draw_arrow(ax, (3, 6.85), (3, 5.95))

    draw_box(ax, 9, 5.5, 3, 0.9, '负向样本收集', '#EF9A9A', 'black', 9)
    draw_arrow(ax, (9, 6.85), (9, 5.95))

    draw_box(ax, 6, 4, 4.5, 1, '特征权重更新\n梯度下降优化', '#E1BEE7', 'black', 10)
    ax.plot([3, 9], [5.05, 5.05], 'k-', lw=1.5)
    draw_arrow(ax, (6, 5.05), (6, 4.5))

    draw_box(ax, 6, 2.5, 4, 0.9, '阈值动态调整', '#FFF3E0', 'black', 10)
    draw_arrow(ax, (6, 3.5), (6, 2.95))

    draw_box(ax, 6, 1.2, 4, 0.8, '模型版本更新', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (6, 2.05), (6, 1.6))

    ax.annotate('', xy=(6, 10.65), xytext=(10.5, 1.2),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1,
                                connectionstyle='arc3,rad=-0.3'))
    ax.text(11, 6, '持续\n迭代', ha='center', va='center', fontsize=8, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_自适应学习流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_candidate_filter():
    """图4：候选集筛选优化示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 9.5, '图4  候选集筛选优化示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 全量数据
    draw_box(ax, 2, 7.5, 3, 1.2, '全量交易数据\nN = 10000', '#E0E0E0', 'black', 10)

    # 时间窗口过滤
    draw_box(ax, 6, 7.5, 3, 1.2, '时间窗口过滤\n±7天范围', '#FFCDD2', 'black', 10)
    draw_arrow(ax, (3.5, 7.5), (4.5, 7.5))
    ax.text(4, 8, '→ N=500', ha='center', va='center', fontsize=8, color='#666')

    # 金额区间过滤
    draw_box(ax, 10, 7.5, 3, 1.2, '金额区间过滤\n±10%容差', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (7.5, 7.5), (8.5, 7.5))
    ax.text(8, 8, '→ N=50', ha='center', va='center', fontsize=8, color='#666')

    # 候选集
    draw_box(ax, 7, 5, 4, 1.2, '候选交易集合\nN = 50', '#BBDEFB', 'black', 11)
    draw_arrow(ax, (10, 6.9), (10, 5.8))
    ax.plot([7, 10], [5.8, 5.8], 'k-', lw=1.5)

    # 精细比对
    draw_box(ax, 7, 3, 5, 1.5, '精细多因子比对\n(仅对候选集)', '#E1BEE7', 'black', 11)
    draw_arrow(ax, (7, 4.4), (7, 3.75))

    # 性能对比
    perf_box = FancyBboxPatch((2, 0.8), 10, 1.5, boxstyle="round,pad=0.02",
                              facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=1.5)
    ax.add_patch(perf_box)
    ax.text(7, 1.9, '性能优化效果', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(7, 1.3, '比对次数: 10000×10000 → 50×50  |  时间复杂度: O(N²) → O(N)',
           ha='center', va='center', fontsize=9)

    draw_arrow(ax, (7, 2.25), (7, 2.3))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_候选集筛选优化示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利07附图...')
    figure1_three_layer_dedup()
    figure2_multi_factor_scoring()
    figure3_adaptive_learning()
    figure4_candidate_filter()
    print('专利07全部附图生成完成!')
