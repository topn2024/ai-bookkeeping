# -*- coding: utf-8 -*-
"""生成专利01 v3.1版本的附图（12张）"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle, Circle, Polygon
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'Arial Unicode MS']
plt.rcParams['axes.unicode_minus'] = False

output_dir = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_01_v3.1'
os.makedirs(output_dir, exist_ok=True)

def create_figure1():
    """图1：FIFO资源池模型架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图1 FIFO资源池模型架构示意图', fontsize=14, fontweight='bold')

    # 资源池队列
    pools = [
        ('P1\n1月1日\n¥8000', 0.3, '#90EE90'),
        ('P2\n2月1日\n¥5000', 0.7, '#98FB98'),
        ('P3\n3月1日\n¥6000', 1.0, '#7CFC00'),
    ]

    for i, (label, fill, color) in enumerate(pools):
        x = 1 + i * 2.5
        rect = FancyBboxPatch((x, 4), 2, 2.5, boxstyle="round,pad=0.05",
                              facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x+1, 5.25, label, ha='center', va='center', fontsize=10)
        # 余额条
        bar_height = fill * 2
        bar = Rectangle((x+0.2, 4.2), 1.6, bar_height, facecolor='#228B22', alpha=0.7)
        ax.add_patch(bar)

    # FIFO箭头
    ax.annotate('', xy=(7.5, 5.25), xytext=(1, 5.25),
                arrowprops=dict(arrowstyle='->', color='red', lw=2))
    ax.text(4.25, 5.8, 'FIFO顺序', ha='center', fontsize=11, color='red')

    # 消费事件
    expense_box = FancyBboxPatch((8.5, 4), 2.5, 2.5, boxstyle="round,pad=0.05",
                                  facecolor='#FFB6C1', edgecolor='black', linewidth=2)
    ax.add_patch(expense_box)
    ax.text(9.75, 5.25, '消费事件\n¥10000', ha='center', va='center', fontsize=11)

    # 消费链路
    ax.annotate('', xy=(2, 4), xytext=(9, 4),
                arrowprops=dict(arrowstyle='->', color='blue', lw=1.5,
                               connectionstyle='arc3,rad=0.3'))
    ax.text(5.5, 2.8, '消费链路\nP1:¥8000 + P2:¥2000', ha='center', fontsize=10, color='blue')

    # 钱龄计算
    calc_box = FancyBboxPatch((4, 0.5), 4, 1.5, boxstyle="round,pad=0.05",
                               facecolor='#E6E6FA', edgecolor='black', linewidth=2)
    ax.add_patch(calc_box)
    ax.text(6, 1.25, '加权钱龄 = (8000×60 + 2000×30) / 10000 = 54天',
            ha='center', va='center', fontsize=10)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图1_FIFO资源池模型架构示意图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure2():
    """图2：FIFO消耗算法流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(10, 12))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis('off')
    ax.set_title('图2 FIFO消耗算法流程图', fontsize=14, fontweight='bold')

    # 流程节点
    nodes = [
        (5, 11, '开始', 'ellipse', '#90EE90'),
        (5, 9.5, '获取分布式锁', 'box', '#87CEEB'),
        (5, 8, '查询活跃资源池\n(按时间排序)', 'box', '#87CEEB'),
        (5, 6.5, '遍历资源池', 'diamond', '#FFD700'),
        (5, 5, '计算消耗金额\nconsume=MIN(remaining,balance)', 'box', '#87CEEB'),
        (5, 3.5, '生成消费链路\n计算链路钱龄', 'box', '#87CEEB'),
        (5, 2, '剩余金额>0?', 'diamond', '#FFD700'),
        (5, 0.5, '释放锁并返回', 'ellipse', '#FFB6C1'),
    ]

    for x, y, text, shape, color in nodes:
        if shape == 'ellipse':
            ellipse = mpatches.Ellipse((x, y), 3, 0.8, facecolor=color, edgecolor='black')
            ax.add_patch(ellipse)
        elif shape == 'box':
            rect = FancyBboxPatch((x-1.5, y-0.5), 3, 1, boxstyle="round,pad=0.05",
                                   facecolor=color, edgecolor='black')
            ax.add_patch(rect)
        elif shape == 'diamond':
            diamond = Polygon([(x, y+0.5), (x+1.2, y), (x, y-0.5), (x-1.2, y)],
                             facecolor=color, edgecolor='black')
            ax.add_patch(diamond)
        ax.text(x, y, text, ha='center', va='center', fontsize=9)

    # 箭头
    arrows = [(5, 10.6, 5, 10), (5, 9, 5, 8.5), (5, 7.5, 5, 7),
              (5, 6, 5, 5.5), (5, 4.5, 5, 4), (5, 3, 5, 2.5), (5, 1.5, 5, 1)]
    for x1, y1, x2, y2 in arrows:
        ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                    arrowprops=dict(arrowstyle='->', color='black'))

    # 循环箭头
    ax.annotate('', xy=(6.5, 6.5), xytext=(6.5, 5),
                arrowprops=dict(arrowstyle='->', color='green', connectionstyle='arc3,rad=-0.5'))
    ax.text(7.5, 5.75, '继续遍历', fontsize=8, color='green')

    # 透支分支
    ax.annotate('', xy=(8, 2), xytext=(6.2, 2),
                arrowprops=dict(arrowstyle='->', color='red'))
    ax.text(8.5, 2, '是\n创建透支链路', fontsize=8, ha='left', color='red')

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图2_FIFO消耗算法流程图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure3():
    """图3：增量计算优化原理图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 6))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 6)
    ax.axis('off')
    ax.set_title('图3 增量计算优化原理图', fontsize=14, fontweight='bold')

    # 时间轴
    ax.arrow(0.5, 3, 10.5, 0, head_width=0.15, head_length=0.2, fc='black', ec='black')
    ax.text(11.2, 3, 't', fontsize=12)

    # 事件点
    events = [(1, 'T1'), (3, 'T2'), (5, 'T3*'), (7, 'T4'), (9, 'T5')]
    for x, label in events:
        color = 'red' if '*' in label else 'blue'
        ax.plot(x, 3, 'o', markersize=12, color=color)
        ax.text(x, 2.5, label.replace('*', '\n(变更)'), ha='center', fontsize=9, color=color)

    # 脏数据范围
    ax.axvspan(5, 10, alpha=0.2, color='red')
    ax.text(7.5, 3.8, '脏数据范围', ha='center', fontsize=10, color='red')

    # 增量重算说明
    ax.text(7.5, 4.5, '仅重算T3之后的链路', ha='center', fontsize=11,
            bbox=dict(boxstyle='round', facecolor='#FFFACD'))

    # 复杂度对比
    ax.text(2, 1.2, '全量重算: O(N²)', fontsize=11, color='gray')
    ax.text(2, 0.6, '增量重算: O(K×logM)', fontsize=11, color='green')
    ax.text(8, 1.2, '性能提升', fontsize=10)
    ax.text(8, 0.6, '50-200倍', fontsize=14, fontweight='bold', color='green')

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图3_增量计算优化原理图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure4():
    """图4：系统分层架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图4 系统分层架构图', fontsize=14, fontweight='bold')

    layers = [
        (7, '表示层', ['移动App', 'Web端', 'API'], '#FFB6C1'),
        (5.5, '业务层', ['FIFO引擎', '钱龄引擎', '增量引擎', '降级控制'], '#87CEEB'),
        (4, '缓存层', ['Redis', 'L1 Cache'], '#98FB98'),
        (2.5, '数据层', ['SQLite', 'PostgreSQL', '分片存储'], '#DDA0DD'),
        (1, '加速层', ['GPU加速', 'FPGA加速'], '#FFD700'),
    ]

    for y, name, components, color in layers:
        rect = FancyBboxPatch((0.5, y-0.5), 11, 1.2, boxstyle="round,pad=0.05",
                               facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(1.2, y+0.1, name, fontsize=11, fontweight='bold')

        comp_x = 3
        for comp in components:
            comp_rect = FancyBboxPatch((comp_x, y-0.3), 2, 0.8, boxstyle="round,pad=0.02",
                                        facecolor='white', edgecolor='gray')
            ax.add_patch(comp_rect)
            ax.text(comp_x+1, y+0.1, comp, ha='center', fontsize=9)
            comp_x += 2.2

    # 层间箭头
    for i in range(4):
        y = 6.5 - i * 1.5
        ax.annotate('', xy=(6, y-0.6), xytext=(6, y+0.1),
                    arrowprops=dict(arrowstyle='<->', color='gray', lw=1.5))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图4_系统分层架构图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure5():
    """图5：消费链路桑基图示例"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图5 消费链路桑基图示例', fontsize=14, fontweight='bold')

    # 收入节点（左侧）
    incomes = [
        (1, 6.5, '工资 ¥8000\n(1月1日)', '#90EE90'),
        (1, 4.5, '奖金 ¥5000\n(2月1日)', '#98FB98'),
        (1, 2.5, '副业 ¥3000\n(3月1日)', '#7CFC00'),
    ]

    # 支出节点（右侧）
    expenses = [
        (10, 6, '房租 ¥3000', '#FFB6C1'),
        (10, 4.5, '餐饮 ¥2000', '#FFA07A'),
        (10, 3, '购物 ¥5000', '#FF6347'),
        (10, 1.5, '其他 ¥1000', '#FF4500'),
    ]

    for x, y, label, color in incomes + expenses:
        rect = FancyBboxPatch((x-0.8, y-0.4), 2.5, 0.9, boxstyle="round,pad=0.05",
                               facecolor=color, edgecolor='black')
        ax.add_patch(rect)
        ax.text(x+0.5, y, label, ha='center', va='center', fontsize=9)

    # 消费链路（连线）
    links = [
        (1, 6.5, 10, 6, 0.4, '#228B22'),      # 工资 -> 房租
        (1, 6.5, 10, 4.5, 0.25, '#228B22'),   # 工资 -> 餐饮
        (1, 6.5, 10, 3, 0.35, '#228B22'),     # 工资 -> 购物
        (1, 4.5, 10, 3, 0.35, '#32CD32'),     # 奖金 -> 购物
        (1, 4.5, 10, 1.5, 0.15, '#32CD32'),   # 奖金 -> 其他
        (1, 2.5, 10, 1.5, 0.15, '#7CFC00'),   # 副业 -> 其他
    ]

    for x1, y1, x2, y2, width, color in links:
        ax.plot([x1+1.5, x2-1], [y1, y2], color=color, linewidth=width*20, alpha=0.6)

    ax.text(5.5, 7.5, '资金流向追溯', ha='center', fontsize=12, fontweight='bold')
    ax.text(1.5, 0.5, '收入来源', ha='center', fontsize=10)
    ax.text(10.5, 0.5, '支出去向', ha='center', fontsize=10)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图5_消费链路桑基图示例.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure6():
    """图6：性能对比测试结果图"""
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    # 左图：延迟对比
    methods = ['本发明\n(B+树)', 'YNAB', '无索引']
    latencies = [12, 120, 85]
    colors = ['#4CAF50', '#FFC107', '#F44336']

    axes[0].bar(methods, latencies, color=colors)
    axes[0].set_ylabel('延迟 (ms)', fontsize=11)
    axes[0].set_title('查询延迟对比', fontsize=12, fontweight='bold')
    for i, v in enumerate(latencies):
        axes[0].text(i, v+3, f'{v}ms', ha='center', fontsize=10)

    # 右图：准确率对比
    methods2 = ['本发明', 'YNAB', '简单平均']
    accuracy = [99.2, 75, 70]

    axes[1].bar(methods2, accuracy, color=['#4CAF50', '#FFC107', '#F44336'])
    axes[1].set_ylabel('准确率 (%)', fontsize=11)
    axes[1].set_title('计算准确率对比', fontsize=12, fontweight='bold')
    axes[1].set_ylim(0, 110)
    for i, v in enumerate(accuracy):
        axes[1].text(i, v+2, f'{v}%', ha='center', fontsize=10)

    fig.suptitle('图6 性能对比测试结果图', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{output_dir}/图6_性能对比测试结果图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure7():
    """图7：钱龄健康等级映射图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 4))
    ax.set_xlim(0, 70)
    ax.set_ylim(0, 4)
    ax.axis('off')
    ax.set_title('图7 钱龄健康等级映射图', fontsize=14, fontweight='bold')

    levels = [
        (0, 3, 'L1危险', '#FF0000'),
        (3, 7, 'L2警告', '#FF6600'),
        (7, 14, 'L3一般', '#FFCC00'),
        (14, 30, 'L4良好', '#99CC00'),
        (30, 60, 'L5优秀', '#00CC00'),
        (60, 70, 'L6卓越', '#006600'),
    ]

    for start, end, label, color in levels:
        rect = Rectangle((start, 1), end-start, 2, facecolor=color, edgecolor='white', linewidth=2)
        ax.add_patch(rect)
        ax.text((start+end)/2, 2, label, ha='center', va='center', fontsize=11,
                color='white' if color in ['#FF0000', '#006600'] else 'black', fontweight='bold')
        ax.text((start+end)/2, 0.5, f'{start}-{end}天' if end < 70 else f'>{start}天',
                ha='center', fontsize=9)

    ax.text(35, 3.5, '钱龄（天）→', ha='center', fontsize=12)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图7_钱龄健康等级映射图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure8():
    """图8：数据库ER图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 8))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图8 数据库ER图', fontsize=14, fontweight='bold')

    # ResourcePool表
    pool_fields = ['pool_id (PK)', 'user_id (FK)', 'account_id', 'income_id',
                   'initial_amount', 'current_balance', 'income_timestamp',
                   'status', 'resource_type', 'shard_id']
    rect1 = FancyBboxPatch((0.5, 3), 4, 4.5, boxstyle="round,pad=0.05",
                            facecolor='#E6F3FF', edgecolor='black', linewidth=2)
    ax.add_patch(rect1)
    ax.text(2.5, 7.2, 'ResourcePool', ha='center', fontsize=11, fontweight='bold')
    for i, field in enumerate(pool_fields):
        ax.text(0.8, 6.5-i*0.4, field, fontsize=8)

    # ConsumptionLink表
    link_fields = ['link_id (PK)', 'expense_id (FK)', 'pool_id (FK)',
                   'consumed_amount', 'pool_income_time', 'expense_time',
                   'age_days', 'link_type', 'resource_type']
    rect2 = FancyBboxPatch((5.5, 3.5), 4, 4, boxstyle="round,pad=0.05",
                            facecolor='#FFF3E6', edgecolor='black', linewidth=2)
    ax.add_patch(rect2)
    ax.text(7.5, 7.2, 'ConsumptionLink', ha='center', fontsize=11, fontweight='bold')
    for i, field in enumerate(link_fields):
        ax.text(5.8, 6.8-i*0.4, field, fontsize=8)

    # DirtyMark表
    dirty_fields = ['mark_id (PK)', 'user_id', 'dirty_from', 'reason', 'affected_pool_ids']
    rect3 = FancyBboxPatch((10.5, 4.5), 3, 2.5, boxstyle="round,pad=0.05",
                            facecolor='#FFE6E6', edgecolor='black', linewidth=2)
    ax.add_patch(rect3)
    ax.text(12, 6.7, 'DirtyMark', ha='center', fontsize=11, fontweight='bold')
    for i, field in enumerate(dirty_fields):
        ax.text(10.8, 6.2-i*0.35, field, fontsize=8)

    # 关系连线
    ax.annotate('', xy=(5.5, 5), xytext=(4.5, 5),
                arrowprops=dict(arrowstyle='->', color='blue', lw=2))
    ax.text(5, 5.3, '1:N', fontsize=9, color='blue')

    ax.annotate('', xy=(10.5, 5.5), xytext=(9.5, 5.5),
                arrowprops=dict(arrowstyle='->', color='blue', lw=2))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图8_数据库ER图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure9():
    """图9：分片存储架构图（新增）"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图9 分片存储架构图', fontsize=14, fontweight='bold')

    # 用户数据
    user_box = FancyBboxPatch((4.5, 6.5), 3, 1, boxstyle="round,pad=0.05",
                               facecolor='#87CEEB', edgecolor='black', linewidth=2)
    ax.add_patch(user_box)
    ax.text(6, 7, '用户A\n200万资源池', ha='center', va='center', fontsize=10)

    # 分片路由
    router = FancyBboxPatch((4.5, 4.5), 3, 1.2, boxstyle="round,pad=0.05",
                             facecolor='#FFD700', edgecolor='black', linewidth=2)
    ax.add_patch(router)
    ax.text(6, 5.1, '分片路由\nshard_id = year(timestamp)', ha='center', va='center', fontsize=9)

    ax.annotate('', xy=(6, 5.7), xytext=(6, 6.5),
                arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # 分片存储
    shards = [
        (1, 2, '2023分片\n50万条', '#90EE90', '冷'),
        (4, 2, '2024分片\n80万条', '#98FB98', '温'),
        (7, 2, '2025分片\n50万条', '#7CFC00', '热'),
        (10, 2, '2026分片\n20万条', '#00FF00', '热'),
    ]

    for x, y, label, color, temp in shards:
        rect = FancyBboxPatch((x-0.8, y-0.8), 2.5, 1.8, boxstyle="round,pad=0.05",
                               facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x+0.45, y, label, ha='center', va='center', fontsize=9)
        ax.text(x+0.45, y-1.2, f'[{temp}]', ha='center', fontsize=8, color='gray')

        ax.annotate('', xy=(x+0.45, y+0.8), xytext=(6, 4.5),
                    arrowprops=dict(arrowstyle='->', color='gray', lw=1))

    # FIFO消耗顺序
    ax.annotate('', xy=(10, 2), xytext=(1.5, 2),
                arrowprops=dict(arrowstyle='->', color='red', lw=2))
    ax.text(5.75, 2.5, 'FIFO消耗顺序', fontsize=10, color='red', ha='center')

    # 存储介质
    ax.text(1.5, 0.3, '对象存储\n(压缩归档)', ha='center', fontsize=8)
    ax.text(5, 0.3, 'SSD', ha='center', fontsize=8)
    ax.text(8.5, 0.3, 'Redis+SSD', ha='center', fontsize=8)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图9_分片存储架构图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure10():
    """图10：GPU加速并行计算示意图（新增）"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 8))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图10 GPU加速并行计算示意图', fontsize=14, fontweight='bold')

    # CPU端
    cpu_box = FancyBboxPatch((0.5, 5.5), 3, 2, boxstyle="round,pad=0.05",
                              facecolor='#B0C4DE', edgecolor='black', linewidth=2)
    ax.add_patch(cpu_box)
    ax.text(2, 6.5, 'CPU主机端', ha='center', fontsize=11, fontweight='bold')
    ax.text(2, 6, '数据准备\n任务调度', ha='center', fontsize=9)

    # GPU端
    gpu_box = FancyBboxPatch((4.5, 2), 9, 5.5, boxstyle="round,pad=0.05",
                              facecolor='#98FB98', edgecolor='black', linewidth=2)
    ax.add_patch(gpu_box)
    ax.text(9, 7, 'GPU设备端', ha='center', fontsize=11, fontweight='bold')

    # 并行前缀和
    prefix_box = FancyBboxPatch((5, 4.5), 4, 2, boxstyle="round,pad=0.05",
                                 facecolor='#FFFACD', edgecolor='black')
    ax.add_patch(prefix_box)
    ax.text(7, 5.5, '并行前缀和\nParallel Prefix Sum', ha='center', fontsize=10, fontweight='bold')
    ax.text(7, 4.8, '累计余额计算', ha='center', fontsize=9)

    # 并行二分查找
    search_box = FancyBboxPatch((10, 4.5), 3, 2, boxstyle="round,pad=0.05",
                                 facecolor='#FFE4B5', edgecolor='black')
    ax.add_patch(search_box)
    ax.text(11.5, 5.5, '并行二分查找', ha='center', fontsize=10, fontweight='bold')
    ax.text(11.5, 4.8, '消耗边界定位', ha='center', fontsize=9)

    # 线程块
    for i in range(4):
        thread_box = Rectangle((5.2+i*0.9, 2.5), 0.7, 1.5, facecolor='#ADD8E6', edgecolor='black')
        ax.add_patch(thread_box)
        ax.text(5.55+i*0.9, 3.25, f'T{i}', ha='center', fontsize=8)
    ax.text(7, 2.2, 'Thread Block 0', ha='center', fontsize=8)

    for i in range(4):
        thread_box = Rectangle((10.2+i*0.6, 2.5), 0.5, 1.5, facecolor='#ADD8E6', edgecolor='black')
        ax.add_patch(thread_box)
    ax.text(11.5, 2.2, 'Thread Block 1', ha='center', fontsize=8)

    # 数据传输
    ax.annotate('', xy=(4.5, 6), xytext=(3.5, 6),
                arrowprops=dict(arrowstyle='->', color='blue', lw=2))
    ax.text(4, 6.3, 'PCIe', fontsize=8, color='blue')

    ax.annotate('', xy=(9, 4.5), xytext=(9, 5.5),
                arrowprops=dict(arrowstyle='->', color='green', lw=1.5))

    # 性能数据
    perf_box = FancyBboxPatch((0.5, 0.5), 4, 1.5, boxstyle="round,pad=0.05",
                               facecolor='#E6E6FA', edgecolor='black')
    ax.add_patch(perf_box)
    ax.text(2.5, 1.25, '100万笔批量处理\nCPU: 45s → GPU: 1.8s\n加速比: 25x',
            ha='center', va='center', fontsize=9)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图10_GPU加速并行计算示意图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure11():
    """图11：FPGA流水线架构图（新增）"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 8))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图11 FPGA流水线架构图', fontsize=14, fontweight='bold')

    # FPGA芯片
    fpga_box = FancyBboxPatch((1, 1.5), 12, 5.5, boxstyle="round,pad=0.1",
                               facecolor='#E8F4E8', edgecolor='#228B22', linewidth=3)
    ax.add_patch(fpga_box)
    ax.text(7, 6.7, 'FPGA FIFO Engine', ha='center', fontsize=12, fontweight='bold', color='#228B22')

    # 流水线阶段
    stages = [
        (2, 4, 'Stage 1\n取指', '#FFB6C1'),
        (4.5, 4, 'Stage 2\n解码', '#87CEEB'),
        (7, 4, 'Stage 3\n计算', '#98FB98'),
        (9.5, 4, 'Stage 4\n写回', '#DDA0DD'),
    ]

    for x, y, label, color in stages:
        rect = FancyBboxPatch((x-0.8, y-0.8), 2, 1.8, boxstyle="round,pad=0.05",
                               facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x+0.2, y, label, ha='center', va='center', fontsize=10)

    # 流水线箭头
    for i in range(3):
        x = 3.2 + i * 2.5
        ax.annotate('', xy=(x+0.8, 4), xytext=(x, 4),
                    arrowprops=dict(arrowstyle='->', color='black', lw=2))

    # BRAM
    bram = FancyBboxPatch((2, 2), 3, 1.2, boxstyle="round,pad=0.05",
                           facecolor='#FFFACD', edgecolor='black')
    ax.add_patch(bram)
    ax.text(3.5, 2.6, 'BRAM\n资源池队列缓存', ha='center', va='center', fontsize=9)

    # 寄存器
    for i in range(4):
        reg = Rectangle((6+i*1.5, 2.2), 1.2, 0.8, facecolor='#ADD8E6', edgecolor='black')
        ax.add_patch(reg)
        ax.text(6.6+i*1.5, 2.6, f'REG{i}', ha='center', fontsize=8)

    # 输入输出
    ax.annotate('AXI-Stream\nIN', xy=(1, 4), xytext=(-0.5, 4),
                fontsize=9, ha='right',
                arrowprops=dict(arrowstyle='->', color='blue', lw=2))
    ax.annotate('AXI-Stream\nOUT', xy=(13.5, 4), xytext=(11.2, 4),
                fontsize=9, ha='left',
                arrowprops=dict(arrowstyle='->', color='blue', lw=2))

    # 性能指标
    perf_box = FancyBboxPatch((1, 0.2), 12, 1),
    ax.text(7, 0.5, '时钟: 200MHz | 延迟: 20ns/笔 | 吞吐量: 2亿TPS | 功耗: 15W',
            ha='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round', facecolor='#FFFACD', edgecolor='black'))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图11_FPGA流水线架构图.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_figure12():
    """图12：FIFO变体应用场景图（新增）"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 8))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 8)
    ax.axis('off')
    ax.set_title('图12 FIFO变体应用场景图', fontsize=14, fontweight='bold')

    # 通用FIFO框架
    core = FancyBboxPatch((5, 3.5), 4, 2, boxstyle="round,pad=0.1",
                           facecolor='#FFD700', edgecolor='black', linewidth=3)
    ax.add_patch(core)
    ax.text(7, 4.5, '通用FIFO\n资源池框架', ha='center', va='center', fontsize=12, fontweight='bold')

    # 三种变体
    variants = [
        (2, 6.5, 'MONEY\n资金钱龄', '#90EE90', '个人财务\n企业资金周转'),
        (7, 6.5, 'STOCK\n股票持仓', '#87CEEB', '成本核算\n税务优化'),
        (12, 6.5, 'INVENTORY\n库存管理', '#DDA0DD', '库龄分析\n滞销预警'),
    ]

    for x, y, label, color, desc in variants:
        rect = FancyBboxPatch((x-1.5, y-0.7), 3, 1.5, boxstyle="round,pad=0.05",
                               facecolor=color, edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=10, fontweight='bold')
        ax.text(x, y-1.5, desc, ha='center', fontsize=9, color='gray')

        ax.annotate('', xy=(x, y-0.7), xytext=(7, 5.5),
                    arrowprops=dict(arrowstyle='->', color='gray', lw=1.5))

    # 公共接口
    interface_box = FancyBboxPatch((4, 1), 6, 1.8, boxstyle="round,pad=0.05",
                                    facecolor='#E6E6FA', edgecolor='black')
    ax.add_patch(interface_box)
    ax.text(7, 1.9, '统一接口: IResourcePool', ha='center', fontsize=10, fontweight='bold')
    ax.text(7, 1.3, 'create() | consume() | trace() | calculate_age()', ha='center', fontsize=9)

    ax.annotate('', xy=(7, 2.8), xytext=(7, 3.5),
                arrowprops=dict(arrowstyle='->', color='black', lw=2))

    plt.tight_layout()
    plt.savefig(f'{output_dir}/图12_FIFO变体应用场景图.png', dpi=150, bbox_inches='tight')
    plt.close()

# 生成所有图
if __name__ == '__main__':
    print('开始生成专利01 v3.1附图...')

    create_figure1()
    print('  图1 完成')

    create_figure2()
    print('  图2 完成')

    create_figure3()
    print('  图3 完成')

    create_figure4()
    print('  图4 完成')

    create_figure5()
    print('  图5 完成')

    create_figure6()
    print('  图6 完成')

    create_figure7()
    print('  图7 完成')

    create_figure8()
    print('  图8 完成')

    create_figure9()
    print('  图9 完成 (新增：分片存储)')

    create_figure10()
    print('  图10 完成 (新增：GPU加速)')

    create_figure11()
    print('  图11 完成 (新增：FPGA流水线)')

    create_figure12()
    print('  图12 完成 (新增：FIFO变体)')

    print(f'\n全部12张附图已保存到: {output_dir}')
