# -*- coding: utf-8 -*-
"""生成专利11的附图：离线优先增量同步方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_11'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_offline_first_architecture():
    """图1：离线优先架构示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图1  离线优先架构示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 客户端层
    client_box = FancyBboxPatch((1, 6.5), 5.5, 3.5, boxstyle="round,pad=0.02",
                                facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(client_box)
    ax.text(3.75, 9.5, '客户端 (离线优先)', ha='center', va='center', fontsize=11, weight='bold')

    draw_box(ax, 2.5, 8.3, 2, 0.8, '本地数据库', '#BBDEFB', 'black', 9)
    draw_box(ax, 5, 8.3, 2, 0.8, '操作队列', '#BBDEFB', 'black', 9)
    draw_box(ax, 3.75, 7, 3.5, 0.8, '同步引擎', '#90CAF9', 'black', 9)

    # 网络层
    network_box = FancyBboxPatch((6.75, 7), 0.5, 2, boxstyle="round,pad=0.01",
                                 facecolor='#FFF3E0', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(network_box)
    ax.text(7, 8, '网\n络', ha='center', va='center', fontsize=9, rotation=90)

    # 服务端层
    server_box = FancyBboxPatch((7.5, 6.5), 5.5, 3.5, boxstyle="round,pad=0.02",
                                facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(server_box)
    ax.text(10.25, 9.5, '服务端', ha='center', va='center', fontsize=11, weight='bold')

    draw_box(ax, 9, 8.3, 2, 0.8, '云端数据库', '#C8E6C9', 'black', 9)
    draw_box(ax, 11.5, 8.3, 2, 0.8, '同步服务', '#C8E6C9', 'black', 9)
    draw_box(ax, 10.25, 7, 3.5, 0.8, '冲突处理', '#A5D6A7', 'black', 9)

    # 双向箭头
    ax.annotate('', xy=(7.25, 8), xytext=(6.5, 8),
                arrowprops=dict(arrowstyle='<->', color='#EF6C00', lw=2))

    # 离线模式
    offline_box = FancyBboxPatch((1, 3), 5.5, 2.5, boxstyle="round,pad=0.02",
                                 facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(offline_box)
    ax.text(3.75, 5, '离线模式', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(3.75, 4.2, '所有操作 → 本地队列', ha='center', va='center', fontsize=9)
    ax.text(3.75, 3.5, '自动重试 | 冲突标记', ha='center', va='center', fontsize=9)

    # 在线模式
    online_box = FancyBboxPatch((7.5, 3), 5.5, 2.5, boxstyle="round,pad=0.02",
                                facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(online_box)
    ax.text(10.25, 5, '在线模式', ha='center', va='center', fontsize=10, weight='bold')
    ax.text(10.25, 4.2, '队列上传 → 增量同步', ha='center', va='center', fontsize=9)
    ax.text(10.25, 3.5, '实时更新 | 双向同步', ha='center', va='center', fontsize=9)

    # 状态切换
    ax.annotate('', xy=(7.5, 4.2), xytext=(6.5, 4.2),
                arrowprops=dict(arrowstyle='<->', color='#333', lw=2))
    ax.text(7, 4.6, '网络状态', ha='center', va='center', fontsize=8)

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_离线优先架构示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_three_phase_sync():
    """图2：三阶段同步流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 11.5, '图2  三阶段同步流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 第一阶段：推送
    phase1 = FancyBboxPatch((1, 8.5), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#FFCDD2', edgecolor='#C62828', linewidth=2)
    ax.add_patch(phase1)
    ax.text(7, 10.3, '阶段一：推送 (Push)', ha='center', va='center', fontsize=12, weight='bold')

    push_items = [
        (3, 9, '获取本地\n待同步队列', '#EF9A9A'),
        (6, 9, '批量上传\n变更数据', '#EF9A9A'),
        (9, 9, '等待服务端\n确认', '#EF9A9A'),
    ]
    for x, y, text, color in push_items:
        draw_box(ax, x, y, 2.5, 1, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 9), (4.75, 9))
    draw_arrow(ax, (7.25, 9), (7.75, 9))

    # 第二阶段：拉取
    phase2 = FancyBboxPatch((1, 5.3), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#C8E6C9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(phase2)
    ax.text(7, 7.1, '阶段二：拉取 (Pull)', ha='center', va='center', fontsize=12, weight='bold')

    pull_items = [
        (3, 5.8, '请求服务端\n增量数据', '#A5D6A7'),
        (6, 5.8, '下载变更\n记录', '#A5D6A7'),
        (9, 5.8, '合并到\n本地数据库', '#A5D6A7'),
    ]
    for x, y, text, color in pull_items:
        draw_box(ax, x, y, 2.5, 1, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 5.8), (4.75, 5.8))
    draw_arrow(ax, (7.25, 5.8), (7.75, 5.8))

    draw_arrow(ax, (7, 8.5), (7, 7.5))

    # 第三阶段：确认
    phase3 = FancyBboxPatch((1, 2.1), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#BBDEFB', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(phase3)
    ax.text(7, 3.9, '阶段三：确认 (Confirm)', ha='center', va='center', fontsize=12, weight='bold')

    confirm_items = [
        (3, 2.6, '更新同步\n时间戳', '#90CAF9'),
        (6, 2.6, '清理已同步\n队列', '#90CAF9'),
        (9, 2.6, '更新同步\n状态', '#90CAF9'),
    ]
    for x, y, text, color in confirm_items:
        draw_box(ax, x, y, 2.5, 1, text, color, 'black', 9)
    draw_arrow(ax, (4.25, 2.6), (4.75, 2.6))
    draw_arrow(ax, (7.25, 2.6), (7.75, 2.6))

    draw_arrow(ax, (7, 5.3), (7, 4.3))

    # 完成
    draw_box(ax, 7, 0.8, 3, 0.7, '同步完成', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (7, 2.1), (7, 1.15))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_三阶段同步流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_conflict_resolution():
    """图3：冲突检测与解决流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图3  冲突检测与解决流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '检测数据变更', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    draw_box(ax, 6, 8.8, 4.5, 0.9, '比较版本号/时间戳', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.75), (6, 9.25))

    diamond = Polygon([(6, 7.9), (7.5, 7.2), (6, 6.5), (4.5, 7.2)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 7.2, '存在\n冲突?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.35), (6, 7.9))

    # 无冲突
    draw_box(ax, 9.5, 7.2, 2.5, 0.7, '直接合并', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (7.5, 7.2), (8.25, 7.2))
    ax.text(7.9, 7.45, '否', ha='center', va='center', fontsize=8)

    # 有冲突 - 策略选择
    ax.text(6, 5.7, '冲突解决策略', ha='center', va='center', fontsize=10, weight='bold')
    draw_arrow(ax, (6, 6.5), (6, 6))
    ax.text(6.2, 6.2, '是', ha='center', va='center', fontsize=8)

    strategies = [
        (3, 4.3, '服务端优先\n(Server Wins)', '#FFCDD2'),
        (6, 4.3, '客户端优先\n(Client Wins)', '#C8E6C9'),
        (9, 4.3, '手动解决\n(User Decide)', '#FFE0B2'),
    ]
    for x, y, text, color in strategies:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    ax.plot([3, 9], [5.3, 5.3], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 5.3), (x, 4.9))

    # 合并
    draw_box(ax, 6, 2.5, 4, 0.9, '执行合并操作', '#E1BEE7', 'black', 10)
    ax.plot([3, 9.5], [3.7, 3.7], 'k-', lw=1.5)
    draw_arrow(ax, (6, 3.7), (6, 2.95))

    draw_box(ax, 6, 1.3, 4, 0.8, '更新本地数据', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (6, 2.05), (6, 1.7))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_冲突检测与解决流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_smart_sync_trigger():
    """图4：智能同步触发策略图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图4  智能同步触发策略图', ha='center', va='center', fontsize=14, weight='bold')

    # 触发条件
    ax.text(3, 9.3, '触发条件', ha='center', va='center', fontsize=11, weight='bold')

    triggers = [
        (3, 8, '网络恢复\n(离线→在线)', '#E3F2FD'),
        (3, 6.5, '定时触发\n(每15分钟)', '#C8E6C9'),
        (3, 5, '队列阈值\n(>10条待同步)', '#FFE0B2'),
        (3, 3.5, '用户触发\n(手动同步)', '#E1BEE7'),
    ]
    for x, y, text, color in triggers:
        draw_box(ax, x, y, 3, 1, text, color, 'black', 9)

    # 智能调度器
    scheduler_box = FancyBboxPatch((6, 4), 3.5, 5, boxstyle="round,pad=0.02",
                                   facecolor='#F5F5F5', edgecolor='#333', linewidth=2)
    ax.add_patch(scheduler_box)
    ax.text(7.75, 8.5, '智能调度器', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7.75, 7.5, '优先级评估', ha='center', va='center', fontsize=9)
    ax.text(7.75, 6.5, '↓', ha='center', va='center', fontsize=12)
    ax.text(7.75, 5.8, '资源检测', ha='center', va='center', fontsize=9)
    ax.text(7.75, 5, '↓', ha='center', va='center', fontsize=12)
    ax.text(7.75, 4.3, '执行决策', ha='center', va='center', fontsize=9)

    for y in [8, 6.5, 5, 3.5]:
        draw_arrow(ax, (4.5, y), (6, 6.5))

    # 执行策略
    ax.text(11.5, 9.3, '执行策略', ha='center', va='center', fontsize=11, weight='bold')

    executions = [
        (11.5, 7.8, '立即同步\n(WiFi + 充电)', '#C8E6C9'),
        (11.5, 6.3, '延迟同步\n(移动网络)', '#FFE0B2'),
        (11.5, 4.8, '批量同步\n(队列积累)', '#BBDEFB'),
        (11.5, 3.3, '跳过同步\n(资源不足)', '#FFCDD2'),
    ]
    for x, y, text, color in executions:
        draw_box(ax, x, y, 3, 1, text, color, 'black', 9)

    draw_arrow(ax, (9.5, 6.5), (10, 6.5))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_智能同步触发策略图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利11附图...')
    figure1_offline_first_architecture()
    figure2_three_phase_sync()
    figure3_conflict_resolution()
    figure4_smart_sync_trigger()
    print('专利11全部附图生成完成!')
