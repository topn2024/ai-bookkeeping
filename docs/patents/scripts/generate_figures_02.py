# -*- coding: utf-8 -*-
"""生成专利02的附图：多模态融合智能记账识别方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon, Ellipse
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_02'
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


def figure1_multimodal_architecture():
    """图1：多模态融合识别系统架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图1  多模态融合识别系统架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入层
    ax.text(2, 10.5, '输入层', ha='center', va='center', fontsize=12, weight='bold', color='#333')

    # 三种输入模态
    modals = [
        (2, 9.3, '语音输入', '#E3F2FD', 'mic'),
        (2, 8.0, '图像输入', '#E8F5E9', 'camera'),
        (2, 6.7, '文本输入', '#FFF3E0', 'keyboard'),
    ]
    for x, y, text, color, icon in modals:
        draw_box(ax, x, y, 2.5, 0.9, text, color, 'black', 10)

    # 预处理层
    ax.text(5.5, 10.5, '预处理层', ha='center', va='center', fontsize=12, weight='bold', color='#333')

    preprocess = [
        (5.5, 9.3, '语音预处理\n降噪/VAD/分帧', '#E3F2FD'),
        (5.5, 8.0, '图像预处理\n裁剪/增强/OCR', '#E8F5E9'),
        (5.5, 6.7, '文本预处理\n分词/标准化', '#FFF3E0'),
    ]
    for x, y, text, color in preprocess:
        draw_box(ax, x, y, 2.8, 1.0, text, color, 'black', 9)

    # 连接输入到预处理
    for y in [9.3, 8.0, 6.7]:
        draw_arrow(ax, (3.25, y), (4.1, y))

    # AI识别层
    ax.text(9, 10.5, 'AI识别层', ha='center', va='center', fontsize=12, weight='bold', color='#333')

    ai_modules = [
        (9, 9.3, '语音识别 (ASR)\n千问语音大模型', '#BBDEFB'),
        (9, 8.0, '图像识别 (VLM)\n千问视觉大模型', '#C8E6C9'),
        (9, 6.7, '文本理解 (NLU)\n意图识别/槽位填充', '#FFE0B2'),
    ]
    for x, y, text, color in ai_modules:
        draw_box(ax, x, y, 3.2, 1.0, text, color, 'black', 9)

    # 连接预处理到AI识别
    for y in [9.3, 8.0, 6.7]:
        draw_arrow(ax, (6.9, y), (7.4, y))

    # 融合层
    ax.text(7, 5.2, '多模态融合层', ha='center', va='center', fontsize=12, weight='bold', color='#333')

    # 融合模块
    draw_box(ax, 7, 4.3, 4.5, 1.2, '置信度融合引擎\n(加权融合/竞争选择/互补验证)', '#E1BEE7', 'black', 10)

    # 连接AI识别到融合
    draw_arrow(ax, (9, 6.2), (9, 5.5))
    ax.plot([9, 9], [5.5, 5.5], 'k-', lw=1.5)
    ax.plot([7, 9], [5.5, 5.5], 'k-', lw=1.5)
    draw_arrow(ax, (7, 5.5), (7, 4.9))

    # 后处理层
    ax.text(7, 2.8, '后处理层', ha='center', va='center', fontsize=12, weight='bold', color='#333')

    postprocess = [
        (4, 2, '实体抽取\n金额/商户/日期', '#D1C4E9'),
        (7, 2, '分类推荐\n智能类别匹配', '#D1C4E9'),
        (10, 2, '多笔拆分\n连续记账识别', '#D1C4E9'),
    ]
    for x, y, text, color in postprocess:
        draw_box(ax, x, y, 2.5, 1.0, text, color, 'black', 9)

    # 连接融合到后处理
    draw_arrow(ax, (7, 3.7), (7, 3))
    ax.plot([4, 10], [3, 3], 'k-', lw=1.5)
    for x in [4, 7, 10]:
        draw_arrow(ax, (x, 3), (x, 2.5))

    # 输出层
    draw_box(ax, 7, 0.7, 5, 0.9, '结构化交易数据输出', '#F5F5F5', 'black', 11)

    # 连接后处理到输出
    ax.plot([4, 10], [1.5, 1.5], 'k-', lw=1.5)
    draw_arrow(ax, (7, 1.5), (7, 1.15))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_多模态融合识别系统架构图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_voice_recognition():
    """图2：语音识别处理流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 9.5, '图2  语音识别处理流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 流程步骤
    steps = [
        (2, 8, '语音输入', '#E3F2FD'),
        (5, 8, '降噪处理', '#BBDEFB'),
        (8, 8, 'VAD检测', '#90CAF9'),
        (11, 8, '分帧处理', '#64B5F6'),
    ]

    for x, y, text, color in steps:
        draw_box(ax, x, y, 2.2, 0.9, text, color, 'black', 10)

    # 连接
    for i in range(len(steps) - 1):
        draw_arrow(ax, (steps[i][0] + 1.1, 8), (steps[i+1][0] - 1.1, 8))

    # ASR识别
    draw_box(ax, 7, 6.3, 3, 1, 'ASR语音识别\n(千问语音大模型)', '#42A5F5', 'black', 10)
    draw_arrow(ax, (11, 7.55), (11, 6.8))
    ax.plot([7, 11], [6.8, 6.8], 'k-', lw=1.5)
    draw_arrow(ax, (7, 6.8), (7, 6.8))

    # 文本输出
    draw_box(ax, 7, 4.8, 4, 0.9, '识别文本\n"今天午餐花了35块"', '#E1F5FE', 'black', 10)
    draw_arrow(ax, (7, 5.8), (7, 5.25))

    # NLU处理
    ax.text(7, 3.8, 'NLU自然语言理解', ha='center', va='center', fontsize=11, weight='bold')

    nlu_steps = [
        (3, 2.8, '意图识别\n(记账意图)', '#C5CAE9'),
        (7, 2.8, '槽位填充\n(金额/类别/时间)', '#C5CAE9'),
        (11, 2.8, '实体链接\n(商户匹配)', '#C5CAE9'),
    ]
    for x, y, text, color in nlu_steps:
        draw_box(ax, x, y, 2.8, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 4.35), (7, 3.5))
    ax.plot([3, 11], [3.5, 3.5], 'k-', lw=1.5)
    for x in [3, 7, 11]:
        draw_arrow(ax, (x, 3.5), (x, 3.3))

    # 输出
    output_box = FancyBboxPatch((3.5, 0.8), 7, 1.2, boxstyle="round,pad=0.03",
                                facecolor='#E8F5E9', edgecolor='#4CAF50', linewidth=2)
    ax.add_patch(output_box)
    ax.text(7, 1.4, '结构化输出: {金额: 35, 类别: 餐饮, 时间: 今天, 备注: 午餐}',
           ha='center', va='center', fontsize=10)

    ax.plot([3, 11], [2.3, 2.3], 'k-', lw=1.5)
    draw_arrow(ax, (7, 2.3), (7, 2.0))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_语音识别处理流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_image_recognition():
    """图3：图像识别处理流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图3  图像识别处理流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入
    draw_box(ax, 2, 9, 2.5, 1, '图像输入\n(小票/账单/截图)', '#E8F5E9', 'black', 9)

    # 预处理分支
    ax.text(7, 9.5, '图像预处理', ha='center', va='center', fontsize=11, weight='bold')

    preprocess = [
        (5, 8, '透视校正', '#C8E6C9'),
        (7, 8, '对比度增强', '#C8E6C9'),
        (9, 8, '去噪处理', '#C8E6C9'),
    ]
    for x, y, text, color in preprocess:
        draw_box(ax, x, y, 2.2, 0.8, text, color, 'black', 9)

    draw_arrow(ax, (3.25, 9), (3.9, 8))

    for i in range(len(preprocess) - 1):
        draw_arrow(ax, (preprocess[i][0] + 1.1, 8), (preprocess[i+1][0] - 1.1, 8))

    # 类型识别
    draw_box(ax, 11.5, 8, 2.2, 0.8, '类型识别', '#A5D6A7', 'black', 9)
    draw_arrow(ax, (10.1, 8), (10.4, 8))

    # 分支处理
    ax.text(7, 6.5, '分类处理', ha='center', va='center', fontsize=11, weight='bold')

    branches = [
        (3, 5.5, '纸质小票\nOCR文字提取', '#FFF9C4'),
        (7, 5.5, '电子账单\n结构化解析', '#FFECB3'),
        (11, 5.5, '支付截图\n区域定位识别', '#FFE082'),
    ]
    for x, y, text, color in branches:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    # 连接类型识别到分支
    draw_arrow(ax, (11.5, 7.6), (11.5, 7))
    ax.plot([3, 11], [7, 7], 'k-', lw=1.5)
    for x in [3, 7, 11]:
        draw_arrow(ax, (x, 7), (x, 6.1))

    # VLM识别
    draw_box(ax, 7, 3.8, 4, 1.2, '视觉语言模型 (VLM)\n千问视觉大模型\n多模态理解与提取', '#81C784', 'white', 10)

    ax.plot([3, 11], [4.9, 4.9], 'k-', lw=1.5)
    draw_arrow(ax, (7, 4.9), (7, 4.4))

    # 信息提取
    ax.text(7, 2.5, '信息提取结果', ha='center', va='center', fontsize=11, weight='bold')

    results = [
        (2.5, 1.5, '商户名称\n海底捞', '#E8F5E9'),
        (5, 1.5, '交易金额\n328.00', '#E8F5E9'),
        (7.5, 1.5, '交易时间\n2024-01-15', '#E8F5E9'),
        (10, 1.5, '商品明细\n[锅底/菜品...]', '#E8F5E9'),
    ]
    for x, y, text, color in results:
        draw_box(ax, x, y, 2.3, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 3.2), (7, 2.8))
    ax.plot([2.5, 10], [2.8, 2.8], 'k-', lw=1.5)
    for x in [2.5, 5, 7.5, 10]:
        draw_arrow(ax, (x, 2.8), (x, 2.0))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_图像识别处理流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_multi_transaction_split():
    """图4：多笔交易拆分算法流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 12.5, '图4  多笔交易拆分算法流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 输入
    draw_box(ax, 6, 10.4, 5, 0.9, '输入: 语音/文本识别结果', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.85))

    # 分隔符检测
    draw_box(ax, 6, 9.2, 4.5, 0.9, '分隔符模式检测', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.95), (6, 9.65))

    # 判断
    diamond = Polygon([(6, 8.4), (7.5, 7.7), (6, 7), (4.5, 7.7)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 7.7, '包含分\n隔符?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.75), (6, 8.4))

    # 是 - 语义边界识别
    draw_box(ax, 3, 7.7, 2.5, 0.7, '按分隔符拆分', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (4.5, 7.7), (4.25, 7.7))
    ax.text(4.35, 7.95, '是', ha='center', va='center', fontsize=8)

    # 否 - 语义分析
    draw_box(ax, 9, 7.7, 2.5, 0.7, '语义边界识别', '#FFECB3', 'black', 9)
    draw_arrow(ax, (7.5, 7.7), (7.75, 7.7))
    ax.text(7.65, 7.95, '否', ha='center', va='center', fontsize=8)

    # 合并路径
    ax.plot([3, 3], [7.35, 6.5], 'k-', lw=1.5)
    ax.plot([9, 9], [7.35, 6.5], 'k-', lw=1.5)
    ax.plot([3, 9], [6.5, 6.5], 'k-', lw=1.5)
    draw_arrow(ax, (6, 6.5), (6, 6.3))

    # 获取拆分片段
    draw_box(ax, 6, 5.7, 4, 0.8, '获取拆分片段列表', '#E3F2FD', 'black', 10)

    # 循环处理
    draw_box(ax, 6, 4.5, 4, 0.8, '对每个片段进行解析', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 5.3), (6, 4.9))

    # 解析内容
    parse_items = [
        (3, 3.3, '提取金额', '#C5CAE9'),
        (6, 3.3, '提取商户', '#C5CAE9'),
        (9, 3.3, '提取类别', '#C5CAE9'),
    ]
    for x, y, text, color in parse_items:
        draw_box(ax, x, y, 2.2, 0.7, text, color, 'black', 9)

    draw_arrow(ax, (6, 4.1), (6, 3.8))
    ax.plot([3, 9], [3.8, 3.8], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 3.8), (x, 3.65))

    # 验证
    draw_box(ax, 6, 2.3, 4, 0.8, '一致性验证', '#FFF3E0', 'black', 10)
    ax.plot([3, 9], [2.95, 2.95], 'k-', lw=1.5)
    draw_arrow(ax, (6, 2.95), (6, 2.7))

    # 输出
    output_box = FancyBboxPatch((3, 0.9), 6, 1, boxstyle="round,pad=0.03",
                                facecolor='#E8F5E9', edgecolor='#4CAF50', linewidth=2)
    ax.add_patch(output_box)
    ax.text(6, 1.4, '输出: 多条交易记录列表', ha='center', va='center', fontsize=10)
    draw_arrow(ax, (6, 1.9), (6, 1.9))

    # 示例
    ax.text(6, 0.3, '示例: "午餐35 晚餐68 打车20" → [{金额:35,类别:餐饮}, {金额:68,类别:餐饮}, {金额:20,类别:交通}]',
           ha='center', va='center', fontsize=8, style='italic')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_多笔交易拆分算法流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


def figure5_entity_extraction():
    """图5：实体抽取与分类推荐流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图5  实体抽取与分类推荐流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入文本
    input_box = FancyBboxPatch((2, 9), 10, 0.9, boxstyle="round,pad=0.02",
                               facecolor='#E3F2FD', edgecolor='black', linewidth=1.5)
    ax.add_patch(input_box)
    ax.text(7, 9.45, '输入文本: "昨天在星巴克喝咖啡花了38元"', ha='center', va='center', fontsize=10)

    # 实体抽取层
    ax.text(7, 8, '实体抽取层 (NER)', ha='center', va='center', fontsize=12, weight='bold')

    entities = [
        (2.5, 7, '时间实体\n"昨天"', '#FFCDD2'),
        (5, 7, '商户实体\n"星巴克"', '#C8E6C9'),
        (7.5, 7, '商品实体\n"咖啡"', '#BBDEFB'),
        (10, 7, '金额实体\n"38元"', '#FFE082'),
    ]
    for x, y, text, color in entities:
        draw_box(ax, x, y, 2.3, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 8.55), (7, 7.7))
    ax.plot([2.5, 10], [7.7, 7.7], 'k-', lw=1.5)
    for x in [2.5, 5, 7.5, 10]:
        draw_arrow(ax, (x, 7.7), (x, 7.5))

    # 实体规范化
    ax.text(7, 5.7, '实体规范化', ha='center', va='center', fontsize=11, weight='bold')

    normalized = [
        (2.5, 4.8, '日期解析\n→ 2024-01-14', '#FFCDD2'),
        (5.5, 4.8, '商户匹配\n→ 星巴克(连锁)', '#C8E6C9'),
        (8.5, 4.8, '金额标准化\n→ 38.00', '#FFE082'),
    ]
    for x, y, text, color in normalized:
        draw_box(ax, x, y, 2.6, 1.0, text, color, 'black', 9)

    ax.plot([2.5, 10], [6.5, 6.5], 'k-', lw=1.5)
    draw_arrow(ax, (5.5, 6.5), (5.5, 5.5))
    ax.plot([2.5, 8.5], [5.5, 5.5], 'k-', lw=1.5)
    for x in [2.5, 5.5, 8.5]:
        draw_arrow(ax, (x, 5.5), (x, 5.3))

    # 分类推荐引擎
    ax.text(7, 3.5, '分类推荐引擎', ha='center', va='center', fontsize=12, weight='bold')

    recommend = [
        (3.5, 2.5, '规则匹配\n星巴克→餐饮', '#D1C4E9'),
        (7, 2.5, '历史学习\n用户习惯权重', '#D1C4E9'),
        (10.5, 2.5, '语义推断\n咖啡→饮品', '#D1C4E9'),
    ]
    for x, y, text, color in recommend:
        draw_box(ax, x, y, 2.8, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 4.05), (7, 3.8))
    ax.plot([3.5, 10.5], [3.8, 3.8], 'k-', lw=1.5)
    for x in [3.5, 7, 10.5]:
        draw_arrow(ax, (x, 3.8), (x, 3))

    # 输出
    output_box = FancyBboxPatch((3, 0.7), 8, 1.2, boxstyle="round,pad=0.03",
                                facecolor='#E8F5E9', edgecolor='#4CAF50', linewidth=2)
    ax.add_patch(output_box)
    ax.text(7, 1.3, '输出: {日期: 2024-01-14, 商户: 星巴克, 金额: 38.00, 类别: 餐饮-饮品}',
           ha='center', va='center', fontsize=10)

    ax.plot([3.5, 10.5], [2, 2], 'k-', lw=1.5)
    draw_arrow(ax, (7, 2), (7, 1.9))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图5_实体抽取与分类推荐流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图5 已生成')


if __name__ == '__main__':
    print('开始生成专利02附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_multimodal_architecture()
    figure2_voice_recognition()
    figure3_image_recognition()
    figure4_multi_transaction_split()
    figure5_entity_extraction()
    print('专利02全部附图生成完成!')
