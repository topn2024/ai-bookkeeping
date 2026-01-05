# -*- coding: utf-8 -*-
"""生成专利12的附图：隐私保护协同学习方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_12'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_three_layer_learning():
    """图1：三层学习架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图1  隐私保护三层学习架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 第一层：个体学习
    layer1 = FancyBboxPatch((1, 8.2), 12, 2.3, boxstyle="round,pad=0.02",
                            facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer1)
    ax.text(7, 10, '第一层：个体学习 (本地隐私)', ha='center', va='center', fontsize=12, weight='bold')

    layer1_items = [
        (3, 8.8, '本地数据', '#BBDEFB'),
        (6, 8.8, '本地训练', '#BBDEFB'),
        (9, 8.8, '个性化模型', '#BBDEFB'),
    ]
    for x, y, text, color in layer1_items:
        draw_box(ax, x, y, 2.5, 0.8, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 8.8), (4.75, 8.8))
    draw_arrow(ax, (7.25, 8.8), (7.75, 8.8))

    # 隐私屏障
    barrier = FancyBboxPatch((1, 7.5), 12, 0.5, boxstyle="round,pad=0.01",
                             facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(barrier)
    ax.text(7, 7.75, '差分隐私屏障 (DP Noise)', ha='center', va='center', fontsize=9, weight='bold')

    # 第二层：协同学习
    layer2 = FancyBboxPatch((1, 4.5), 12, 2.5, boxstyle="round,pad=0.02",
                            facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(layer2)
    ax.text(7, 6.5, '第二层：协同学习 (联邦隐私)', ha='center', va='center', fontsize=12, weight='bold')

    layer2_items = [
        (3, 5.2, '梯度加密', '#A5D6A7'),
        (6, 5.2, '安全聚合', '#A5D6A7'),
        (9, 5.2, '全局模型', '#A5D6A7'),
    ]
    for x, y, text, color in layer2_items:
        draw_box(ax, x, y, 2.5, 0.8, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 5.2), (4.75, 5.2))
    draw_arrow(ax, (7.25, 5.2), (7.75, 5.2))

    draw_arrow(ax, (7, 7.5), (7, 7))

    # 第三层：迁移学习
    layer3 = FancyBboxPatch((1, 1.5), 12, 2.5, boxstyle="round,pad=0.02",
                            facecolor='#FFE0B2', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(layer3)
    ax.text(7, 3.5, '第三层：迁移学习 (知识蒸馏)', ha='center', va='center', fontsize=12, weight='bold')

    layer3_items = [
        (3, 2.2, '基础模型', '#FFCC80'),
        (6, 2.2, '领域适配', '#FFCC80'),
        (9, 2.2, '轻量部署', '#FFCC80'),
    ]
    for x, y, text, color in layer3_items:
        draw_box(ax, x, y, 2.5, 0.8, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 2.2), (4.75, 2.2))
    draw_arrow(ax, (7.25, 2.2), (7.75, 2.2))

    draw_arrow(ax, (7, 4.5), (7, 4))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_隐私保护三层学习架构示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_differential_privacy():
    """图2：本地差分隐私处理流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图2  本地差分隐私处理流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '本地模型梯度计算', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    draw_box(ax, 6, 8.8, 4.5, 0.9, '梯度裁剪\n(Gradient Clipping)', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.75), (6, 9.25))

    # 噪声添加
    noise_box = FancyBboxPatch((3.5, 6.5), 5, 1.8, boxstyle="round,pad=0.02",
                               facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(noise_box)
    ax.text(6, 7.8, '添加高斯噪声', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(6, 7.0, 'noise ~ N(0, sigma^2)', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.35), (6, 8.3))

    # 隐私预算
    draw_box(ax, 6, 5.2, 4.5, 1, '隐私预算计算\nepsilon-delta', '#FFF3E0', 'black', 10)
    draw_arrow(ax, (6, 6.5), (6, 5.7))

    diamond = Polygon([(6, 4.3), (7.3, 3.7), (6, 3.1), (4.7, 3.7)],
                      facecolor='#E1BEE7', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 3.7, '预算\n充足?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 4.7), (6, 4.3))

    draw_box(ax, 9.5, 3.7, 2.5, 0.7, '上传梯度', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (7.3, 3.7), (8.25, 3.7))
    ax.text(7.7, 3.95, '是', ha='center', va='center', fontsize=8)

    draw_box(ax, 2.5, 3.7, 2.5, 0.7, '暂停学习', '#FFCDD2', 'black', 9)
    draw_arrow(ax, (4.7, 3.7), (3.75, 3.7))
    ax.text(4.3, 3.95, '否', ha='center', va='center', fontsize=8)

    draw_box(ax, 6, 1.8, 4.5, 1, '隐私保护的\n梯度上传完成', '#E8F5E9', 'black', 10)
    ax.plot([2.5, 9.5], [3.35, 3.35], 'k-', lw=1.5)
    draw_arrow(ax, (6, 3.35), (6, 2.3))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_本地差分隐私处理流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_secure_aggregation():
    """图3：安全聚合协议流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图3  安全聚合协议流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 客户端
    ax.text(3.5, 10.5, '客户端集群', ha='center', va='center', fontsize=11, weight='bold')

    clients = [
        (2, 9, 'Client A', '#E3F2FD'),
        (3.5, 9, 'Client B', '#E3F2FD'),
        (5, 9, 'Client C', '#E3F2FD'),
    ]
    for x, y, text, color in clients:
        draw_box(ax, x, y, 1.8, 0.8, text, color, '#1976D2', 8)

    ax.text(6, 9, '...', ha='center', va='center', fontsize=14)

    # 加密梯度
    ax.text(3.5, 7.5, '加密梯度', ha='center', va='center', fontsize=10, weight='bold')

    encrypts = [
        (2, 6.5, 'Enc(g_A)', '#FFCDD2'),
        (3.5, 6.5, 'Enc(g_B)', '#FFCDD2'),
        (5, 6.5, 'Enc(g_C)', '#FFCDD2'),
    ]
    for x, y, text, color in encrypts:
        draw_box(ax, x, y, 1.8, 0.7, text, color, 'black', 8)
        draw_arrow(ax, (x, 8.6), (x, 6.85))

    # 聚合服务器
    server_box = FancyBboxPatch((7.5, 4.5), 5, 4.5, boxstyle="round,pad=0.02",
                                facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(server_box)
    ax.text(10, 8.5, '安全聚合服务器', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(10, 7.5, '密态聚合', ha='center', va='center', fontsize=10)
    ax.text(10, 6.5, 'Sum(Enc(g_i))', ha='center', va='center', fontsize=9)
    ax.text(10, 5.5, '↓', ha='center', va='center', fontsize=14)
    ax.text(10, 4.8, '联合解密', ha='center', va='center', fontsize=10)

    # 上传箭头
    ax.plot([2, 5], [6.15, 6.15], 'k-', lw=1.5)
    draw_arrow(ax, (3.5, 6.15), (7.5, 6.5))

    # 全局模型
    draw_box(ax, 10, 2.5, 4, 1.2, '全局模型更新\n(仅聚合结果可见)', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (10, 4.5), (10, 3.1))

    # 下发
    ax.text(3.5, 2.5, '模型下发', ha='center', va='center', fontsize=10, weight='bold')
    ax.annotate('', xy=(6, 2.5), xytext=(8, 2.5),
                arrowprops=dict(arrowstyle='<-', color='#388E3C', lw=2))

    for x in [2, 3.5, 5]:
        draw_box(ax, x, 1.5, 1.8, 0.7, '更新本地', '#E3F2FD', 'black', 8)
        draw_arrow(ax, (x, 2.2), (x, 1.85))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_安全聚合协议流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_model_sync():
    """图4：模型同步与更新机制图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图4  模型同步与更新机制图', ha='center', va='center', fontsize=14, weight='bold')

    # 时间轴
    ax.annotate('', xy=(13, 9), xytext=(1, 9),
                arrowprops=dict(arrowstyle='->', color='#666', lw=2))
    ax.text(13.2, 9, '轮次', ha='left', va='center', fontsize=10, color='#666')

    rounds = ['Round 1', 'Round 2', 'Round 3', 'Round N']
    for i, r in enumerate(rounds):
        x = 2.5 + i * 3
        ax.plot([x, x], [8.8, 8.2], 'k-', lw=1.5)
        ax.text(x, 8, r, ha='center', va='center', fontsize=9)

    # 本地训练
    ax.text(1.5, 6.5, '本地:', ha='right', va='center', fontsize=10, weight='bold')
    for i in range(4):
        x = 2.5 + i * 3
        draw_box(ax, x, 6.5, 2, 0.8, '本地训练', '#E3F2FD', 'black', 8)

    # 上传
    ax.text(1.5, 5, '上传:', ha='right', va='center', fontsize=10, weight='bold')
    for i in range(4):
        x = 2.5 + i * 3
        draw_arrow(ax, (x, 6.1), (x, 5.4))
        draw_box(ax, x, 5, 2, 0.6, 'DP梯度', '#FFCDD2', 'black', 8)

    # 聚合
    ax.text(1.5, 3.5, '聚合:', ha='right', va='center', fontsize=10, weight='bold')
    for i in range(4):
        x = 2.5 + i * 3
        draw_arrow(ax, (x, 4.7), (x, 4))
        draw_box(ax, x, 3.5, 2, 0.6, '全局更新', '#C8E6C9', 'black', 8)

    # 下发
    ax.text(1.5, 2, '下发:', ha='right', va='center', fontsize=10, weight='bold')
    for i in range(4):
        x = 2.5 + i * 3
        draw_arrow(ax, (x, 3.2), (x, 2.5))
        draw_box(ax, x, 2, 2, 0.6, '模型同步', '#BBDEFB', 'black', 8)

    # 模型版本
    version_box = FancyBboxPatch((1, 0.3), 12, 1, boxstyle="round,pad=0.02",
                                 facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=1.5)
    ax.add_patch(version_box)
    ax.text(7, 0.8, '模型版本: v1.0 → v1.1 → v1.2 → ... → vN.0  (持续优化)',
           ha='center', va='center', fontsize=9)

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_模型同步与更新机制图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利12附图...')
    figure1_three_layer_learning()
    figure2_differential_privacy()
    figure3_secure_aggregation()
    figure4_model_sync()
    print('专利12全部附图生成完成!')
