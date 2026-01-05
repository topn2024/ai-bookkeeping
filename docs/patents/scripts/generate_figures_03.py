# -*- coding: utf-8 -*-
"""生成专利03的附图：分层自学习与协同学习方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon, Ellipse
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_03'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    """绘制带文字的方框"""
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize, wrap=True)

def draw_arrow(ax, start, end, color='black', style='->'):
    """绘制箭头"""
    ax.annotate('', xy=end, xytext=start,
                arrowprops=dict(arrowstyle=style, color=color, lw=1.5))


def figure1_three_layer_architecture():
    """图1：三层学习架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图1  三层学习架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 第一层：个体学习层
    layer1_box = FancyBboxPatch((1, 8), 12, 2.5, boxstyle="round,pad=0.02",
                                facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer1_box)
    ax.text(7, 10.2, '第一层：个体学习层 (Local Learning)', ha='center', va='center', fontsize=12, weight='bold')

    # 个体学习组件
    local_components = [
        (3, 9, '用户行为\n分析模块', '#BBDEFB'),
        (6, 9, '个性化\n模型训练', '#BBDEFB'),
        (9, 9, '本地模型\n存储', '#BBDEFB'),
        (12, 9, '增量学习\n引擎', '#BBDEFB'),
    ]
    for x, y, text, color in local_components:
        draw_box(ax, x, y, 2.2, 1.2, text, color, 'black', 9)

    # 第二层：协同学习层
    layer2_box = FancyBboxPatch((1, 4.5), 12, 2.5, boxstyle="round,pad=0.02",
                                facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(layer2_box)
    ax.text(7, 6.7, '第二层：协同学习层 (Federated Learning)', ha='center', va='center', fontsize=12, weight='bold')

    # 协同学习组件
    federated_components = [
        (3, 5.5, '隐私保护\n梯度计算', '#C8E6C9'),
        (6, 5.5, '联邦聚合\n服务器', '#C8E6C9'),
        (9, 5.5, '差分隐私\n噪声添加', '#C8E6C9'),
        (12, 5.5, '安全多方\n计算', '#C8E6C9'),
    ]
    for x, y, text, color in federated_components:
        draw_box(ax, x, y, 2.2, 1.2, text, color, 'black', 9)

    # 第三层：迁移学习层
    layer3_box = FancyBboxPatch((1, 1), 12, 2.5, boxstyle="round,pad=0.02",
                                facecolor='#FFF3E0', edgecolor='#F57C00', linewidth=2)
    ax.add_patch(layer3_box)
    ax.text(7, 3.2, '第三层：迁移学习层 (Transfer Learning)', ha='center', va='center', fontsize=12, weight='bold')

    # 迁移学习组件
    transfer_components = [
        (3, 2, '预训练\n基础模型', '#FFE0B2'),
        (6, 2, '领域适配\n模块', '#FFE0B2'),
        (9, 2, '知识蒸馏\n引擎', '#FFE0B2'),
        (12, 2, '模型压缩\n优化', '#FFE0B2'),
    ]
    for x, y, text, color in transfer_components:
        draw_box(ax, x, y, 2.2, 1.2, text, color, 'black', 9)

    # 层间连接箭头
    # 个体学习到协同学习
    for x in [3, 6, 9, 12]:
        draw_arrow(ax, (x, 8.4), (x, 7), style='->')
        draw_arrow(ax, (x, 7), (x, 5.6), style='->')

    # 协同学习到迁移学习
    for x in [3, 6, 9, 12]:
        draw_arrow(ax, (x, 4.9), (x, 3.5), style='->')
        draw_arrow(ax, (x, 3.5), (x, 2.6), style='->')

    # 添加交互说明
    ax.text(0.5, 7.5, '模型\n上传', ha='center', va='center', fontsize=8, color='#1976D2')
    ax.text(0.5, 4, '全局\n模型', ha='center', va='center', fontsize=8, color='#388E3C')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_三层学习架构示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_individual_learning():
    """图2：个体学习流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图2  个体学习流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle = Circle((2, 9.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(2, 9.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 用户行为数据收集
    draw_box(ax, 2, 8.2, 3, 0.9, '用户行为数据收集', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (2, 9.15), (2, 8.65))

    # 数据类型分支
    ax.text(7, 8.2, '数据类型', ha='center', va='center', fontsize=11, weight='bold')

    data_types = [
        (5, 7, '分类选择记录', '#BBDEFB'),
        (7.5, 7, '修改历史记录', '#BBDEFB'),
        (10, 7, '时间模式记录', '#BBDEFB'),
    ]
    for x, y, text, color in data_types:
        draw_box(ax, x, y, 2.5, 0.8, text, color, 'black', 9)

    draw_arrow(ax, (3.5, 8.2), (4.2, 8.2))
    ax.plot([4.2, 4.2], [8.2, 7.5], 'k-', lw=1.5)
    ax.plot([4.2, 10], [7.5, 7.5], 'k-', lw=1.5)
    for x in [5, 7.5, 10]:
        draw_arrow(ax, (x, 7.5), (x, 7.4))

    # 特征提取
    draw_box(ax, 7, 5.7, 4, 0.9, '特征提取与编码', '#C5CAE9', 'black', 10)
    ax.plot([5, 10], [6.6, 6.6], 'k-', lw=1.5)
    draw_arrow(ax, (7, 6.6), (7, 6.15))

    # 模型训练
    draw_box(ax, 7, 4.5, 4, 0.9, '个性化模型增量训练', '#D1C4E9', 'black', 10)
    draw_arrow(ax, (7, 5.25), (7, 4.95))

    # 模型评估
    diamond = Polygon([(7, 3.7), (8.3, 3.1), (7, 2.5), (5.7, 3.1)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(7, 3.1, '性能\n提升?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (7, 4.05), (7, 3.7))

    # 是 - 更新模型
    draw_box(ax, 10.5, 3.1, 2.5, 0.7, '更新本地模型', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (8.3, 3.1), (9.25, 3.1))
    ax.text(8.7, 3.35, '是', ha='center', va='center', fontsize=8)

    # 否 - 保留原模型
    draw_box(ax, 3.5, 3.1, 2.5, 0.7, '保留原模型', '#FFCDD2', 'black', 9)
    draw_arrow(ax, (5.7, 3.1), (4.75, 3.1))
    ax.text(5.3, 3.35, '否', ha='center', va='center', fontsize=8)

    # 合并
    ax.plot([3.5, 3.5], [2.75, 1.8], 'k-', lw=1.5)
    ax.plot([10.5, 10.5], [2.75, 1.8], 'k-', lw=1.5)
    ax.plot([3.5, 10.5], [1.8, 1.8], 'k-', lw=1.5)
    draw_arrow(ax, (7, 1.8), (7, 1.5))

    # 输出
    draw_box(ax, 7, 0.9, 4, 0.8, '个性化预测服务', '#E8F5E9', 'black', 10)

    # 循环标记
    ax.annotate('', xy=(2, 8.65), xytext=(2, 1.8),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1,
                                connectionstyle='arc3,rad=-0.5'))
    ax.text(0.8, 5, '持续\n学习', ha='center', va='center', fontsize=8, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_个体学习流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_collaborative_learning():
    """图3：协同学习流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图3  协同学习流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 客户端层
    ax.text(7, 10.5, '客户端层 (多用户)', ha='center', va='center', fontsize=12, weight='bold')

    # 多个客户端
    clients = [
        (2.5, 9.3, '客户端A\n本地模型A', '#E3F2FD'),
        (5.5, 9.3, '客户端B\n本地模型B', '#E3F2FD'),
        (8.5, 9.3, '客户端C\n本地模型C', '#E3F2FD'),
        (11.5, 9.3, '客户端N\n本地模型N', '#E3F2FD'),
    ]
    for x, y, text, color in clients:
        draw_box(ax, x, y, 2.3, 1.2, text, color, '#1976D2', 9)

    # 本地训练
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_box(ax, x, 7.8, 2, 0.7, '本地训练', '#BBDEFB', 'black', 8)
        draw_arrow(ax, (x, 8.7), (x, 8.15))

    # 梯度计算
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_box(ax, x, 6.7, 2, 0.7, '计算梯度', '#90CAF9', 'black', 8)
        draw_arrow(ax, (x, 7.45), (x, 7.05))

    # 差分隐私处理
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_box(ax, x, 5.6, 2.2, 0.7, '添加DP噪声', '#64B5F6', 'white', 8)
        draw_arrow(ax, (x, 6.35), (x, 5.95))

    # 上传箭头
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_arrow(ax, (x, 5.25), (x, 4.8))

    # 联邦服务器
    server_box = FancyBboxPatch((3, 3.5), 8, 1.3, boxstyle="round,pad=0.02",
                                facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(server_box)
    ax.text(7, 4.4, '联邦聚合服务器', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 3.9, '安全聚合 | FedAvg算法 | 全局模型更新', ha='center', va='center', fontsize=9)

    # 上传连接
    ax.plot([2.5, 11.5], [4.8, 4.8], 'k-', lw=1.5)
    draw_arrow(ax, (7, 4.8), (7, 4.8))

    # 下发全局模型
    draw_box(ax, 7, 2.3, 4, 0.8, '下发更新后的全局模型', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (7, 3.5), (7, 2.7))

    # 分发到各客户端
    ax.plot([2.5, 11.5], [1.9, 1.9], 'k-', lw=1.5)
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_arrow(ax, (x, 1.9), (x, 1.5))

    # 更新本地
    for x in [2.5, 5.5, 8.5, 11.5]:
        draw_box(ax, x, 1, 2, 0.7, '更新本地', '#E8F5E9', 'black', 8)

    # 循环标记
    ax.annotate('', xy=(12.5, 9.3), xytext=(12.5, 1),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1.5,
                                connectionstyle='arc3,rad=-0.3'))
    ax.text(13.3, 5, '迭代\n轮次', ha='center', va='center', fontsize=9, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_协同学习流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_model_fusion():
    """图4：模型融合决策流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 12.5, '图4  模型融合决策流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入模型
    ax.text(6, 11.5, '输入模型', ha='center', va='center', fontsize=11, weight='bold')

    models = [
        (3, 10.5, '个体模型\n(本地学习)', '#E3F2FD'),
        (6, 10.5, '协同模型\n(联邦学习)', '#E8F5E9'),
        (9, 10.5, '迁移模型\n(预训练)', '#FFF3E0'),
    ]
    for x, y, text, color in models:
        draw_box(ax, x, y, 2.5, 1.0, text, color, 'black', 9)

    # 性能评估
    draw_box(ax, 6, 8.8, 4, 0.9, '多维度性能评估', '#D1C4E9', 'black', 10)
    ax.plot([3, 9], [10, 10], 'k-', lw=1.5)
    draw_arrow(ax, (6, 10), (6, 9.25))

    # 评估维度
    metrics = [
        (3, 7.7, '准确率\n评估', '#E1BEE7'),
        (6, 7.7, '泛化能力\n评估', '#E1BEE7'),
        (9, 7.7, '响应延迟\n评估', '#E1BEE7'),
    ]
    for x, y, text, color in metrics:
        draw_box(ax, x, y, 2.2, 0.9, text, color, 'black', 9)

    draw_arrow(ax, (6, 8.35), (6, 8.3))
    ax.plot([3, 9], [8.3, 8.3], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 8.3), (x, 8.15))

    # 融合策略选择
    diamond = Polygon([(6, 6.7), (7.8, 5.9), (6, 5.1), (4.2, 5.9)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 5.9, '场景\n判断', ha='center', va='center', fontsize=10)

    ax.plot([3, 9], [7.25, 7.25], 'k-', lw=1.5)
    draw_arrow(ax, (6, 7.25), (6, 6.7))

    # 三种策略
    strategies = [
        (2, 4.5, '加权融合\n(多模型权重组合)', '#C8E6C9', '通用场景'),
        (6, 4.5, '竞争选择\n(选择最优模型)', '#FFECB3', '性能差异大'),
        (10, 4.5, '级联融合\n(分层决策)', '#FFCDD2', '复杂场景'),
    ]
    for x, y, text, color, label in strategies:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)
        ax.text(x, 3.7, label, ha='center', va='center', fontsize=8, color='#666')

    draw_arrow(ax, (4.2, 5.9), (2.9, 5.1))
    draw_arrow(ax, (6, 5.1), (6, 5.1))
    draw_arrow(ax, (7.8, 5.9), (9.1, 5.1))

    # 融合结果
    draw_box(ax, 6, 2.5, 4, 0.9, '融合模型输出', '#E8F5E9', 'black', 10)
    ax.plot([2, 10], [3.9, 3.9], 'k-', lw=1.5)
    draw_arrow(ax, (6, 3.9), (6, 2.95))

    # 在线更新
    draw_box(ax, 6, 1.3, 4, 0.9, '在线A/B测试与反馈', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 2.05), (6, 1.75))

    # 循环反馈
    ax.annotate('', xy=(0.8, 10.5), xytext=(0.8, 1.3),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1.5,
                                connectionstyle='arc3,rad=0.3'))
    ax.text(0.3, 6, '持续\n优化', ha='center', va='center', fontsize=9, color='#666')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_模型融合决策流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利03附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_three_layer_architecture()
    figure2_individual_learning()
    figure3_collaborative_learning()
    figure4_model_fusion()
    print('专利03全部附图生成完成!')
