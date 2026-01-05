# -*- coding: utf-8 -*-
"""
为专利02-12生成规范的黑白附图
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle, Circle, Polygon
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def save_figure(fig, name):
    """保存图形为黑白PNG"""
    filepath = os.path.join(OUTPUT_DIR, f'{name}.png')
    fig.savefig(filepath, dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    print(f'  生成: {name}.png')

# ============================================================
# 专利02: 多模态融合智能记账
# ============================================================
def generate_patent_02_figures():
    print('生成专利02附图...')

    # 图1: 多模态融合系统架构图
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 输入层
    inputs = [('语音输入', 1, 6.5), ('图像输入', 4, 6.5), ('文本输入', 7, 6.5), ('位置输入', 10, 6.5)]
    for label, x, y in inputs:
        rect = FancyBboxPatch((x-0.8, y-0.3), 1.6, 0.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=10)

    # 预处理层
    preprocess = [('ASR引擎', 1, 5), ('OCR引擎', 4, 5), ('NLP解析', 7, 5), ('位置解析', 10, 5)]
    for label, x, y in preprocess:
        rect = FancyBboxPatch((x-0.9, y-0.3), 1.8, 0.6, boxstyle="round,pad=0.05",
                              facecolor='#f0f0f0', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=9)

    # 连接线 - 输入到预处理
    for i in range(4):
        ax.annotate('', xy=(inputs[i][1], 5.35), xytext=(inputs[i][1], 6.15),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    # 特征融合层
    rect = Rectangle((3, 3.2), 6, 1, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 3.7, '多模态特征融合引擎', ha='center', va='center', fontsize=12, fontweight='bold')

    # 连接线 - 预处理到融合
    for i, (_, x, _) in enumerate(preprocess):
        ax.annotate('', xy=(6 if i < 2 else 6, 4.25), xytext=(x, 4.65),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    # 意图识别层
    intent_box = Rectangle((4, 1.8), 4, 0.8, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(intent_box)
    ax.text(6, 2.2, '意图识别与实体提取', ha='center', va='center', fontsize=11)

    ax.annotate('', xy=(6, 2.65), xytext=(6, 3.15),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 输出层
    outputs = [('交易记录', 2.5, 0.5), ('分类结果', 6, 0.5), ('置信度', 9.5, 0.5)]
    for label, x, y in outputs:
        rect = FancyBboxPatch((x-0.8, y-0.3), 1.6, 0.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=10)

    for _, x, _ in outputs:
        ax.annotate('', xy=(x, 0.85), xytext=(6, 1.75),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    ax.set_title('图1 多模态融合系统架构示意图', fontsize=14, pad=20)
    save_figure(fig, '专利02_图1_多模态融合系统架构')

    # 图2: 融合算法流程图
    fig, ax = plt.subplots(figsize=(10, 12))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis('off')

    # 流程节点
    nodes = [
        ('开始', 5, 11, 'ellipse'),
        ('接收多模态输入', 5, 9.5, 'rect'),
        ('并行特征提取', 5, 8, 'rect'),
        ('特征向量标准化', 5, 6.5, 'rect'),
        ('注意力权重计算', 5, 5, 'rect'),
        ('加权特征融合', 5, 3.5, 'rect'),
        ('生成融合结果', 5, 2, 'rect'),
        ('结束', 5, 0.5, 'ellipse')
    ]

    for label, x, y, shape in nodes:
        if shape == 'ellipse':
            circle = plt.Circle((x, y), 0.4, facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(circle)
            ax.text(x, y, label, ha='center', va='center', fontsize=10)
        else:
            rect = FancyBboxPatch((x-1.5, y-0.35), 3, 0.7, boxstyle="round,pad=0.05",
                                  facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(rect)
            ax.text(x, y, label, ha='center', va='center', fontsize=10)

    # 连接箭头
    for i in range(len(nodes)-1):
        y1 = nodes[i][2] - (0.4 if nodes[i][3] == 'ellipse' else 0.35)
        y2 = nodes[i+1][2] + (0.4 if nodes[i+1][3] == 'ellipse' else 0.35)
        ax.annotate('', xy=(5, y2), xytext=(5, y1),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 侧边说明
    annotations = [
        (8, 8, '语音/图像/文本/位置'),
        (8, 6.5, 'L2归一化'),
        (8, 5, 'Softmax'),
        (8, 3.5, 'Σ(wi × fi)')
    ]
    for x, y, text in annotations:
        ax.text(x, y, text, ha='left', va='center', fontsize=9, style='italic')
        ax.plot([6.55, 7.9], [y, y], 'k--', lw=0.5)

    ax.set_title('图2 多模态融合算法流程图', fontsize=14, pad=20)
    save_figure(fig, '专利02_图2_多模态融合算法流程')

    # 图3: 置信度融合示意图
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis('off')

    # 各模态置信度
    modalities = [('语音\n0.85', 1.5, 4), ('图像\n0.92', 3.5, 4), ('文本\n0.78', 5.5, 4), ('位置\n0.95', 7.5, 4)]
    for label, x, y in modalities:
        circle = plt.Circle((x, y), 0.6, facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(circle)
        ax.text(x, y, label, ha='center', va='center', fontsize=9)

    # 权重
    weights = ['w1=0.25', 'w2=0.35', 'w3=0.15', 'w4=0.25']
    for i, w in enumerate(weights):
        ax.text(modalities[i][1], 3, w, ha='center', va='center', fontsize=8)

    # 融合框
    rect = Rectangle((3, 1), 4, 1.2, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, 1.6, '加权融合: Σ(wi × ci)', ha='center', va='center', fontsize=11)

    # 连接线
    for _, x, _ in modalities:
        ax.annotate('', xy=(5, 2.25), xytext=(x, 3.35),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    # 结果
    result = plt.Circle((5, -0.2), 0.5, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(result)
    ax.text(5, -0.2, '0.89', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(5, -0.9, '融合置信度', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(5, 0.35), xytext=(5, 0.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    ax.set_title('图3 置信度加权融合示意图', fontsize=14, pad=20)
    save_figure(fig, '专利02_图3_置信度融合示意')

# ============================================================
# 专利03: 分层自学习与协同学习
# ============================================================
def generate_patent_03_figures():
    print('生成专利03附图...')

    # 图1: 分层学习架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # 三层架构
    layers = [
        ('全局模型层', 6, 8.5, 8, 1.2, '#e0e0e0'),
        ('用户模型层', 6, 5.5, 10, 2.5, '#f0f0f0'),
        ('场景模型层', 6, 2, 10, 2.5, 'white')
    ]

    for label, x, y, w, h, color in layers:
        rect = FancyBboxPatch((x-w/2, y-h/2), w, h, boxstyle="round,pad=0.1",
                              facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, y+h/2-0.3, label, ha='center', va='top', fontsize=12, fontweight='bold')

    # 全局模型
    ax.text(6, 8.3, '通用分类知识 + 行业模式', ha='center', va='center', fontsize=10)

    # 用户模型子项
    user_items = [('用户A', 2.5, 5.3), ('用户B', 6, 5.3), ('用户C', 9.5, 5.3)]
    for label, x, y in user_items:
        rect = FancyBboxPatch((x-1, y-0.8), 2, 1.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, y+0.4, label, ha='center', va='center', fontsize=9, fontweight='bold')
        ax.text(x, y-0.2, '个人偏好', ha='center', va='center', fontsize=8)

    # 场景模型子项
    scene_items = [
        ('工作日', 1.5, 1.8), ('周末', 3.5, 1.8), ('出差', 5.5, 1.8),
        ('节假日', 7.5, 1.8), ('购物', 9.5, 1.8)
    ]
    for label, x, y in scene_items:
        rect = FancyBboxPatch((x-0.7, y-0.5), 1.4, 1, boxstyle="round,pad=0.05",
                              facecolor='#f8f8f8', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=9)

    # 层间箭头
    ax.annotate('', xy=(6, 7.1), xytext=(6, 7.85),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
    ax.text(6.5, 7.5, '知识蒸馏', ha='left', va='center', fontsize=9)

    ax.annotate('', xy=(6, 3.5), xytext=(6, 4.2),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
    ax.text(6.5, 3.85, '场景切换', ha='left', va='center', fontsize=9)

    ax.set_title('图1 分层学习系统架构图', fontsize=14, pad=20)
    save_figure(fig, '专利03_图1_分层学习架构')

    # 图2: 联邦学习流程
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 中央服务器
    rect = Rectangle((4.5, 6), 3, 1.5, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 6.75, '聚合服务器', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 6.25, '(仅接收梯度)', ha='center', va='center', fontsize=9)

    # 客户端
    clients = [('客户端1', 1.5, 2.5), ('客户端2', 4.5, 2.5), ('客户端3', 7.5, 2.5), ('客户端4', 10.5, 2.5)]
    for label, x, y in clients:
        rect = FancyBboxPatch((x-1.2, y-1), 2.4, 2, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y+0.5, label, ha='center', va='center', fontsize=10, fontweight='bold')
        ax.text(x, y-0.1, '本地数据', ha='center', va='center', fontsize=8)
        ax.text(x, y-0.5, '本地模型', ha='center', va='center', fontsize=8)

    # 数据流
    for _, x, _ in clients:
        # 上传梯度
        ax.annotate('', xy=(5.5, 5.95), xytext=(x, 3.55),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1, ls='--'))
        # 下载模型
        ax.annotate('', xy=(x, 3.55), xytext=(6.5, 5.95),
                   arrowprops=dict(arrowstyle='->', color='gray', lw=1))

    ax.text(3, 4.8, '上传梯度', ha='center', va='center', fontsize=9, rotation=45)
    ax.text(9, 4.8, '下载模型', ha='center', va='center', fontsize=9, color='gray', rotation=-45)

    # 隐私说明
    ax.text(6, 0.5, '* 原始数据始终保留在本地，仅梯度参与聚合',
            ha='center', va='center', fontsize=10, style='italic')

    ax.set_title('图2 联邦学习隐私保护流程图', fontsize=14, pad=20)
    save_figure(fig, '专利03_图2_联邦学习流程')

    # 图3: 知识蒸馏过程
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 教师模型
    rect = Rectangle((1, 5.5), 3, 2, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(2.5, 6.8, '教师模型', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(2.5, 6.2, '(全局模型)', ha='center', va='center', fontsize=10)
    ax.text(2.5, 5.8, '大型复杂网络', ha='center', va='center', fontsize=9)

    # 学生模型
    rect = Rectangle((6, 5.5), 3, 2, facecolor='white', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(7.5, 6.8, '学生模型', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(7.5, 6.2, '(用户模型)', ha='center', va='center', fontsize=10)
    ax.text(7.5, 5.8, '轻量化网络', ha='center', va='center', fontsize=9)

    # 蒸馏过程
    ax.annotate('', xy=(5.9, 6.5), xytext=(4.1, 6.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))
    ax.text(5, 7, '软标签', ha='center', va='center', fontsize=10)
    ax.text(5, 6.5, '知识迁移', ha='center', va='center', fontsize=10, fontweight='bold')

    # 输出对比
    ax.text(2.5, 4.5, '软概率分布', ha='center', va='center', fontsize=9)
    ax.text(2.5, 4, 'P(餐饮)=0.6', ha='center', va='center', fontsize=8)
    ax.text(2.5, 3.6, 'P(交通)=0.3', ha='center', va='center', fontsize=8)
    ax.text(2.5, 3.2, 'P(其他)=0.1', ha='center', va='center', fontsize=8)

    ax.text(7.5, 4.5, '学习目标', ha='center', va='center', fontsize=9)
    ax.text(7.5, 4, '模仿教师分布', ha='center', va='center', fontsize=8)
    ax.text(7.5, 3.6, '+ 硬标签监督', ha='center', va='center', fontsize=8)
    ax.text(7.5, 3.2, '= 混合损失', ha='center', va='center', fontsize=8)

    # 温度参数
    rect = Rectangle((3.5, 1.5), 3, 1.2, facecolor='#f0f0f0', edgecolor='black', linewidth=1)
    ax.add_patch(rect)
    ax.text(5, 2.1, '温度参数 T', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(5, 1.7, '控制软化程度', ha='center', va='center', fontsize=9)

    ax.set_title('图3 知识蒸馏过程示意图', fontsize=14, pad=20)
    save_figure(fig, '专利03_图3_知识蒸馏过程')

# ============================================================
# 专利04: 零基预算动态分配
# ============================================================
def generate_patent_04_figures():
    print('生成专利04附图...')

    # 图1: 零基预算系统架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # 收入层
    rect = Rectangle((1, 8), 10, 1.5, facecolor='#d0ffd0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 9, '收入来源', ha='center', va='center', fontsize=12, fontweight='bold')
    income_items = ['工资', '奖金', '投资收益', '其他收入']
    for i, item in enumerate(income_items):
        ax.text(2 + i*2.5, 8.4, item, ha='center', va='center', fontsize=9)

    # 分配引擎
    rect = Rectangle((3, 5.5), 6, 1.5, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 6.5, '智能分配引擎', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 5.9, '历史分析 + 优先级排序 + 动态调整', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 7.05), xytext=(6, 7.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 小金库层
    rect = Rectangle((0.5, 2), 11, 3, facecolor='#fff0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 4.7, '小金库（零基预算单元）', ha='center', va='center', fontsize=11, fontweight='bold')

    vaults = [
        ('餐饮', 1.5, 3, '¥2000'),
        ('交通', 3.5, 3, '¥800'),
        ('娱乐', 5.5, 3, '¥1500'),
        ('购物', 7.5, 3, '¥3000'),
        ('储蓄', 9.5, 3, '¥5000')
    ]
    for name, x, y, amount in vaults:
        rect = FancyBboxPatch((x-0.8, y-0.8), 1.6, 1.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, y+0.3, name, ha='center', va='center', fontsize=9, fontweight='bold')
        ax.text(x, y-0.3, amount, ha='center', va='center', fontsize=8)

    ax.annotate('', xy=(6, 5.05), xytext=(6, 5.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 消费层
    rect = Rectangle((2, 0.3), 8, 1, facecolor='#ffd0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 0.8, '实际消费（从对应小金库扣减）', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(6, 1.35), xytext=(6, 1.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    ax.set_title('图1 零基预算系统架构图', fontsize=14, pad=20)
    save_figure(fig, '专利04_图1_零基预算架构')

    # 图2: 动态调整算法流程
    fig, ax = plt.subplots(figsize=(10, 12))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis('off')

    nodes = [
        ('开始', 5, 11, 'ellipse'),
        ('月初预算归零', 5, 9.5, 'rect'),
        ('收集收入信息', 5, 8, 'rect'),
        ('分析历史消费', 5, 6.5, 'rect'),
        ('计算优先级权重', 5, 5, 'rect'),
        ('分配预算到小金库', 5, 3.5, 'rect'),
        ('设置预警阈值', 5, 2, 'rect'),
        ('结束', 5, 0.5, 'ellipse')
    ]

    for label, x, y, shape in nodes:
        if shape == 'ellipse':
            circle = plt.Circle((x, y), 0.4, facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(circle)
            ax.text(x, y, label, ha='center', va='center', fontsize=10)
        else:
            rect = FancyBboxPatch((x-1.5, y-0.35), 3, 0.7, boxstyle="round,pad=0.05",
                                  facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(rect)
            ax.text(x, y, label, ha='center', va='center', fontsize=10)

    for i in range(len(nodes)-1):
        y1 = nodes[i][2] - (0.4 if nodes[i][3] == 'ellipse' else 0.35)
        y2 = nodes[i+1][2] + (0.4 if nodes[i+1][3] == 'ellipse' else 0.35)
        ax.annotate('', xy=(5, y2), xytext=(5, y1),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 公式说明
    ax.text(8, 5, 'Wi = f(频率, 金额, 必要性)', ha='left', va='center', fontsize=9, style='italic')
    ax.plot([6.55, 7.9], [5, 5], 'k--', lw=0.5)

    ax.set_title('图2 零基预算分配算法流程图', fontsize=14, pad=20)
    save_figure(fig, '专利04_图2_动态分配流程')

    # 图3: 预算调拨示意图
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis('off')

    # 源小金库
    rect = FancyBboxPatch((0.5, 2), 3, 3, boxstyle="round,pad=0.1",
                          facecolor='#e0ffe0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(2, 4.5, '交通小金库', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(2, 3.8, '预算: ¥800', ha='center', va='center', fontsize=10)
    ax.text(2, 3.3, '已用: ¥200', ha='center', va='center', fontsize=10)
    ax.text(2, 2.7, '剩余: ¥600', ha='center', va='center', fontsize=10, color='green')

    # 目标小金库
    rect = FancyBboxPatch((6.5, 2), 3, 3, boxstyle="round,pad=0.1",
                          facecolor='#ffe0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(8, 4.5, '餐饮小金库', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(8, 3.8, '预算: ¥2000', ha='center', va='center', fontsize=10)
    ax.text(8, 3.3, '已用: ¥1950', ha='center', va='center', fontsize=10)
    ax.text(8, 2.7, '剩余: ¥50', ha='center', va='center', fontsize=10, color='red')

    # 调拨箭头
    ax.annotate('', xy=(6.4, 3.5), xytext=(3.6, 3.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))
    ax.text(5, 4.2, '调拨 ¥300', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(5, 3.7, '(用户确认)', ha='center', va='center', fontsize=9)

    # 结果
    ax.text(5, 1, '调拨后: 交通剩余¥300, 餐饮剩余¥350',
            ha='center', va='center', fontsize=10, style='italic')

    ax.set_title('图3 预算跨小金库调拨示意图', fontsize=14, pad=20)
    save_figure(fig, '专利04_图3_预算调拨示意')

# ============================================================
# 专利05: 四维语音交互
# ============================================================
def generate_patent_05_figures():
    print('生成专利05附图...')

    # 图1: 四维交互架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # 中心 - 语音交互核心
    circle = plt.Circle((6, 5), 1.5, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(circle)
    ax.text(6, 5.3, '语音交互', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 4.7, '核心引擎', ha='center', va='center', fontsize=10)

    # 四个维度
    dimensions = [
        ('时间维度', 6, 8.5, '多时态理解\n过去/现在/未来'),
        ('空间维度', 10, 5, '位置感知\n场景识别'),
        ('语义维度', 6, 1.5, '意图解析\n实体提取'),
        ('情感维度', 2, 5, '情绪识别\n个性化响应')
    ]

    for label, x, y, desc in dimensions:
        rect = FancyBboxPatch((x-1.5, y-1), 3, 2, boxstyle="round,pad=0.1",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y+0.5, label, ha='center', va='center', fontsize=11, fontweight='bold')
        ax.text(x, y-0.3, desc, ha='center', va='center', fontsize=8)

    # 连接线
    connections = [
        ((6, 6.55), (6, 7.45)),  # 上
        ((7.55, 5), (8.45, 5)),  # 右
        ((6, 3.45), (6, 2.55)),  # 下
        ((4.45, 5), (3.55, 5))   # 左
    ]
    for start, end in connections:
        ax.annotate('', xy=end, xytext=start,
                   arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))

    ax.set_title('图1 四维语音交互架构图', fontsize=14, pad=20)
    save_figure(fig, '专利05_图1_四维交互架构')

    # 图2: 语音处理流程
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 流程步骤
    steps = [
        ('语音\n采集', 1, 4),
        ('降噪\n增强', 3, 4),
        ('语音\n识别', 5, 4),
        ('意图\n理解', 7, 4),
        ('实体\n提取', 9, 4),
        ('结果\n输出', 11, 4)
    ]

    for label, x, y in steps:
        rect = FancyBboxPatch((x-0.8, y-1), 1.6, 2, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=10)

    for i in range(len(steps)-1):
        ax.annotate('', xy=(steps[i+1][1]-0.85, 4), xytext=(steps[i][1]+0.85, 4),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 四维增强层
    ax.text(6, 6.5, '四维增强处理层', ha='center', va='center', fontsize=11, fontweight='bold')
    enhancements = ['时间解析', '位置关联', '情感分析', '上下文融合']
    for i, e in enumerate(enhancements):
        x = 2.5 + i * 2.5
        rect = FancyBboxPatch((x-0.9, 5.5), 1.8, 0.7, boxstyle="round,pad=0.03",
                              facecolor='#f0f0f0', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 5.85, e, ha='center', va='center', fontsize=9)

    # 连接到增强层
    ax.plot([6, 6], [5.1, 5.45], 'k-', lw=1)

    ax.set_title('图2 语音处理流程图', fontsize=14, pad=20)
    save_figure(fig, '专利05_图2_语音处理流程')

    # 图3: 多轮对话状态机
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 状态节点
    states = [
        ('空闲', 5, 7, 0.6),
        ('监听', 2, 5, 0.6),
        ('处理', 5, 4, 0.6),
        ('确认', 8, 5, 0.6),
        ('执行', 5, 1.5, 0.6)
    ]

    for label, x, y, r in states:
        circle = plt.Circle((x, y), r, facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(circle)
        ax.text(x, y, label, ha='center', va='center', fontsize=10)

    # 状态转换
    transitions = [
        ((5, 6.35), (2.4, 5.45), '唤醒词'),
        ((2.55, 4.55), (4.45, 4.15), '语音输入'),
        ((5.55, 4.15), (7.45, 4.55), '需确认'),
        ((5, 3.35), (5, 2.15), '直接执行'),
        ((7.55, 4.45), (5.45, 1.8), '确认'),
        ((8, 5.65), (5.5, 6.75), '取消'),
        ((5, 0.85), (5, 0.85), '')  # 终态
    ]

    for start, end, label in transitions[:-1]:
        ax.annotate('', xy=end, xytext=start,
                   arrowprops=dict(arrowstyle='->', color='black', lw=1,
                                   connectionstyle='arc3,rad=0.1'))
        mid_x = (start[0] + end[0]) / 2
        mid_y = (start[1] + end[1]) / 2
        ax.text(mid_x, mid_y + 0.3, label, ha='center', va='center', fontsize=8)

    # 返回空闲
    ax.annotate('', xy=(4.4, 6.8), xytext=(4.5, 2),
               arrowprops=dict(arrowstyle='->', color='gray', lw=1, ls='--',
                               connectionstyle='arc3,rad=-0.3'))
    ax.text(2.8, 3.5, '完成/超时', ha='center', va='center', fontsize=8, color='gray')

    ax.set_title('图3 多轮对话状态机', fontsize=14, pad=20)
    save_figure(fig, '专利05_图3_对话状态机')

# ============================================================
# 专利06: 位置增强财务管理
# ============================================================
def generate_patent_06_figures():
    print('生成专利06附图...')

    # 图1: 位置增强系统架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # GPS/网络定位层
    rect = Rectangle((1, 8), 10, 1.5, facecolor='#d0e0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 9, '定位服务层', ha='center', va='center', fontsize=12, fontweight='bold')
    loc_items = ['GPS', 'WiFi', '基站', '蓝牙Beacon']
    for i, item in enumerate(loc_items):
        ax.text(2 + i*2.5, 8.4, item, ha='center', va='center', fontsize=9)

    # POI识别层
    rect = Rectangle((2, 5.5), 8, 1.5, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 6.5, 'POI识别引擎', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 5.9, '商户匹配 + 分类推断 + 置信度评估', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 7.05), xytext=(6, 7.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 智能推荐层
    rect = Rectangle((1, 2.5), 10, 2.2, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 4.3, '场景化智能推荐', ha='center', va='center', fontsize=11, fontweight='bold')

    features = [('分类建议', 2.5), ('预算提醒', 5), ('商户历史', 7.5), ('消费预测', 10)]
    for name, x in features:
        rect = FancyBboxPatch((x-1, 2.8), 2, 1, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 3.3, name, ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 4.75), xytext=(6, 5.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 用户界面层
    rect = Rectangle((3, 0.5), 6, 1.5, facecolor='white', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 1.25, '用户交互界面', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(6, 2.05), xytext=(6, 2.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    ax.set_title('图1 位置增强财务管理系统架构图', fontsize=14, pad=20)
    save_figure(fig, '专利06_图1_位置增强架构')

    # 图2: POI匹配算法
    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    nodes = [
        ('获取用户位置', 5, 9, 'rect'),
        ('查询周边POI', 5, 7.5, 'rect'),
        ('候选POI列表', 5, 6, 'rect'),
        ('距离过滤\n(<100m)', 3, 4.5, 'diamond'),
        ('计算匹配分数', 5, 3, 'rect'),
        ('排序选择最优', 5, 1.5, 'rect')
    ]

    for label, x, y, shape in nodes:
        if shape == 'rect':
            rect = FancyBboxPatch((x-1.5, y-0.4), 3, 0.8, boxstyle="round,pad=0.05",
                                  facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(rect)
            ax.text(x, y, label, ha='center', va='center', fontsize=10)
        elif shape == 'diamond':
            diamond = Polygon([(x, y+0.6), (x+1.2, y), (x, y-0.6), (x-1.2, y)],
                            facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(diamond)
            ax.text(x, y, label, ha='center', va='center', fontsize=8)

    # 连接
    connections = [
        ((5, 8.55), (5, 7.95)),
        ((5, 7.05), (5, 6.45)),
        ((5, 5.55), (3.8, 5.05)),
        ((3, 3.85), (4.2, 3.35)),
        ((5, 2.55), (5, 1.95))
    ]
    for start, end in connections:
        ax.annotate('', xy=end, xytext=start,
                   arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 分支
    ax.text(1.5, 4.5, '否: 放弃匹配', ha='center', va='center', fontsize=8)
    ax.annotate('', xy=(1.8, 4.5), xytext=(2.2, 4.5),
               arrowprops=dict(arrowstyle='->', color='gray', lw=1))
    ax.text(4.5, 4, '是', ha='center', va='center', fontsize=8)

    ax.set_title('图2 POI匹配算法流程图', fontsize=14, pad=20)
    save_figure(fig, '专利06_图2_POI匹配算法')

# ============================================================
# 专利07: 多因子交易去重
# ============================================================
def generate_patent_07_figures():
    print('生成专利07附图...')

    # 图1: 去重系统架构
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 输入层
    inputs = [('微信账单', 1.5, 6.5), ('支付宝', 4, 6.5), ('银行流水', 6.5, 6.5), ('手动录入', 9, 6.5)]
    for label, x, y in inputs:
        rect = FancyBboxPatch((x-1, y-0.3), 2, 0.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=10)

    # 解析层
    rect = Rectangle((1, 4.5), 9, 1.2, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 5.1, '多源账单解析器', ha='center', va='center', fontsize=11, fontweight='bold')

    for _, x, _ in inputs:
        ax.annotate('', xy=(5.5, 5.75), xytext=(x, 6.15),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    # 去重引擎
    rect = Rectangle((2, 2.5), 7, 1.2, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 3.1, '多因子去重引擎', ha='center', va='center', fontsize=11, fontweight='bold')

    ax.annotate('', xy=(5.5, 3.75), xytext=(5.5, 4.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 因子列表
    factors = ['金额', '时间', '商户', '描述', '账户']
    for i, f in enumerate(factors):
        x = 2.5 + i * 1.5
        ax.text(x, 2.2, f, ha='center', va='center', fontsize=8,
               bbox=dict(boxstyle='round', facecolor='white', edgecolor='gray'))

    # 输出
    rect = Rectangle((3.5, 0.5), 4, 1, facecolor='#d0ffd0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 1, '去重后交易列表', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(5.5, 1.55), xytext=(5.5, 2.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    ax.set_title('图1 多因子交易去重系统架构图', fontsize=14, pad=20)
    save_figure(fig, '专利07_图1_去重系统架构')

    # 图2: 相似度计算
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 交易对比
    t1 = Rectangle((0.5, 5.5), 4, 2, facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(t1)
    ax.text(2.5, 7.1, '交易A', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(2.5, 6.5, '金额: ¥128.00', ha='center', va='center', fontsize=9)
    ax.text(2.5, 6.1, '时间: 14:32:15', ha='center', va='center', fontsize=9)
    ax.text(2.5, 5.7, '商户: 星巴克咖啡', ha='center', va='center', fontsize=9)

    t2 = Rectangle((5.5, 5.5), 4, 2, facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(t2)
    ax.text(7.5, 7.1, '交易B', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(7.5, 6.5, '金额: ¥128.00', ha='center', va='center', fontsize=9)
    ax.text(7.5, 6.1, '时间: 14:32:18', ha='center', va='center', fontsize=9)
    ax.text(7.5, 5.7, '商户: 星巴克', ha='center', va='center', fontsize=9)

    # 相似度计算框
    rect = Rectangle((1.5, 2.5), 7, 2.2, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, 4.3, '多因子相似度计算', ha='center', va='center', fontsize=11, fontweight='bold')

    # 各因子得分
    scores = [
        ('金额相似度', '1.00'),
        ('时间相似度', '0.98'),
        ('商户相似度', '0.92'),
        ('加权总分', '0.96')
    ]
    for i, (name, score) in enumerate(scores):
        y = 3.8 - i * 0.4
        ax.text(2.5, y, name + ':', ha='left', va='center', fontsize=9)
        ax.text(6, y, score, ha='left', va='center', fontsize=9, fontweight='bold')

    ax.annotate('', xy=(5, 4.75), xytext=(5, 5.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 判定结果
    rect = Rectangle((2.5, 0.5), 5, 1.2, facecolor='#ffe0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, 1.1, '判定: 重复交易 (>0.85)', ha='center', va='center', fontsize=10, fontweight='bold')

    ax.annotate('', xy=(5, 1.75), xytext=(5, 2.45),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    ax.set_title('图2 多因子相似度计算示意图', fontsize=14, pad=20)
    save_figure(fig, '专利07_图2_相似度计算')

# ============================================================
# 专利08: 财务数据可视化交互
# ============================================================
def generate_patent_08_figures():
    print('生成专利08附图...')

    # 图1: 可视化组件架构
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 数据层
    rect = Rectangle((1, 6), 10, 1.5, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 6.75, '财务数据层', ha='center', va='center', fontsize=12, fontweight='bold')

    # 可视化引擎
    rect = Rectangle((2, 3.5), 8, 1.8, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 4.8, '可视化渲染引擎', ha='center', va='center', fontsize=11, fontweight='bold')
    ax.text(6, 4.1, '图表库 + 动画引擎 + 手势处理', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 5.35), xytext=(6, 5.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 图表组件
    charts = [
        ('饼图', 1.5, 1.5), ('折线图', 4, 1.5), ('柱状图', 6.5, 1.5),
        ('热力图', 9, 1.5), ('趋势图', 11, 1.5)
    ]
    for label, x, y in charts:
        rect = FancyBboxPatch((x-0.9, y-0.6), 1.8, 1.2, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=9)

    for _, x, _ in charts:
        ax.annotate('', xy=(x, 2.15), xytext=(6, 3.45),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    ax.set_title('图1 财务数据可视化组件架构图', fontsize=14, pad=20)
    save_figure(fig, '专利08_图1_可视化架构')

    # 图2: 交互手势规范
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    gestures = [
        ('单击', '选中数据点', 1.5, 6),
        ('双击', '进入下钻', 5, 6),
        ('长按', '详情弹窗', 8.5, 6),
        ('左滑', '前一周期', 1.5, 3.5),
        ('右滑', '后一周期', 5, 3.5),
        ('双指缩放', '时间范围', 8.5, 3.5)
    ]

    for gesture, action, x, y in gestures:
        rect = FancyBboxPatch((x-1.3, y-1), 2.6, 2, boxstyle="round,pad=0.1",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y+0.4, gesture, ha='center', va='center', fontsize=10, fontweight='bold')
        ax.text(x, y-0.3, action, ha='center', va='center', fontsize=9)

    ax.text(5, 1, '* 所有手势支持触觉反馈', ha='center', va='center', fontsize=10, style='italic')

    ax.set_title('图2 交互手势规范示意图', fontsize=14, pad=20)
    save_figure(fig, '专利08_图2_交互手势规范')

# ============================================================
# 专利09: 渐进式披露界面设计
# ============================================================
def generate_patent_09_figures():
    print('生成专利09附图...')

    # 图1: 渐进式披露层级
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 三层架构
    layers = [
        ('核心层', 6, 6.5, 4, 1.2, '#d0d0d0', '最常用功能 (20%)'),
        ('标准层', 6, 4.5, 7, 1.2, '#e0e0e0', '常规功能 (60%)'),
        ('高级层', 6, 2.5, 10, 1.2, '#f0f0f0', '专业功能 (20%)')
    ]

    for label, x, y, w, h, color, desc in layers:
        rect = FancyBboxPatch((x-w/2, y-h/2), w, h, boxstyle="round,pad=0.1",
                              facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x-w/2+0.5, y, label, ha='left', va='center', fontsize=11, fontweight='bold')
        ax.text(x+w/2-0.5, y, desc, ha='right', va='center', fontsize=9)

    # 连接箭头
    ax.annotate('', xy=(6, 5.35), xytext=(6, 5.85),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
    ax.annotate('', xy=(6, 3.35), xytext=(6, 3.85),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))

    ax.text(6.5, 5.6, '展开', ha='left', va='center', fontsize=9)
    ax.text(6.5, 3.6, '展开', ha='left', va='center', fontsize=9)

    ax.set_title('图1 渐进式披露界面层级结构', fontsize=14, pad=20)
    save_figure(fig, '专利09_图1_披露层级结构')

    # 图2: 用户行为驱动展开
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 行为收集
    rect = Rectangle((0.5, 5.5), 3, 2, facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(2, 7.1, '用户行为', ha='center', va='center', fontsize=11, fontweight='bold')
    behaviors = ['点击频率', '停留时长', '使用路径']
    for i, b in enumerate(behaviors):
        ax.text(2, 6.4 - i*0.4, '• ' + b, ha='center', va='center', fontsize=9)

    # 分析引擎
    rect = Rectangle((4, 5.5), 2, 2, facecolor='#e0e0e0', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, 6.5, '行为\n分析', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(3.95, 6.5), xytext=(3.55, 6.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 决策输出
    rect = Rectangle((6.5, 5.5), 3, 2, facecolor='#f0f0f0', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(8, 7.1, '界面适配', ha='center', va='center', fontsize=11, fontweight='bold')
    adaptations = ['自动展开', '快捷入口', '个性推荐']
    for i, a in enumerate(adaptations):
        ax.text(8, 6.4 - i*0.4, '• ' + a, ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6.45, 6.5), xytext=(6.05, 6.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 示例
    ax.text(5, 4, '示例: 用户频繁使用"导出"功能 → 自动提升至核心层',
            ha='center', va='center', fontsize=10, style='italic',
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='gray'))

    ax.set_title('图2 用户行为驱动的界面适配', fontsize=14, pad=20)
    save_figure(fig, '专利09_图2_行为驱动适配')

# ============================================================
# 专利10: 智能账单解析导入
# ============================================================
def generate_patent_10_figures():
    print('生成专利10附图...')

    # 图1: 账单解析系统架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # 输入源
    sources = [('微信\n账单', 1.5, 8.5), ('支付宝\n账单', 4, 8.5), ('银行\nCSV', 6.5, 8.5), ('其他\n格式', 9, 8.5)]
    for label, x, y in sources:
        rect = FancyBboxPatch((x-0.8, y-0.6), 1.6, 1.2, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=9)

    # 格式识别
    rect = Rectangle((2, 6), 7, 1.2, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 6.6, '智能格式识别引擎', ha='center', va='center', fontsize=11, fontweight='bold')

    for _, x, _ in sources:
        ax.annotate('', xy=(5.5, 7.25), xytext=(x, 7.85),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1))

    # 字段映射
    rect = Rectangle((2, 4), 7, 1.2, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 4.6, '字段智能映射', ha='center', va='center', fontsize=11, fontweight='bold')

    ax.annotate('', xy=(5.5, 5.25), xytext=(5.5, 5.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 数据清洗
    rect = Rectangle((2, 2), 7, 1.2, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 2.6, '数据清洗与标准化', ha='center', va='center', fontsize=11, fontweight='bold')

    ax.annotate('', xy=(5.5, 3.25), xytext=(5.5, 3.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 输出
    rect = Rectangle((3, 0.3), 5, 1, facecolor='#d0ffd0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, 0.8, '标准化交易记录', ha='center', va='center', fontsize=10)

    ax.annotate('', xy=(5.5, 1.35), xytext=(5.5, 1.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=2))

    ax.set_title('图1 智能账单解析系统架构图', fontsize=14, pad=20)
    save_figure(fig, '专利10_图1_账单解析架构')

    # 图2: 字段映射算法
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 源字段
    source_fields = ['交易时间', '交易金额', '对方户名', '备注']
    for i, f in enumerate(source_fields):
        y = 6.5 - i * 1
        rect = FancyBboxPatch((0.5, y-0.3), 2.5, 0.6, boxstyle="round,pad=0.05",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(1.75, y, f, ha='center', va='center', fontsize=9)

    # 目标字段
    target_fields = ['timestamp', 'amount', 'merchant', 'note']
    for i, f in enumerate(target_fields):
        y = 6.5 - i * 1
        rect = FancyBboxPatch((7, y-0.3), 2.5, 0.6, boxstyle="round,pad=0.05",
                              facecolor='#e0e0e0', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(8.25, y, f, ha='center', va='center', fontsize=9)

    # 映射箭头
    for i in range(4):
        y = 6.5 - i * 1
        ax.annotate('', xy=(6.95, y), xytext=(3.05, y),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 映射引擎
    rect = Rectangle((3.5, 2.5), 3, 3.5, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, 5.5, '智能映射', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(5, 4.8, '语义匹配', ha='center', va='center', fontsize=9)
    ax.text(5, 4.3, '模式识别', ha='center', va='center', fontsize=9)
    ax.text(5, 3.8, '类型推断', ha='center', va='center', fontsize=9)
    ax.text(5, 3.3, '历史学习', ha='center', va='center', fontsize=9)

    ax.text(1.75, 2, '源账单字段', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(8.25, 2, '标准字段', ha='center', va='center', fontsize=10, fontweight='bold')

    ax.set_title('图2 字段智能映射算法示意图', fontsize=14, pad=20)
    save_figure(fig, '专利10_图2_字段映射算法')

# ============================================================
# 专利11: 离线优先增量同步
# ============================================================
def generate_patent_11_figures():
    print('生成专利11附图...')

    # 图1: 离线优先架构
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 客户端
    rect = Rectangle((0.5, 1), 4, 6, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(2.5, 6.5, '客户端', ha='center', va='center', fontsize=12, fontweight='bold')

    # 本地存储
    rect = FancyBboxPatch((1, 4), 3, 1.5, boxstyle="round,pad=0.1",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(2.5, 5, '本地数据库', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(2.5, 4.4, 'SQLite', ha='center', va='center', fontsize=9)

    # 同步队列
    rect = FancyBboxPatch((1, 1.8), 3, 1.5, boxstyle="round,pad=0.1",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(2.5, 2.8, '同步队列', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(2.5, 2.2, '待同步变更', ha='center', va='center', fontsize=9)

    # 云端
    rect = Rectangle((7.5, 1), 4, 6, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(9.5, 6.5, '云端服务', ha='center', va='center', fontsize=12, fontweight='bold')

    # 云端存储
    rect = FancyBboxPatch((8, 4), 3, 1.5, boxstyle="round,pad=0.1",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(9.5, 5, '云端数据库', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(9.5, 4.4, 'PostgreSQL', ha='center', va='center', fontsize=9)

    # 同步引擎
    rect = Rectangle((4.8, 2.5), 2.4, 3, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 5, '增量', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(6, 4.5, '同步', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(6, 4, '引擎', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(6, 3.2, '冲突检测', ha='center', va='center', fontsize=8)
    ax.text(6, 2.8, '版本合并', ha='center', va='center', fontsize=8)

    # 双向箭头
    ax.annotate('', xy=(4.75, 4.5), xytext=(4.05, 4.5),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
    ax.annotate('', xy=(7.95, 4.5), xytext=(7.25, 4.5),
               arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))

    ax.set_title('图1 离线优先增量同步架构图', fontsize=14, pad=20)
    save_figure(fig, '专利11_图1_离线同步架构')

    # 图2: 冲突解决流程
    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    nodes = [
        ('检测到冲突', 5, 9, 'rect'),
        ('分析冲突类型', 5, 7.5, 'rect'),
        ('是否可自动\n解决?', 5, 6, 'diamond'),
        ('应用合并策略', 2.5, 4.5, 'rect'),
        ('提示用户\n手动选择', 7.5, 4.5, 'rect'),
        ('更新版本号', 5, 2.5, 'rect'),
        ('同步完成', 5, 1, 'rect')
    ]

    for label, x, y, shape in nodes:
        if shape == 'rect':
            rect = FancyBboxPatch((x-1.3, y-0.4), 2.6, 0.8, boxstyle="round,pad=0.05",
                                  facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(rect)
            ax.text(x, y, label, ha='center', va='center', fontsize=9)
        elif shape == 'diamond':
            diamond = Polygon([(x, y+0.7), (x+1.5, y), (x, y-0.7), (x-1.5, y)],
                            facecolor='white', edgecolor='black', linewidth=1.5)
            ax.add_patch(diamond)
            ax.text(x, y, label, ha='center', va='center', fontsize=8)

    # 连接
    ax.annotate('', xy=(5, 8.55), xytext=(5, 7.95),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))
    ax.annotate('', xy=(5, 7.05), xytext=(5, 6.75),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 判断分支
    ax.annotate('', xy=(3.2, 4.95), xytext=(4, 5.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))
    ax.text(3.2, 5.5, '是', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6.8, 4.95), xytext=(6, 5.5),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))
    ax.text(6.8, 5.5, '否', ha='center', va='center', fontsize=9)

    # 汇合
    ax.annotate('', xy=(5, 2.95), xytext=(2.5, 4.05),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))
    ax.annotate('', xy=(5, 2.95), xytext=(7.5, 4.05),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))
    ax.annotate('', xy=(5, 1.45), xytext=(5, 2.05),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    ax.set_title('图2 同步冲突解决流程图', fontsize=14, pad=20)
    save_figure(fig, '专利11_图2_冲突解决流程')

# ============================================================
# 专利12: 隐私保护协同学习
# ============================================================
def generate_patent_12_figures():
    print('生成专利12附图...')

    # 图1: 隐私保护架构
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # 用户设备层
    rect = Rectangle((0.5, 6.5), 11, 3, facecolor='#f0f0f0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 9.1, '用户设备层（数据始终保留在本地）', ha='center', va='center', fontsize=11, fontweight='bold')

    devices = [('用户A', 2, 7.5), ('用户B', 6, 7.5), ('用户C', 10, 7.5)]
    for label, x, y in devices:
        rect = FancyBboxPatch((x-1.3, y-0.8), 2.6, 1.6, boxstyle="round,pad=0.1",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, y+0.3, label, ha='center', va='center', fontsize=10, fontweight='bold')
        ax.text(x, y-0.3, '本地模型+数据', ha='center', va='center', fontsize=8)

    # 安全计算层
    rect = Rectangle((2, 3.5), 8, 2, facecolor='#e0e0e0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 5, '安全聚合层', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 4, '差分隐私 + 安全多方计算 + 同态加密', ha='center', va='center', fontsize=9)

    # 连接
    for _, x, _ in devices:
        ax.annotate('', xy=(6, 5.55), xytext=(x, 6.65),
                   arrowprops=dict(arrowstyle='->', color='black', lw=1, ls='--'))
    ax.text(4, 6.1, '仅上传加密梯度', ha='center', va='center', fontsize=8, style='italic')

    # 全局模型
    rect = Rectangle((3.5, 0.5), 5, 2, facecolor='#d0d0d0', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 1.8, '全局模型', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(6, 1.1, '聚合后的共享知识', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 2.55), xytext=(6, 3.45),
               arrowprops=dict(arrowstyle='<->', color='black', lw=2))

    ax.set_title('图1 隐私保护协同学习架构图', fontsize=14, pad=20)
    save_figure(fig, '专利12_图1_隐私保护架构')

    # 图2: 差分隐私机制
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.axis('off')

    # 原始梯度
    rect = FancyBboxPatch((0.5, 5), 2.5, 2, boxstyle="round,pad=0.1",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(1.75, 6.5, '原始梯度', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(1.75, 5.8, 'G = [0.12, 0.35, ...]', ha='center', va='center', fontsize=8)
    ax.text(1.75, 5.3, '(包含用户信息)', ha='center', va='center', fontsize=7, color='red')

    # 噪声添加
    rect = Rectangle((3.5, 5), 3, 2, facecolor='#e0e0e0', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, 6.5, '差分隐私处理', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(5, 5.9, 'G\' = G + N(0, σ²)', ha='center', va='center', fontsize=9)
    ax.text(5, 5.3, 'σ由ε-DP预算决定', ha='center', va='center', fontsize=8)

    ax.annotate('', xy=(3.45, 6), xytext=(3.05, 6),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 保护后梯度
    rect = FancyBboxPatch((7, 5), 2.5, 2, boxstyle="round,pad=0.1",
                          facecolor='#d0ffd0', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(8.25, 6.5, '保护后梯度', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(8.25, 5.8, 'G\' = [0.15, 0.33, ...]', ha='center', va='center', fontsize=8)
    ax.text(8.25, 5.3, '(无法逆推原数据)', ha='center', va='center', fontsize=7, color='green')

    ax.annotate('', xy=(6.95, 6), xytext=(6.55, 6),
               arrowprops=dict(arrowstyle='->', color='black', lw=1.5))

    # 隐私预算说明
    rect = Rectangle((2, 1.5), 6, 2.5, facecolor='#f0f0f0', edgecolor='black', linewidth=1)
    ax.add_patch(rect)
    ax.text(5, 3.6, '隐私预算 ε (Epsilon)', ha='center', va='center', fontsize=10, fontweight='bold')
    ax.text(5, 3, 'ε 越小 → 隐私保护越强 → 模型精度略降', ha='center', va='center', fontsize=9)
    ax.text(5, 2.4, 'ε 越大 → 隐私保护越弱 → 模型精度更高', ha='center', va='center', fontsize=9)
    ax.text(5, 1.8, '系统默认 ε = 1.0（平衡配置）', ha='center', va='center', fontsize=9, style='italic')

    ax.set_title('图2 差分隐私机制示意图', fontsize=14, pad=20)
    save_figure(fig, '专利12_图2_差分隐私机制')


# ============================================================
# 主函数
# ============================================================
if __name__ == '__main__':
    print('='*60)
    print('开始为专利02-12生成规范附图...')
    print('='*60)

    generate_patent_02_figures()
    generate_patent_03_figures()
    generate_patent_04_figures()
    generate_patent_05_figures()
    generate_patent_06_figures()
    generate_patent_07_figures()
    generate_patent_08_figures()
    generate_patent_09_figures()
    generate_patent_10_figures()
    generate_patent_11_figures()
    generate_patent_12_figures()

    print('='*60)
    print('所有附图生成完成！')
    print(f'输出目录: {OUTPUT_DIR}')
    print('='*60)
