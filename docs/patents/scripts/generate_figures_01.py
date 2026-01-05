# -*- coding: utf-8 -*-
"""生成专利01的附图：基于FIFO资源池模型的钱龄计算方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle, Circle, Polygon
import matplotlib.lines as mlines
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_01'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10, text_color='black'):
    """绘制带文字的方框"""
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.03,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize, color=text_color, weight='bold')

def draw_arrow(ax, start, end, color='black', style='->', connectionstyle='arc3,rad=0'):
    """绘制箭头"""
    ax.annotate('', xy=end, xytext=start,
                arrowprops=dict(arrowstyle=style, color=color, lw=1.5, connectionstyle=connectionstyle))

def draw_line(ax, start, end, color='black', linestyle='-', linewidth=1.5):
    """绘制线条"""
    ax.plot([start[0], end[0]], [start[1], end[1]], color=color, linestyle=linestyle, linewidth=linewidth)


def figure1_fifo_architecture():
    """图1：FIFO资源池模型架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 9.5, '图1  FIFO资源池模型架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 收入层
    ax.text(2, 8.5, '收入层', ha='center', va='center', fontsize=12, weight='bold', color='#333333')
    draw_box(ax, 2, 7.5, 2.5, 0.8, '收入交易检测', '#E8F4FD', 'black', 9)

    # 资源池层
    ax.text(7, 8.5, '资源池层（FIFO队列）', ha='center', va='center', fontsize=12, weight='bold', color='#333333')

    # 绘制资源池队列
    pool_y = 7
    pool_width = 2
    pool_height = 1.2
    pools = [
        ('资源池#1\n(1月工资)\n余额:¥500', '#D4EDDA', 4),
        ('资源池#2\n(2月工资)\n余额:¥8000', '#D4EDDA', 7),
        ('资源池#3\n(3月工资)\n余额:¥8000', '#D4EDDA', 10),
    ]

    for text, color, x in pools:
        rect = FancyBboxPatch((x - pool_width/2, pool_y - pool_height/2), pool_width, pool_height,
                              boxstyle="round,pad=0.02", facecolor=color, edgecolor='#28a745', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, pool_y, text, ha='center', va='center', fontsize=8)

    # 时间箭头
    ax.annotate('', xy=(11.5, 7), xytext=(2.5, 7),
                arrowprops=dict(arrowstyle='->', color='#666666', lw=2))
    ax.text(12, 7, '时间', ha='left', va='center', fontsize=9, color='#666666')
    ax.text(3.2, 6.2, '最早(先出)', ha='center', va='center', fontsize=8, color='#666666')
    ax.text(10.8, 6.2, '最新(后出)', ha='center', va='center', fontsize=8, color='#666666')

    # FIFO消耗模块
    draw_box(ax, 7, 4.5, 3, 1, 'FIFO消耗算法', '#FFF3CD', 'black', 10)

    # 消费链路记录
    draw_box(ax, 7, 3, 3, 0.8, '消费链路记录', '#F8D7DA', 'black', 9)

    # 钱龄计算模块
    draw_box(ax, 7, 1.5, 3, 1, '钱龄计算模块', '#D1ECF1', 'black', 10)

    # 支出层
    ax.text(12, 4.5, '支出层', ha='center', va='center', fontsize=12, weight='bold', color='#333333')
    draw_box(ax, 12, 3.5, 2.5, 0.8, '支出交易检测', '#E8F4FD', 'black', 9)

    # 输出
    draw_box(ax, 7, 0.3, 2.5, 0.6, '钱龄指标输出', '#E2E3E5', 'black', 9)

    # 绘制箭头连接
    # 收入到资源池
    draw_arrow(ax, (2, 7.1), (2, 7.5))
    draw_arrow(ax, (2, 7.5), (2.8, 7))

    # 资源池到FIFO消耗
    for x in [4, 7, 10]:
        draw_arrow(ax, (x, 6.4), (x, 5.5), style='-|>')
    ax.plot([4, 10], [5.5, 5.5], 'k-', lw=1.5)
    draw_arrow(ax, (7, 5.5), (7, 5))

    # 支出到FIFO
    draw_arrow(ax, (12, 3.9), (12, 4.5))
    draw_arrow(ax, (10.7, 4.5), (8.5, 4.5))

    # FIFO到消费链路
    draw_arrow(ax, (7, 4), (7, 3.4))

    # 消费链路到钱龄计算
    draw_arrow(ax, (7, 2.6), (7, 2))

    # 钱龄计算到输出
    draw_arrow(ax, (7, 1), (7, 0.6))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_FIFO资源池模型架构示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_fifo_consume_algorithm():
    """图2：FIFO消耗算法流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 14))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 14)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 13.5, '图2  FIFO消耗算法流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle_start = Circle((6, 12.5), 0.4, facecolor='#333333', edgecolor='black')
    ax.add_patch(circle_start)
    ax.text(6, 12.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 步骤1: 检测支出交易
    draw_box(ax, 6, 11.3, 4, 0.8, '检测到支出交易', '#E8F4FD', 'black', 10)
    draw_arrow(ax, (6, 12.1), (6, 11.7))

    # 步骤2: 获取剩余支出金额
    draw_box(ax, 6, 10.2, 4, 0.8, '设置剩余金额 = 支出金额', '#E8F4FD', 'black', 10)
    draw_arrow(ax, (6, 10.9), (6, 10.6))

    # 步骤3: 获取活跃资源池
    draw_box(ax, 6, 9.1, 4.5, 0.8, '获取所有活跃资源池(按时间升序)', '#E8F4FD', 'black', 9)
    draw_arrow(ax, (6, 9.8), (6, 9.5))

    # 判断1: 是否有活跃资源池
    diamond1 = Polygon([(6, 8.3), (7.3, 7.7), (6, 7.1), (4.7, 7.7)],
                       facecolor='#FFF3CD', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond1)
    ax.text(6, 7.7, '有活跃\n资源池?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.7), (6, 8.3))

    # 否 - 透支处理
    draw_box(ax, 10, 7.7, 2.5, 0.7, '透支处理', '#F8D7DA', 'black', 9)
    draw_arrow(ax, (7.3, 7.7), (8.7, 7.7))
    ax.text(8, 7.95, '否', ha='center', va='center', fontsize=8)

    # 是 - 获取最早资源池
    draw_box(ax, 6, 6.2, 4, 0.8, '获取最早的资源池 P', '#D4EDDA', 'black', 10)
    draw_arrow(ax, (6, 7.1), (6, 6.6))
    ax.text(6.2, 6.85, '是', ha='center', va='center', fontsize=8)

    # 判断2: 剩余金额 <= P余额?
    diamond2 = Polygon([(6, 5.4), (7.5, 4.7), (6, 4), (4.5, 4.7)],
                       facecolor='#FFF3CD', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond2)
    ax.text(6, 4.7, '剩余金额\n≤ P余额?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 5.8), (6, 5.4))

    # 是 - 从P扣减剩余金额
    draw_box(ax, 2.5, 4.7, 3.5, 0.7, '从P扣减剩余金额', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (4.5, 4.7), (4.2, 4.7))
    ax.text(4.3, 4.95, '是', ha='center', va='center', fontsize=8)

    # 记录消费链路（左侧）
    draw_box(ax, 2.5, 3.7, 3, 0.7, '记录消费链路', '#E8F4FD', 'black', 9)
    draw_arrow(ax, (2.5, 4.3), (2.5, 4))

    # 否 - 从P扣减P的余额
    draw_box(ax, 9.5, 4.7, 3.5, 0.7, '从P扣减P的全部余额', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (7.5, 4.7), (7.7, 4.7))
    ax.text(7.6, 4.95, '否', ha='center', va='center', fontsize=8)

    # 记录消费链路（右侧）
    draw_box(ax, 9.5, 3.7, 3, 0.7, '记录消费链路', '#E8F4FD', 'black', 9)
    draw_arrow(ax, (9.5, 4.3), (9.5, 4))

    # 标记P为耗尽
    draw_box(ax, 9.5, 2.8, 3, 0.7, '标记P为"耗尽"', '#F8D7DA', 'black', 9)
    draw_arrow(ax, (9.5, 3.3), (9.5, 3.1))

    # 更新剩余金额
    draw_box(ax, 9.5, 1.9, 3.5, 0.7, '剩余金额 -= P余额', '#E8F4FD', 'black', 9)
    draw_arrow(ax, (9.5, 2.4), (9.5, 2.2))

    # 循环返回
    ax.annotate('', xy=(6, 8.7), xytext=(9.5, 1.5),
                arrowprops=dict(arrowstyle='->', color='black', lw=1.5,
                                connectionstyle='arc3,rad=-0.3'))

    # 结束
    circle_end = Circle((2.5, 2.8), 0.4, facecolor='#333333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(2.5, 2.8, '结束', ha='center', va='center', fontsize=9, color='white', weight='bold')
    draw_arrow(ax, (2.5, 3.3), (2.5, 3.2))

    # 透支结束
    draw_arrow(ax, (10, 7.3), (10, 6.5))
    circle_end2 = Circle((10, 6.2), 0.3, facecolor='#333333', edgecolor='black')
    ax.add_patch(circle_end2)
    ax.text(10, 6.2, '结束', ha='center', va='center', fontsize=8, color='white')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_FIFO消耗算法流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_money_age_calculation():
    """图3：钱龄计算流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 9.5, '图3  钱龄计算流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 左侧：单笔交易钱龄计算
    ax.text(4, 8.5, '单笔交易钱龄计算', ha='center', va='center', fontsize=12, weight='bold')

    # 获取消费链路
    draw_box(ax, 4, 7.3, 3.5, 0.8, '获取支出的消费链路', '#E8F4FD', 'black', 9)

    # 链路列表
    rect = Rectangle((2.2, 5.3), 3.6, 1.5, facecolor='#F5F5F5', edgecolor='black', linewidth=1)
    ax.add_patch(rect)
    ax.text(4, 6.6, '消费链路列表', ha='center', va='center', fontsize=9, weight='bold')
    ax.text(4, 6.1, '链路1: 金额A₁, 天数D₁', ha='center', va='center', fontsize=8)
    ax.text(4, 5.7, '链路2: 金额A₂, 天数D₂', ha='center', va='center', fontsize=8)
    ax.text(4, 5.3, '...', ha='center', va='center', fontsize=8)

    draw_arrow(ax, (4, 6.9), (4, 6.8))

    # 计算公式
    draw_box(ax, 4, 4.3, 4, 1, '加权平均计算\n钱龄 = Σ(Aᵢ×Dᵢ) / Σ(Aᵢ)', '#FFF3CD', 'black', 9)
    draw_arrow(ax, (4, 5.0), (4, 4.8))

    # 输出单笔钱龄
    draw_box(ax, 4, 3, 3, 0.7, '输出：单笔钱龄(天)', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (4, 3.8), (4, 3.4))

    # 右侧：账户整体钱龄计算
    ax.text(10, 8.5, '账户整体钱龄计算', ha='center', va='center', fontsize=12, weight='bold')

    # 获取活跃资源池
    draw_box(ax, 10, 7.3, 3.5, 0.8, '获取所有活跃资源池', '#E8F4FD', 'black', 9)

    # 资源池列表
    rect2 = Rectangle((8.2, 5.3), 3.6, 1.5, facecolor='#F5F5F5', edgecolor='black', linewidth=1)
    ax.add_patch(rect2)
    ax.text(10, 6.6, '资源池列表', ha='center', va='center', fontsize=9, weight='bold')
    ax.text(10, 6.1, 'P₁: 余额B₁, 存活S₁天', ha='center', va='center', fontsize=8)
    ax.text(10, 5.7, 'P₂: 余额B₂, 存活S₂天', ha='center', va='center', fontsize=8)
    ax.text(10, 5.3, '...', ha='center', va='center', fontsize=8)

    draw_arrow(ax, (10, 6.9), (10, 6.8))

    # 计算公式
    draw_box(ax, 10, 4.3, 4, 1, '加权平均计算\n钱龄 = Σ(Bᵢ×Sᵢ) / Σ(Bᵢ)', '#FFF3CD', 'black', 9)
    draw_arrow(ax, (10, 5.0), (10, 4.8))

    # 输出整体钱龄
    draw_box(ax, 10, 3, 3, 0.7, '输出：整体钱龄(天)', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (10, 3.8), (10, 3.4))

    # 健康等级映射
    ax.text(7, 2, '健康等级映射', ha='center', va='center', fontsize=11, weight='bold')

    # 等级表格
    levels = [
        ('≥60天', '非常健康', '#28a745'),
        ('30-59天', '健康', '#5cb85c'),
        ('14-29天', '一般', '#f0ad4e'),
        ('7-13天', '偏低', '#ec971f'),
        ('3-6天', '紧张', '#d9534f'),
        ('0-2天', '月光', '#c9302c'),
    ]

    start_x = 1.5
    for i, (days, level, color) in enumerate(levels):
        x = start_x + i * 2
        rect = Rectangle((x - 0.8, 0.7), 1.6, 1, facecolor=color, edgecolor='black', linewidth=1, alpha=0.8)
        ax.add_patch(rect)
        ax.text(x, 1.3, level, ha='center', va='center', fontsize=9, color='white', weight='bold')
        ax.text(x, 0.9, days, ha='center', va='center', fontsize=8, color='white')

    # 箭头连接到健康等级
    draw_arrow(ax, (4, 2.6), (4, 1.8))
    draw_arrow(ax, (10, 2.6), (10, 1.8))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_钱龄计算流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_incremental_calculation():
    """图4：增量计算优化流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 12))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 11.5, '图4  增量计算优化流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle_start = Circle((6, 10.7), 0.35, facecolor='#333333', edgecolor='black')
    ax.add_patch(circle_start)
    ax.text(6, 10.7, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 检测交易变更
    draw_box(ax, 6, 9.6, 4, 0.8, '检测到交易变更事件', '#E8F4FD', 'black', 10)
    draw_arrow(ax, (6, 10.35), (6, 10))

    # 判断变更类型
    diamond = Polygon([(6, 8.8), (7.5, 8.2), (6, 7.6), (4.5, 8.2)],
                      facecolor='#FFF3CD', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 8.2, '变更类型?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 9.2), (6, 8.8))

    # 新增
    draw_box(ax, 2.5, 8.2, 2, 0.6, '新增', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (4.5, 8.2), (3.5, 8.2))

    # 修改
    draw_box(ax, 6, 7, 2, 0.6, '修改', '#FFF3CD', 'black', 9)
    draw_arrow(ax, (6, 7.6), (6, 7.3))

    # 删除
    draw_box(ax, 9.5, 8.2, 2, 0.6, '删除', '#F8D7DA', 'black', 9)
    draw_arrow(ax, (7.5, 8.2), (8.5, 8.2))

    # 确定变更时间点T
    draw_box(ax, 6, 5.8, 4.5, 0.8, '确定变更交易的时间点 T', '#E8F4FD', 'black', 10)

    # 连接到确定时间点
    draw_arrow(ax, (2.5, 7.9), (2.5, 5.8))
    ax.plot([2.5, 3.75], [5.8, 5.8], 'k-', lw=1.5)
    draw_arrow(ax, (6, 6.7), (6, 6.2))
    draw_arrow(ax, (9.5, 7.9), (9.5, 5.8))
    ax.plot([8.25, 9.5], [5.8, 5.8], 'k-', lw=1.5)

    # 标记脏数据
    draw_box(ax, 6, 4.7, 5, 0.8, '标记时间点T之后的资源池为"脏"', '#F8D7DA', 'black', 9)
    draw_arrow(ax, (6, 5.4), (6, 5.1))

    # 回滚消费记录
    draw_box(ax, 6, 3.6, 4.5, 0.8, '回滚脏资源池的消费记录', '#FFF3CD', 'black', 9)
    draw_arrow(ax, (6, 4.3), (6, 4))

    # 重新执行FIFO
    draw_box(ax, 6, 2.5, 4.5, 0.8, '重新执行FIFO消耗算法', '#D4EDDA', 'black', 9)
    draw_arrow(ax, (6, 3.2), (6, 2.9))

    # 更新钱龄
    draw_box(ax, 6, 1.4, 4, 0.8, '更新受影响交易的钱龄', '#D1ECF1', 'black', 9)
    draw_arrow(ax, (6, 2.1), (6, 1.8))

    # 结束
    circle_end = Circle((6, 0.5), 0.35, facecolor='#333333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(6, 0.5, '结束', ha='center', va='center', fontsize=9, color='white', weight='bold')
    draw_arrow(ax, (6, 1), (6, 0.85))

    # 性能对比注释
    ax.text(10.5, 2.5, '性能优化效果:', ha='left', va='center', fontsize=9, weight='bold')
    ax.text(10.5, 2.0, '全量重算: 2秒', ha='left', va='center', fontsize=8, color='#c9302c')
    ax.text(10.5, 1.6, '增量重算: 50ms', ha='left', va='center', fontsize=8, color='#28a745')

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_增量计算优化流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


def figure5_consumption_trace():
    """图5：消费链路追溯示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 9.5, '图5  消费链路追溯示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 时间轴
    ax.annotate('', xy=(13, 8.5), xytext=(1, 8.5),
                arrowprops=dict(arrowstyle='->', color='#666666', lw=2))
    ax.text(13.2, 8.5, '时间', ha='left', va='center', fontsize=10, color='#666666')

    # 收入事件（上方）
    income_events = [
        (2.5, '1月1日\n工资收入\n¥8000', 'P001'),
        (6, '2月1日\n工资收入\n¥8000', 'P002'),
        (9.5, '3月1日\n工资收入\n¥8000', 'P003'),
    ]

    for x, text, pool_id in income_events:
        # 资源池方框
        rect = FancyBboxPatch((x - 1.2, 7.2), 2.4, 1.2, boxstyle="round,pad=0.02",
                              facecolor='#D4EDDA', edgecolor='#28a745', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, 7.8, text, ha='center', va='center', fontsize=8)
        ax.text(x, 7.0, pool_id, ha='center', va='center', fontsize=8, color='#666666')
        # 连接到时间轴
        ax.plot([x, x], [7.2, 8.5], 'k--', lw=1, alpha=0.5)

    # 支出事件（下方）
    expense_events = [
        (3.5, '1月15日\n餐饮消费\n¥500', 'E001'),
        (5, '1月25日\n购物消费\n¥2000', 'E002'),
        (8, '2月20日\n旅游消费\n¥10000', 'E003'),
    ]

    for x, text, exp_id in expense_events:
        rect = FancyBboxPatch((x - 1.2, 5.3), 2.4, 1.2, boxstyle="round,pad=0.02",
                              facecolor='#F8D7DA', edgecolor='#dc3545', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, 5.9, text, ha='center', va='center', fontsize=8)
        ax.text(x, 5.1, exp_id, ha='center', va='center', fontsize=8, color='#666666')

    # 消费链路连接（用曲线箭头）
    # E001 -> P001
    ax.annotate('', xy=(2.5, 7.2), xytext=(3.5, 6.5),
                arrowprops=dict(arrowstyle='->', color='#007bff', lw=2,
                                connectionstyle='arc3,rad=0.2'))
    ax.text(2.8, 6.7, '¥500\n14天', ha='center', va='center', fontsize=7, color='#007bff')

    # E002 -> P001
    ax.annotate('', xy=(2.5, 7.2), xytext=(4.5, 6.5),
                arrowprops=dict(arrowstyle='->', color='#007bff', lw=2,
                                connectionstyle='arc3,rad=0.3'))
    ax.text(3.3, 7.0, '¥2000\n24天', ha='center', va='center', fontsize=7, color='#007bff')

    # E003 -> P001 (部分)
    ax.annotate('', xy=(2.5, 7.2), xytext=(7.2, 6.5),
                arrowprops=dict(arrowstyle='->', color='#17a2b8', lw=2,
                                connectionstyle='arc3,rad=0.4'))
    ax.text(4.5, 7.5, '¥5500\n50天', ha='center', va='center', fontsize=7, color='#17a2b8')

    # E003 -> P002 (部分)
    ax.annotate('', xy=(6, 7.2), xytext=(8, 6.5),
                arrowprops=dict(arrowstyle='->', color='#17a2b8', lw=2,
                                connectionstyle='arc3,rad=0.2'))
    ax.text(7.2, 7.0, '¥4500\n19天', ha='center', va='center', fontsize=7, color='#17a2b8')

    # 消费链路记录表
    ax.text(7, 4, '消费链路记录表', ha='center', va='center', fontsize=11, weight='bold')

    # 表格
    table_data = [
        ['支出ID', '资源池ID', '扣减金额', '资源池时间', '链路钱龄'],
        ['E001', 'P001', '¥500', '1月1日', '14天'],
        ['E002', 'P001', '¥2000', '1月1日', '24天'],
        ['E003', 'P001', '¥5500', '1月1日', '50天'],
        ['E003', 'P002', '¥4500', '2月1日', '19天'],
    ]

    cell_width = 2.2
    cell_height = 0.5
    start_x = 7 - (5 * cell_width) / 2
    start_y = 3.5

    for i, row in enumerate(table_data):
        for j, cell in enumerate(row):
            x = start_x + j * cell_width
            y = start_y - i * cell_height
            if i == 0:
                facecolor = '#E8F4FD'
            else:
                facecolor = 'white'
            rect = Rectangle((x, y - cell_height), cell_width, cell_height,
                            facecolor=facecolor, edgecolor='black', linewidth=1)
            ax.add_patch(rect)
            ax.text(x + cell_width/2, y - cell_height/2, cell,
                   ha='center', va='center', fontsize=8)

    # 钱龄计算示例
    ax.text(7, 0.8, 'E003钱龄计算: (5500×50 + 4500×19) / 10000 = 36.05天',
           ha='center', va='center', fontsize=10,
           bbox=dict(boxstyle='round', facecolor='#FFF3CD', edgecolor='#ffc107'))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图5_消费链路追溯示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图5 已生成')


if __name__ == '__main__':
    print('开始生成专利01附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_fifo_architecture()
    figure2_fifo_consume_algorithm()
    figure3_money_age_calculation()
    figure4_incremental_calculation()
    figure5_consumption_trace()
    print('专利01全部附图生成完成!')
