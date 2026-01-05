# -*- coding: utf-8 -*-
"""
生成专利01改进版的规范黑白线条附图

专利附图规范要求：
1. 黑白线条图，无灰度填充
2. 使用规范的附图标记（S101, S102等表示步骤）
3. 流程图使用标准形状（矩形=处理，菱形=判断，椭圆=开始/结束）
4. 附图标记与说明书对应
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Ellipse, Polygon
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 创建输出目录
output_dir = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_01_improved'
os.makedirs(output_dir, exist_ok=True)


def draw_box(ax, x, y, w, h, text, fontsize=9, bold=False):
    """绘制矩形框（处理步骤）"""
    rect = FancyBboxPatch((x - w/2, y - h/2), w, h,
                          boxstyle="round,pad=0.02,rounding_size=0.1",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    weight = 'bold' if bold else 'normal'
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize, weight=weight, wrap=True)


def draw_diamond(ax, x, y, size, text, fontsize=8):
    """绘制菱形（判断）"""
    d = size / 2
    diamond = Polygon([(x, y+d), (x+d, y), (x, y-d), (x-d, y)],
                      facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize, wrap=True)


def draw_ellipse(ax, x, y, w, h, text, fontsize=9):
    """绘制椭圆（开始/结束）"""
    ellipse = Ellipse((x, y), w, h, facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(ellipse)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)


def draw_arrow(ax, start, end, style='->', connectionstyle="arc3,rad=0"):
    """绘制箭头"""
    ax.annotate('', xy=end, xytext=start,
                arrowprops=dict(arrowstyle=style, color='black', lw=1.2,
                               connectionstyle=connectionstyle))


def draw_line(ax, start, end):
    """绘制直线"""
    ax.plot([start[0], end[0]], [start[1], end[1]], 'k-', lw=1.2)


# ==================== 图1：FIFO资源池模型架构示意图 ====================
def create_figure1():
    fig, ax = plt.subplots(1, 1, figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 9.5, '图1  FIFO资源池模型架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 收入事件区域
    ax.text(1.5, 8.5, '收入事件', ha='center', fontsize=10, weight='bold')

    # 资源池队列
    pools = [
        ('P1', '¥5000\n1月1日', 2),
        ('P2', '¥3000\n1月15日', 4),
        ('P3', '¥8000\n2月1日', 6),
        ('P4', '¥2000\n2月15日', 8),
    ]

    for pool_id, info, x in pools:
        # 资源池方框
        rect = FancyBboxPatch((x-0.6, 6.8), 1.2, 1.2,
                              boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, 7.6, pool_id, ha='center', va='center', fontsize=9, weight='bold')
        ax.text(x, 7.2, info, ha='center', va='center', fontsize=7)

        # 箭头从收入到资源池
        draw_arrow(ax, (x, 8.3), (x, 8.0))

    # FIFO队列标注
    ax.annotate('', xy=(8.8, 7.4), xytext=(1.5, 7.4),
                arrowprops=dict(arrowstyle='->', color='black', lw=2))
    ax.text(5, 7.9, 'FIFO队列（按收入时间排序）', ha='center', fontsize=9)
    ax.text(1.2, 7.4, '先', ha='center', fontsize=8)
    ax.text(9.0, 7.4, '后', ha='center', fontsize=8)

    # 支出事件
    ax.text(5, 5.5, '支出事件', ha='center', fontsize=10, weight='bold')
    rect = FancyBboxPatch((4, 4.8), 2, 0.6,
                          boxstyle="round,pad=0.02",
                          facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, 5.1, '¥6000 (2月20日)', ha='center', fontsize=9)

    draw_arrow(ax, (5, 5.4), (5, 6.7))

    # FIFO消耗过程
    ax.text(5, 4.3, 'FIFO消耗过程', ha='center', fontsize=10, weight='bold')

    process_box = FancyBboxPatch((2.5, 2.5), 5, 1.5,
                                  boxstyle="round,pad=0.05",
                                  facecolor='white', edgecolor='black', linewidth=1.5)
    ax.add_patch(process_box)

    ax.text(5, 3.7, '① P1: 消耗¥5000 (全部) → 标记EXHAUSTED', ha='center', fontsize=8)
    ax.text(5, 3.3, '② P2: 消耗¥1000 (部分) → 余额¥2000', ha='center', fontsize=8)
    ax.text(5, 2.9, '③ 消耗完成，生成消费链路记录', ha='center', fontsize=8)

    # 消费链路记录
    ax.text(5, 2.0, '消费链路记录', ha='center', fontsize=10, weight='bold')

    table_data = [
        ['链路ID', '资源池', '金额', '钱龄'],
        ['L1', 'P1', '¥5000', '50天'],
        ['L2', 'P2', '¥1000', '36天'],
    ]

    for i, row in enumerate(table_data):
        y_pos = 1.5 - i * 0.35
        for j, cell in enumerate(row):
            x_pos = 3 + j * 1.2
            if i == 0:
                ax.text(x_pos, y_pos, cell, ha='center', fontsize=8, weight='bold')
            else:
                ax.text(x_pos, y_pos, cell, ha='center', fontsize=8)

    # 表格边框
    ax.plot([2.5, 7.5], [1.7, 1.7], 'k-', lw=1)
    ax.plot([2.5, 7.5], [1.35, 1.35], 'k-', lw=0.5)
    ax.plot([2.5, 7.5], [1.0, 1.0], 'k-', lw=0.5)
    ax.plot([2.5, 7.5], [0.65, 0.65], 'k-', lw=1)

    # 钱龄计算结果
    ax.text(9.5, 1.2, '钱龄计算:', ha='center', fontsize=9, weight='bold')
    ax.text(9.5, 0.8, '(5000×50+1000×36)', ha='center', fontsize=8)
    ax.text(9.5, 0.5, '÷6000 = 47.7天', ha='center', fontsize=8)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图1_FIFO资源池模型架构示意图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图1已生成')


# ==================== 图2：FIFO消耗算法流程图 ====================
def create_figure2():
    fig, ax = plt.subplots(1, 1, figsize=(10, 14))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 14)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(5, 13.5, '图2  FIFO消耗算法流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    draw_ellipse(ax, 5, 12.5, 1.5, 0.6, '开始')

    # S201
    draw_box(ax, 5, 11.5, 3.5, 0.7, 'S201: 接收支出事件\n获取支出金额E和时间Te')
    draw_arrow(ax, (5, 12.2), (5, 11.9))

    # S202
    draw_box(ax, 5, 10.5, 3.5, 0.7, 'S202: 初始化\nR=E, L=空列表')
    draw_arrow(ax, (5, 11.1), (5, 10.9))

    # S203
    draw_box(ax, 5, 9.5, 3.5, 0.7, 'S203: 获取活跃资源池队列P\n按income_timestamp升序')
    draw_arrow(ax, (5, 10.1), (5, 9.9))

    # S204 判断
    draw_diamond(ax, 5, 8.3, 1.0, 'S204:\nR>0且\nP非空?')
    draw_arrow(ax, (5, 9.1), (5, 8.8))

    # S205
    draw_box(ax, 5, 7.0, 3.5, 0.7, 'S205: 取队首资源池Pi\n获取Pi.current_balance')
    draw_arrow(ax, (5, 7.8), (5, 7.4))
    ax.text(5.3, 8.0, '是', fontsize=8)

    # S206 判断
    draw_diamond(ax, 5, 5.8, 1.0, 'S206:\nR≤Pi余额?')
    draw_arrow(ax, (5, 6.6), (5, 6.3))

    # S207 (R <= 余额的情况)
    draw_box(ax, 2, 4.5, 2.8, 0.8, 'S207: 从Pi扣减R\n记录链路(Pi,R)\nR=0')
    draw_arrow(ax, (4.5, 5.8), (2.8, 5.8))
    draw_arrow(ax, (2, 5.3), (2, 5.0))
    ax.text(3.5, 6.0, '是', fontsize=8)

    # S208 (R > 余额的情况)
    draw_box(ax, 8, 4.5, 2.8, 0.9, 'S208: 消耗Pi全部余额C\n记录链路(Pi,C)\nPi标记EXHAUSTED\nR=R-C')
    draw_arrow(ax, (5.5, 5.8), (7.2, 5.8))
    draw_arrow(ax, (8, 5.0), (8, 4.0))
    ax.text(6.5, 6.0, '否', fontsize=8)

    # 返回循环
    draw_arrow(ax, (8, 3.5), (8, 8.3))
    draw_arrow(ax, (8, 8.3), (5.5, 8.3))

    # S209 否的情况 - 处理透支
    draw_box(ax, 8.5, 7.0, 2.2, 0.7, 'S209: 创建\n透支链路')
    draw_arrow(ax, (5.5, 8.3), (7.4, 7.0))
    ax.text(6.5, 8.5, '否(R>0)', fontsize=8)

    # S210 持久化
    draw_box(ax, 5, 3.0, 3.5, 0.7, 'S210: 持久化消费链路L\n更新资源池状态')
    draw_arrow(ax, (2, 4.1), (2, 3.0))
    draw_arrow(ax, (2, 3.0), (3.2, 3.0))
    draw_arrow(ax, (8.5, 6.6), (8.5, 3.0))
    draw_arrow(ax, (8.5, 3.0), (6.8, 3.0))

    # S211 计算钱龄
    draw_box(ax, 5, 2.0, 3.5, 0.7, 'S211: 计算加权平均钱龄\nAge=Σ(ai×di)/Σ(ai)')
    draw_arrow(ax, (5, 2.6), (5, 2.4))

    # 结束
    draw_ellipse(ax, 5, 1.0, 1.5, 0.6, '结束')
    draw_arrow(ax, (5, 1.6), (5, 1.3))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图2_FIFO消耗算法流程图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图2已生成')


# ==================== 图3：增量计算优化流程图 ====================
def create_figure3():
    fig, ax = plt.subplots(1, 1, figsize=(10, 12))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(5, 11.5, '图3  增量计算优化流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    draw_ellipse(ax, 5, 10.5, 1.5, 0.6, '开始')

    # S301
    draw_box(ax, 5, 9.5, 3.5, 0.7, 'S301: 检测到交易变更事件\n(新增/修改/删除)')
    draw_arrow(ax, (5, 10.2), (5, 9.9))

    # S302
    draw_box(ax, 5, 8.5, 3.5, 0.7, 'S302: 确定变更时间点Tmin')
    draw_arrow(ax, (5, 9.1), (5, 8.9))

    # S303
    draw_box(ax, 5, 7.5, 3.5, 0.7, 'S303: 标记Tmin之后的\n资源池为脏数据')
    draw_arrow(ax, (5, 8.1), (5, 7.9))

    # S304
    draw_box(ax, 5, 6.5, 3.5, 0.7, 'S304: 回滚脏数据资源池\n涉及的消费链路')
    draw_arrow(ax, (5, 7.1), (5, 6.9))

    # S305
    draw_box(ax, 5, 5.5, 3.5, 0.7, 'S305: 恢复资源池余额\n和状态至变更前')
    draw_arrow(ax, (5, 6.1), (5, 5.9))

    # S306
    draw_box(ax, 5, 4.5, 3.5, 0.7, 'S306: 获取Tmin之后的\n所有支出交易')
    draw_arrow(ax, (5, 5.1), (5, 4.9))

    # S307
    draw_box(ax, 5, 3.5, 3.5, 0.7, 'S307: 按时间顺序\n重新执行FIFO消耗')
    draw_arrow(ax, (5, 4.1), (5, 3.9))

    # S308
    draw_box(ax, 5, 2.5, 3.5, 0.7, 'S308: 更新钱龄值\n清除脏数据标记')
    draw_arrow(ax, (5, 3.1), (5, 2.9))

    # 结束
    draw_ellipse(ax, 5, 1.5, 1.5, 0.6, '结束')
    draw_arrow(ax, (5, 2.1), (5, 1.8))

    # 右侧注释
    ax.text(8, 7.5, '复杂度: O(K)\nK为受影响交易数', ha='left', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='gray'))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图3_增量计算优化流程图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图3已生成')


# ==================== 图4：系统架构图 ====================
def create_figure4():
    fig, ax = plt.subplots(1, 1, figsize=(12, 10))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 9.5, '图4  资金时间价值计算系统架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 应用层
    rect = FancyBboxPatch((1, 7.5), 10, 1.5, boxstyle="round,pad=0.05",
                          facecolor='white', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 8.7, '应用层', ha='center', fontsize=11, weight='bold')

    modules = ['钱龄展示\n模块', '健康评估\n模块', '追溯查询\n模块', '报表分析\n模块']
    for i, mod in enumerate(modules):
        x = 2.5 + i * 2.2
        rect = FancyBboxPatch((x-0.8, 7.7), 1.6, 0.7, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 8.05, mod, ha='center', va='center', fontsize=8)

    # 双向箭头
    ax.annotate('', xy=(6, 7.5), xytext=(6, 6.8),
                arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))

    # 服务层
    rect = FancyBboxPatch((1, 4.5), 10, 2.2, boxstyle="round,pad=0.05",
                          facecolor='white', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 6.3, '服务层', ha='center', fontsize=11, weight='bold')

    services = [
        ('资源池管理\n服务', 2.5),
        ('FIFO消耗\n服务', 4.5),
        ('钱龄计算\n服务', 6.5),
        ('增量优化\n服务', 8.5),
    ]
    for name, x in services:
        rect = FancyBboxPatch((x-0.8, 5.5), 1.6, 0.7, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 5.85, name, ha='center', va='center', fontsize=8)

    services2 = [
        ('健康等级\n映射服务', 3.5),
        ('追溯查询\n服务', 5.5),
        ('事件监听\n服务', 7.5),
    ]
    for name, x in services2:
        rect = FancyBboxPatch((x-0.8, 4.7), 1.6, 0.7, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 5.05, name, ha='center', va='center', fontsize=8)

    # 双向箭头
    ax.annotate('', xy=(6, 4.5), xytext=(6, 3.8),
                arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))

    # 数据层
    rect = FancyBboxPatch((1, 2), 10, 1.5, boxstyle="round,pad=0.05",
                          facecolor='white', edgecolor='black', linewidth=2)
    ax.add_patch(rect)
    ax.text(6, 3.2, '数据层', ha='center', fontsize=11, weight='bold')

    tables = [
        ('资源池表\nResourcePool', 2.5),
        ('消费链路表\nConsumptionLink', 5),
        ('脏数据标记表\nDirtyMark', 7.5),
        ('交易表\nTransaction', 10),
    ]
    for name, x in tables:
        # 使用圆柱形表示数据库表
        rect = FancyBboxPatch((x-0.9, 2.15), 1.8, 0.65, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(rect)
        ax.text(x, 2.5, name, ha='center', va='center', fontsize=7)

    # 外部接口
    ax.text(0.5, 5.5, '收入\n事件', ha='center', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black'))
    ax.annotate('', xy=(1, 5.5), xytext=(0.8, 5.5),
                arrowprops=dict(arrowstyle='->', color='black', lw=1))

    ax.text(0.5, 4.5, '支出\n事件', ha='center', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black'))
    ax.annotate('', xy=(1, 4.8), xytext=(0.8, 4.6),
                arrowprops=dict(arrowstyle='->', color='black', lw=1))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图4_系统架构图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图4已生成')


# ==================== 图5：消费链路追溯示意图 ====================
def create_figure5():
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 7.5, '图5  消费链路追溯示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 左侧：收入资源池
    ax.text(2, 6.5, '收入（资源池）', ha='center', fontsize=11, weight='bold')

    incomes = [
        ('P1: 1月工资\n¥8000', 5.5),
        ('P2: 1月奖金\n¥2000', 4.5),
        ('P3: 2月工资\n¥8000', 3.5),
    ]
    for name, y in incomes:
        rect = FancyBboxPatch((0.8, y-0.35), 2.4, 0.7, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(2, y, name, ha='center', va='center', fontsize=9)

    # 右侧：支出
    ax.text(10, 6.5, '支出', ha='center', fontsize=11, weight='bold')

    expenses = [
        ('E1: 1月15日\n消费¥3000', 5.5),
        ('E2: 2月1日\n消费¥6000', 4.5),
        ('E3: 2月20日\n消费¥5000', 3.5),
    ]
    for name, y in expenses:
        rect = FancyBboxPatch((8.8, y-0.35), 2.4, 0.7, boxstyle="round,pad=0.02",
                              facecolor='white', edgecolor='black', linewidth=1.5)
        ax.add_patch(rect)
        ax.text(10, y, name, ha='center', va='center', fontsize=9)

    # 中间：消费链路
    ax.text(6, 6.5, '消费链路', ha='center', fontsize=11, weight='bold')

    # 链路连接线（带标注）
    links = [
        ((3.2, 5.5), (8.8, 5.5), '¥3000\n14天'),
        ((3.2, 5.4), (8.8, 4.7), '¥5000\n30天'),
        ((3.2, 4.5), (8.8, 4.4), '¥1000\n17天'),
        ((3.2, 4.4), (8.8, 3.7), '¥1000\n37天'),
        ((3.2, 3.5), (8.8, 3.5), '¥4000\n19天'),
    ]

    for start, end, label in links:
        ax.annotate('', xy=end, xytext=start,
                    arrowprops=dict(arrowstyle='->', color='black', lw=1,
                                   connectionstyle="arc3,rad=0.1"))
        mid_x = (start[0] + end[0]) / 2
        mid_y = (start[1] + end[1]) / 2 + 0.15
        ax.text(mid_x, mid_y, label, ha='center', va='center', fontsize=7,
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='gray', alpha=0.9))

    # 底部说明
    ax.text(6, 2.3, '双向追溯示例', ha='center', fontsize=10, weight='bold')

    # 支出来源追溯
    rect = FancyBboxPatch((1, 1.2), 4.5, 0.9, boxstyle="round,pad=0.02",
                          facecolor='white', edgecolor='black', linewidth=1)
    ax.add_patch(rect)
    ax.text(3.25, 1.9, '支出来源追溯', ha='center', fontsize=9, weight='bold')
    ax.text(3.25, 1.45, 'E2(¥6000) ← P1(¥5000) + P2(¥1000)', ha='center', fontsize=8)

    # 收入去向追溯
    rect = FancyBboxPatch((6.5, 1.2), 4.5, 0.9, boxstyle="round,pad=0.02",
                          facecolor='white', edgecolor='black', linewidth=1)
    ax.add_patch(rect)
    ax.text(8.75, 1.9, '收入去向追溯', ha='center', fontsize=9, weight='bold')
    ax.text(8.75, 1.45, 'P1(¥8000) → E1(¥3000) + E2(¥5000)', ha='center', fontsize=8)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图5_消费链路追溯示意图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图5已生成')


# ==================== 图6：性能对比测试结果图 ====================
def create_figure6():
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    # 左图：计算时间对比
    categories = ['1000笔', '5000笔', '10000笔', '50000笔', '100000笔']
    full_calc = [200, 1000, 2000, 10000, 40000]  # 全量重算（毫秒）
    incr_calc = [10, 12, 15, 20, 30]  # 增量重算（毫秒）

    x = np.arange(len(categories))
    width = 0.35

    bars1 = ax1.bar(x - width/2, full_calc, width, label='全量重算', color='white', edgecolor='black', hatch='///')
    bars2 = ax1.bar(x + width/2, incr_calc, width, label='增量重算', color='white', edgecolor='black', hatch='...')

    ax1.set_xlabel('交易数量', fontsize=10)
    ax1.set_ylabel('计算时间（毫秒）', fontsize=10)
    ax1.set_title('(a) 计算时间对比', fontsize=11, weight='bold')
    ax1.set_xticks(x)
    ax1.set_xticklabels(categories, fontsize=9)
    ax1.legend(fontsize=9)
    ax1.set_yscale('log')
    ax1.grid(axis='y', linestyle='--', alpha=0.7)

    # 右图：性能提升倍数
    speedup = [s/i for s, i in zip(full_calc, incr_calc)]

    ax2.bar(categories, speedup, color='white', edgecolor='black', hatch='xxx')
    ax2.set_xlabel('交易数量', fontsize=10)
    ax2.set_ylabel('性能提升倍数', fontsize=10)
    ax2.set_title('(b) 增量计算性能提升', fontsize=11, weight='bold')
    ax2.grid(axis='y', linestyle='--', alpha=0.7)

    # 添加数值标签
    for i, v in enumerate(speedup):
        ax2.text(i, v + 20, f'{v:.0f}x', ha='center', fontsize=9)

    plt.suptitle('图6  性能对比测试结果', fontsize=14, weight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{output_dir}/图6_性能对比测试结果图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图6已生成')


# ==================== 图7：健康等级映射示意图 ====================
def create_figure7():
    fig, ax = plt.subplots(1, 1, figsize=(10, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis('off')

    ax.text(5, 5.5, '图7  钱龄健康等级映射示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 等级条
    levels = [
        (0, 7, 'L1: 月光级', '0-6天'),
        (7, 14, 'L2: 紧张级', '7-13天'),
        (14, 30, 'L3: 一般级', '14-29天'),
        (30, 60, 'L4: 健康级', '30-59天'),
        (60, 90, 'L5: 优秀级', '60-89天'),
        (90, 120, 'L6: 理想级', '≥90天'),
    ]

    y_base = 4
    height = 0.6
    scale = 8 / 120  # 将120天映射到8个单位宽度

    hatches = ['////', '....', 'xxxx', '\\\\\\\\', '----', '||||']

    for i, (start, end, name, days) in enumerate(levels):
        x_start = 1 + start * scale
        width = (end - start) * scale

        rect = FancyBboxPatch((x_start, y_base), width, height,
                              boxstyle="square,pad=0",
                              facecolor='white', edgecolor='black', linewidth=1.5,
                              hatch=hatches[i])
        ax.add_patch(rect)

        # 等级名称
        ax.text(x_start + width/2, y_base + height + 0.15, name,
                ha='center', va='bottom', fontsize=9, weight='bold')

        # 天数范围
        ax.text(x_start + width/2, y_base - 0.15, days,
                ha='center', va='top', fontsize=8)

    # 箭头和标注
    ax.annotate('', xy=(9.2, y_base + height/2), xytext=(0.8, y_base + height/2),
                arrowprops=dict(arrowstyle='->', color='black', lw=2))
    ax.text(0.5, y_base + height/2, '低', ha='center', va='center', fontsize=10)
    ax.text(9.5, y_base + height/2, '高', ha='center', va='center', fontsize=10)

    ax.text(5, y_base - 0.6, '钱龄（天）', ha='center', fontsize=10)
    ax.text(5, y_base + height + 0.6, '财务健康程度', ha='center', fontsize=10)

    # 底部示例
    ax.text(5, 2.5, '示例：用户当前钱龄 = 35天 → 健康等级: L4 (健康级)',
            ha='center', fontsize=10,
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white', edgecolor='black'))

    ax.text(5, 1.5, '建议：继续保持当前消费节奏，钱龄有望提升至优秀级',
            ha='center', fontsize=9, style='italic')

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图7_健康等级映射示意图.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    print('图7已生成')


# 生成所有附图
if __name__ == '__main__':
    print('开始生成专利01改进版附图...')
    create_figure1()
    create_figure2()
    create_figure3()
    create_figure4()
    create_figure5()
    create_figure6()
    create_figure7()
    print(f'\n所有附图已保存到: {output_dir}')
