# -*- coding: utf-8 -*-
"""生成专利06的附图：位置增强财务管理方法"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon, Ellipse
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

# 输出目录
OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_06'
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


def figure1_location_architecture():
    """图1：位置增强财务管理系统架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 12)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 11.5, '图1  位置增强财务管理系统架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 数据采集层
    layer1 = FancyBboxPatch((1, 9.5), 12, 1.5, boxstyle="round,pad=0.02",
                            facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(layer1)
    ax.text(7, 10.6, '数据采集层', ha='center', va='center', fontsize=11, weight='bold')

    collect_items = [
        (3, 9.9, 'GPS定位', '#BBDEFB'),
        (6, 9.9, 'WiFi定位', '#BBDEFB'),
        (9, 9.9, '基站定位', '#BBDEFB'),
        (11.5, 9.9, '传感器数据', '#BBDEFB'),
    ]
    for x, y, text, color in collect_items:
        draw_box(ax, x, y, 2, 0.6, text, color, 'black', 9)

    # 位置处理层
    layer2 = FancyBboxPatch((1, 6.8), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(layer2)
    ax.text(7, 8.5, '位置处理层', ha='center', va='center', fontsize=11, weight='bold')

    process_items = [
        (3, 7.5, '位置聚类\nDBSCAN算法', '#C8E6C9'),
        (6, 7.5, '常驻地点\n识别', '#C8E6C9'),
        (9, 7.5, '消费场景\n分类', '#C8E6C9'),
        (12, 7.5, '地理围栏\n检测', '#C8E6C9'),
    ]
    for x, y, text, color in process_items:
        draw_box(ax, x, y, 2.2, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 9.2), (7, 8.8))

    # 智能分析层
    layer3 = FancyBboxPatch((1, 4), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#FFF3E0', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(layer3)
    ax.text(7, 5.7, '智能分析层', ha='center', va='center', fontsize=11, weight='bold')

    analysis_items = [
        (3, 4.7, '消费模式\n分析', '#FFE0B2'),
        (6, 4.7, '位置相关\n推荐', '#FFE0B2'),
        (9, 4.7, '异常消费\n检测', '#FFE0B2'),
        (12, 4.7, '位置钱龄\n增强', '#FFE0B2'),
    ]
    for x, y, text, color in analysis_items:
        draw_box(ax, x, y, 2.2, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 6.5), (7, 6.1))

    # 应用服务层
    layer4 = FancyBboxPatch((1, 1.2), 12, 2.2, boxstyle="round,pad=0.02",
                            facecolor='#F3E5F5', edgecolor='#7B1FA2', linewidth=2)
    ax.add_patch(layer4)
    ax.text(7, 2.9, '应用服务层', ha='center', va='center', fontsize=11, weight='bold')

    service_items = [
        (3, 1.9, '智能记账\n位置填充', '#E1BEE7'),
        (6, 1.9, '预算预警\n地理触发', '#E1BEE7'),
        (9, 1.9, '消费报告\n位置维度', '#E1BEE7'),
        (12, 1.9, '位置化\n财务建议', '#E1BEE7'),
    ]
    for x, y, text, color in service_items:
        draw_box(ax, x, y, 2.2, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (7, 3.7), (7, 3.3))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_位置增强财务管理系统架构图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_location_clustering():
    """图2：常驻地点识别流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 12.5, '图2  常驻地点识别流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 位置数据收集
    draw_box(ax, 6, 10.3, 4, 0.9, '收集用户位置数据', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.75))

    # 数据预处理
    draw_box(ax, 6, 9.0, 4.5, 0.9, '数据预处理\n(去噪/时间标准化)', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.85), (6, 9.45))

    # DBSCAN聚类
    draw_box(ax, 6, 7.5, 4.5, 1.2, 'DBSCAN密度聚类\n(eps=100m, minPts=5)', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (6, 8.55), (6, 8.1))

    # 聚类结果
    ax.text(6, 6.3, '聚类结果', ha='center', va='center', fontsize=10, weight='bold')

    clusters = [
        (3, 5.3, '聚类1\n(家)', '#FFCDD2'),
        (6, 5.3, '聚类2\n(公司)', '#C8E6C9'),
        (9, 5.3, '聚类3\n(商圈)', '#BBDEFB'),
    ]
    for x, y, text, color in clusters:
        draw_box(ax, x, y, 2, 1.0, text, color, 'black', 9)

    draw_arrow(ax, (6, 6.9), (6, 6.5))
    ax.plot([3, 9], [6.5, 6.5], 'k-', lw=1.5)
    for x in [3, 6, 9]:
        draw_arrow(ax, (x, 6.5), (x, 5.8))

    # 访问频率分析
    draw_box(ax, 6, 4, 4.5, 0.9, '访问频率与时长分析', '#FFF3E0', 'black', 10)
    ax.plot([3, 9], [4.8, 4.8], 'k-', lw=1.5)
    draw_arrow(ax, (6, 4.8), (6, 4.45))

    # 地点分类
    draw_box(ax, 6, 2.8, 4.5, 1.0, '常驻地点类型判定\n(住宅/办公/商业/休闲)', '#E1BEE7', 'black', 10)
    draw_arrow(ax, (6, 3.55), (6, 3.3))

    # 输出
    draw_box(ax, 6, 1.5, 4, 0.8, '输出常驻地点列表', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (6, 2.3), (6, 1.9))

    # 结束
    circle_end = Circle((6, 0.6), 0.3, facecolor='#333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(6, 0.6, '结束', ha='center', va='center', fontsize=8, color='white')
    draw_arrow(ax, (6, 1.1), (6, 0.9))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_常驻地点识别流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_scene_recognition():
    """图3：消费场景识别示意图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图3  消费场景识别示意图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入特征
    ax.text(3, 9.5, '输入特征', ha='center', va='center', fontsize=11, weight='bold')

    features = [
        (3, 8.5, '位置坐标', '#E3F2FD'),
        (3, 7.5, '时间信息', '#E3F2FD'),
        (3, 6.5, '停留时长', '#E3F2FD'),
        (3, 5.5, 'POI信息', '#E3F2FD'),
    ]
    for x, y, text, color in features:
        draw_box(ax, x, y, 2.2, 0.7, text, color, 'black', 9)

    # 场景分类器
    classifier = FancyBboxPatch((5.5, 5), 3, 4.5, boxstyle="round,pad=0.02",
                                facecolor='#C5CAE9', edgecolor='#3F51B5', linewidth=2)
    ax.add_patch(classifier)
    ax.text(7, 8.8, '场景分类器', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 8.2, '特征融合', ha='center', va='center', fontsize=9)
    ax.text(7, 7.5, '↓', ha='center', va='center', fontsize=12)
    ax.text(7, 7.0, '机器学习', ha='center', va='center', fontsize=9)
    ax.text(7, 6.3, '↓', ha='center', va='center', fontsize=12)
    ax.text(7, 5.8, '规则修正', ha='center', va='center', fontsize=9)

    # 连接
    for y in [8.5, 7.5, 6.5, 5.5]:
        draw_arrow(ax, (4.1, y), (5.5, 7.2))

    # 输出场景
    ax.text(11, 9.5, '消费场景', ha='center', va='center', fontsize=11, weight='bold')

    scenes = [
        (11, 8.5, '日常餐饮', '#FFCDD2', '工作日午餐/晚餐'),
        (11, 7.5, '商圈购物', '#C8E6C9', '周末商场消费'),
        (11, 6.5, '交通出行', '#BBDEFB', '通勤/差旅'),
        (11, 5.5, '休闲娱乐', '#FFE0B2', '电影/健身/KTV'),
    ]
    for x, y, text, color, desc in scenes:
        draw_box(ax, x, y, 2.2, 0.7, text, color, 'black', 9)
        ax.text(x + 1.5, y, desc, ha='left', va='center', fontsize=7, color='#666')

    draw_arrow(ax, (8.5, 7.2), (9.9, 7.2))

    # 场景应用
    ax.text(7, 3.5, '场景应用', ha='center', va='center', fontsize=11, weight='bold')

    applications = [
        (3, 2.2, '智能分类\n自动匹配类别', '#E8F5E9'),
        (7, 2.2, '预算关联\n场景预算管理', '#E8F5E9'),
        (11, 2.2, '消费预测\n场景消费提醒', '#E8F5E9'),
    ]
    for x, y, text, color in applications:
        draw_box(ax, x, y, 3, 1.2, text, color, 'black', 9)

    ax.plot([3, 11], [4, 4], 'k-', lw=1.5)
    for x in [3, 7, 11]:
        draw_arrow(ax, (x, 4), (x, 2.8))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_消费场景识别示意图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_geofence_alert():
    """图4：地理围栏预警流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(6, 12.5, '图4  地理围栏预警流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 开始
    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    # 实时位置获取
    draw_box(ax, 6, 10.3, 4, 0.9, '实时位置监听', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.75))

    # 围栏检测
    draw_box(ax, 6, 9.0, 4, 0.9, '地理围栏碰撞检测', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.85), (6, 9.45))

    # 判断
    diamond = Polygon([(6, 8.1), (7.5, 7.4), (6, 6.7), (4.5, 7.4)],
                      facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond)
    ax.text(6, 7.4, '进入\n围栏?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 8.55), (6, 8.1))

    # 否 - 继续监听
    draw_box(ax, 9.5, 7.4, 2.5, 0.7, '继续监听', '#E0E0E0', 'black', 9)
    draw_arrow(ax, (7.5, 7.4), (8.25, 7.4))
    ax.text(7.9, 7.65, '否', ha='center', va='center', fontsize=8)

    # 循环回去
    ax.annotate('', xy=(6, 10.75), xytext=(9.5, 7.75),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1,
                                connectionstyle='arc3,rad=-0.3'))

    # 是 - 获取围栏配置
    draw_box(ax, 6, 6, 4, 0.9, '获取围栏预算配置', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (6, 6.7), (6, 6.45))
    ax.text(6.2, 6.5, '是', ha='center', va='center', fontsize=8)

    # 查询预算状态
    draw_box(ax, 6, 4.8, 4, 0.9, '查询关联预算余额', '#C8E6C9', 'black', 10)
    draw_arrow(ax, (6, 5.55), (6, 5.25))

    # 判断预算
    diamond2 = Polygon([(6, 4), (7.3, 3.4), (6, 2.8), (4.7, 3.4)],
                       facecolor='#FFF3E0', edgecolor='black', linewidth=1.5)
    ax.add_patch(diamond2)
    ax.text(6, 3.4, '预算\n充足?', ha='center', va='center', fontsize=9)
    draw_arrow(ax, (6, 4.35), (6, 4))

    # 否 - 发送预警
    draw_box(ax, 9.5, 3.4, 2.5, 0.7, '发送预警通知', '#FFCDD2', 'black', 9)
    draw_arrow(ax, (7.3, 3.4), (8.25, 3.4))
    ax.text(7.7, 3.65, '否', ha='center', va='center', fontsize=8)

    # 是 - 显示可用
    draw_box(ax, 2.5, 3.4, 2.5, 0.7, '显示可用额度', '#C8E6C9', 'black', 9)
    draw_arrow(ax, (4.7, 3.4), (3.75, 3.4))
    ax.text(4.3, 3.65, '是', ha='center', va='center', fontsize=8)

    # 记录
    draw_box(ax, 6, 1.8, 4, 0.9, '记录进入围栏事件', '#E8F5E9', 'black', 10)
    ax.plot([2.5, 9.5], [3.05, 3.05], 'k-', lw=1.5)
    draw_arrow(ax, (6, 3.05), (6, 2.25))

    # 结束
    circle_end = Circle((6, 0.8), 0.3, facecolor='#333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(6, 0.8, '结束', ha='center', va='center', fontsize=8, color='white')
    draw_arrow(ax, (6, 1.35), (6, 1.1))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_地理围栏预警流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


def figure5_location_money_age():
    """图5：位置增强钱龄计算模型图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    # 标题
    ax.text(7, 10.5, '图5  位置增强钱龄计算模型图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入数据
    ax.text(3, 9.5, '输入数据', ha='center', va='center', fontsize=11, weight='bold')

    inputs = [
        (3, 8.5, '交易记录\n(金额/时间)', '#E3F2FD'),
        (3, 7, '位置信息\n(经纬度)', '#E3F2FD'),
        (3, 5.5, '场景标签\n(消费场景)', '#E3F2FD'),
    ]
    for x, y, text, color in inputs:
        draw_box(ax, x, y, 2.5, 1.0, text, color, 'black', 9)

    # 基础钱龄计算
    draw_box(ax, 7, 8, 3.5, 1.2, '基础FIFO\n钱龄计算', '#C8E6C9', 'black', 10)

    # 位置增强模块
    draw_box(ax, 7, 6, 3.5, 1.5, '位置增强模块\n- 场景权重调整\n- 高频地点加成', '#FFE0B2', 'black', 9)

    # 连接
    draw_arrow(ax, (4.25, 8.5), (5.25, 8))
    draw_arrow(ax, (4.25, 7), (5.25, 6))
    draw_arrow(ax, (4.25, 5.5), (5.25, 5.8))

    draw_arrow(ax, (7, 7.4), (7, 6.75))

    # 增强后钱龄
    draw_box(ax, 7, 4, 4, 1.2, '增强钱龄输出\n= 基础钱龄 × 场景系数', '#E1BEE7', 'black', 10)
    draw_arrow(ax, (7, 5.25), (7, 4.6))

    # 应用场景
    ax.text(11, 9.5, '应用场景', ha='center', va='center', fontsize=11, weight='bold')

    applications = [
        (11, 8.3, '地点钱龄分析\n各场所消费年龄', '#E8F5E9'),
        (11, 6.5, '位置健康评分\n场景财务健康度', '#E8F5E9'),
        (11, 4.7, '消费建议\n场景优化建议', '#E8F5E9'),
    ]
    for x, y, text, color in applications:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (8.75, 6), (9.6, 6.5))
    draw_arrow(ax, (9, 4), (9.6, 4.7))

    # 场景系数示例
    ax.text(7, 2.5, '场景系数示例', ha='center', va='center', fontsize=10, weight='bold')

    examples = [
        (3.5, 1.5, '日常通勤: 1.0', '#E0E0E0'),
        (7, 1.5, '商圈购物: 0.8', '#FFCDD2'),
        (10.5, 1.5, '高频餐饮: 1.2', '#C8E6C9'),
    ]
    for x, y, text, color in examples:
        draw_box(ax, x, y, 3, 0.7, text, color, 'black', 9)

    draw_arrow(ax, (7, 3.4), (7, 2.8))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图5_位置增强钱龄计算模型图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图5 已生成')


if __name__ == '__main__':
    print('开始生成专利06附图...')
    print(f'输出目录: {OUTPUT_DIR}')
    figure1_location_architecture()
    figure2_location_clustering()
    figure3_scene_recognition()
    figure4_geofence_alert()
    figure5_location_money_age()
    print('专利06全部附图生成完成!')
