# -*- coding: utf-8 -*-
"""生成专利10的附图：智能账单解析导入方法"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
import os

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = 'D:/code/ai-bookkeeping/docs/patents/figures/patent_10'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_box(ax, x, y, width, height, text, facecolor='white', edgecolor='black', fontsize=10):
    box = FancyBboxPatch((x - width/2, y - height/2), width, height,
                         boxstyle="round,pad=0.02,rounding_size=0.1",
                         facecolor=facecolor, edgecolor=edgecolor, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)

def draw_arrow(ax, start, end, color='black'):
    ax.annotate('', xy=end, xytext=start, arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def figure1_format_detection():
    """图1：智能格式检测流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 13))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 13)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(6, 12.5, '图1  智能格式检测流程图', ha='center', va='center', fontsize=14, weight='bold')

    circle = Circle((6, 11.5), 0.35, facecolor='#333', edgecolor='black')
    ax.add_patch(circle)
    ax.text(6, 11.5, '开始', ha='center', va='center', fontsize=9, color='white', weight='bold')

    draw_box(ax, 6, 10.2, 4, 0.9, '上传账单文件', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (6, 11.15), (6, 10.65))

    draw_box(ax, 6, 8.8, 4, 0.9, '文件类型识别\n(扩展名/MIME)', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (6, 9.75), (6, 9.25))

    # 格式分支
    ax.text(6, 7.5, '账单格式判定', ha='center', va='center', fontsize=10, weight='bold')

    formats = [
        (2.5, 6.2, 'CSV格式\n(通用导出)', '#FFCDD2'),
        (5, 6.2, 'Excel格式\n(银行账单)', '#C8E6C9'),
        (7.5, 6.2, 'PDF格式\n(电子账单)', '#BBDEFB'),
        (10, 6.2, '图片格式\n(截图/照片)', '#FFE0B2'),
    ]
    for x, y, text, color in formats:
        draw_box(ax, x, y, 2.3, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (6, 8.35), (6, 7.8))
    ax.plot([2.5, 10], [7.8, 7.8], 'k-', lw=1.5)
    for x in [2.5, 5, 7.5, 10]:
        draw_arrow(ax, (x, 7.8), (x, 6.8))

    draw_box(ax, 6, 4.3, 4.5, 1, '特征模式匹配\n(微信/支付宝/银行)', '#E1BEE7', 'black', 10)
    ax.plot([2.5, 10], [5.6, 5.6], 'k-', lw=1.5)
    draw_arrow(ax, (6, 5.6), (6, 4.8))

    draw_box(ax, 6, 2.8, 4.5, 1, '返回格式类型\n+ 推荐解析器', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (6, 3.8), (6, 3.3))

    circle_end = Circle((6, 1.5), 0.3, facecolor='#333', edgecolor='black')
    ax.add_patch(circle_end)
    ax.text(6, 1.5, '结束', ha='center', va='center', fontsize=8, color='white')
    draw_arrow(ax, (6, 2.3), (6, 1.8))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图1_智能格式检测流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图1 已生成')


def figure2_plugin_parser():
    """图2：插件化解析器架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图2  插件化解析器架构图', ha='center', va='center', fontsize=14, weight='bold')

    # 解析器接口
    interface_box = FancyBboxPatch((4.5, 8), 5, 1.5, boxstyle="round,pad=0.02",
                                   facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(interface_box)
    ax.text(7, 9.1, '解析器接口 (IParser)', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 8.4, 'parse() | validate() | transform()', ha='center', va='center', fontsize=9)

    # 具体解析器
    ax.text(7, 6.8, '具体解析器实现', ha='center', va='center', fontsize=10, weight='bold')

    parsers = [
        (2, 5.3, '微信解析器\nWeChatParser', '#C8E6C9'),
        (5, 5.3, '支付宝解析器\nAlipayParser', '#BBDEFB'),
        (8, 5.3, '银行解析器\nBankParser', '#FFE0B2'),
        (11, 5.3, '通用解析器\nGenericParser', '#E1BEE7'),
    ]
    for x, y, text, color in parsers:
        draw_box(ax, x, y, 2.6, 1.4, text, color, 'black', 9)

    # 继承箭头
    for x in [2, 5, 8, 11]:
        ax.annotate('', xy=(x, 6), xytext=(x, 8),
                    arrowprops=dict(arrowstyle='-|>', color='black', lw=1.5))

    # 解析器工厂
    factory_box = FancyBboxPatch((4.5, 2.5), 5, 1.5, boxstyle="round,pad=0.02",
                                 facecolor='#FFF3E0', edgecolor='#EF6C00', linewidth=2)
    ax.add_patch(factory_box)
    ax.text(7, 3.6, '解析器工厂 (ParserFactory)', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(7, 2.9, 'create(type) → IParser', ha='center', va='center', fontsize=9)

    # 工厂到解析器
    ax.plot([2, 11], [4.6, 4.6], 'k--', lw=1, alpha=0.5)
    draw_arrow(ax, (7, 4), (7, 4.6))

    # 输出
    draw_box(ax, 7, 1, 5, 0.8, '标准化交易数据输出', '#E8F5E9', 'black', 10)
    draw_arrow(ax, (7, 2.5), (7, 1.4))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图2_插件化解析器架构图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图2 已生成')


def figure3_ai_classification():
    """图3：AI辅助分类流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图3  AI辅助分类流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 输入
    draw_box(ax, 3, 9, 3, 1, '解析后的\n交易数据', '#E3F2FD', 'black', 10)

    # 特征提取
    draw_box(ax, 7, 9, 3, 1, '特征提取\n(商户/金额/时间)', '#BBDEFB', 'black', 10)
    draw_arrow(ax, (4.5, 9), (5.5, 9))

    # AI分类模型
    model_box = FancyBboxPatch((9, 7.5), 4, 3.5, boxstyle="round,pad=0.02",
                               facecolor='#E1BEE7', edgecolor='#7B1FA2', linewidth=2)
    ax.add_patch(model_box)
    ax.text(11, 10.5, 'AI分类模型', ha='center', va='center', fontsize=11, weight='bold')
    ax.text(11, 9.5, '规则匹配层', ha='center', va='center', fontsize=9)
    ax.text(11, 8.8, '↓', ha='center', va='center', fontsize=10)
    ax.text(11, 8.3, '机器学习层', ha='center', va='center', fontsize=9)
    ax.text(11, 7.6, '↓', ha='center', va='center', fontsize=10)
    ax.text(11, 7.1, '用户历史层', ha='center', va='center', fontsize=9)

    draw_arrow(ax, (8.5, 9), (9, 9))

    # 分类结果
    ax.text(7, 5.5, '分类结果输出', ha='center', va='center', fontsize=10, weight='bold')

    results = [
        (3.5, 4.2, '高置信度\n直接应用', '#C8E6C9'),
        (7, 4.2, '中置信度\n人工确认', '#FFE0B2'),
        (10.5, 4.2, '低置信度\n手动选择', '#FFCDD2'),
    ]
    for x, y, text, color in results:
        draw_box(ax, x, y, 2.8, 1.2, text, color, 'black', 9)

    draw_arrow(ax, (11, 7.5), (11, 6))
    ax.plot([3.5, 10.5], [6, 6], 'k-', lw=1.5)
    for x in [3.5, 7, 10.5]:
        draw_arrow(ax, (x, 6), (x, 4.8))

    # 反馈学习
    draw_box(ax, 7, 2, 5, 1, '用户反馈 → 模型更新\n持续优��分类准确率', '#E8F5E9', 'black', 10)
    ax.plot([3.5, 10.5], [3.6, 3.6], 'k-', lw=1.5)
    draw_arrow(ax, (7, 3.6), (7, 2.5))

    # 反馈循环
    ax.annotate('', xy=(11.5, 10.5), xytext=(11.5, 2),
                arrowprops=dict(arrowstyle='->', color='#666', lw=1,
                                connectionstyle='arc3,rad=-0.3'))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图3_AI辅助分类流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图3 已生成')


def figure4_chunk_processing():
    """图4：大文件分片处理流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(14, 11))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 11)
    ax.set_aspect('equal')
    ax.axis('off')

    ax.text(7, 10.5, '图4  大文件分片处理流程图', ha='center', va='center', fontsize=14, weight='bold')

    # 大文件
    draw_box(ax, 2.5, 8.5, 3, 1.2, '大文件输入\n(>10MB)', '#E0E0E0', 'black', 10)

    # 分片
    draw_box(ax, 6.5, 8.5, 3, 1.2, '智能分片\n按行数/大小', '#E3F2FD', 'black', 10)
    draw_arrow(ax, (4, 8.5), (5, 8.5))

    # 分片队列
    ax.text(11, 9, '分片队列', ha='center', va='center', fontsize=10, weight='bold')
    chunks = [
        (10, 7.8, '分片1', '#FFCDD2'),
        (11, 7.8, '分片2', '#C8E6C9'),
        (12, 7.8, '分片3', '#BBDEFB'),
    ]
    for x, y, text, color in chunks:
        draw_box(ax, x, y, 1.5, 0.7, text, color, 'black', 8)
    ax.text(12.5, 7.8, '...', ha='left', va='center', fontsize=12)

    draw_arrow(ax, (8, 8.5), (9.25, 8.2))

    # 并行处理
    process_box = FancyBboxPatch((3, 4.5), 8, 2.5, boxstyle="round,pad=0.02",
                                 facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=2)
    ax.add_patch(process_box)
    ax.text(7, 6.5, '并行解析处理', ha='center', va='center', fontsize=11, weight='bold')

    workers = ['Worker1', 'Worker2', 'Worker3', 'WorkerN']
    for i, w in enumerate(workers):
        draw_box(ax, 4 + i*2, 5.2, 1.5, 0.7, w, '#A5D6A7', 'black', 8)

    draw_arrow(ax, (11, 7.45), (7, 7))

    # 结果合并
    draw_box(ax, 7, 2.8, 4, 1, '结果合并\n去重 | 排序 | 校验', '#FFF3E0', 'black', 10)
    draw_arrow(ax, (7, 4.5), (7, 3.3))

    # 进度反馈
    progress_box = FancyBboxPatch((2, 1), 10, 1.2, boxstyle="round,pad=0.02",
                                  facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=1.5)
    ax.add_patch(progress_box)
    ax.text(7, 1.6, '实时进度反馈: [████████░░] 80% | 已处理: 8000/10000条',
           ha='center', va='center', fontsize=9)
    draw_arrow(ax, (7, 2.3), (7, 2.2))

    plt.tight_layout()
    plt.savefig(f'{OUTPUT_DIR}/图4_大文件分片处理流程图.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    print('图4 已生成')


if __name__ == '__main__':
    print('开始生成专利10附图...')
    figure1_format_detection()
    figure2_plugin_parser()
    figure3_ai_classification()
    figure4_chunk_processing()
    print('专利10全部附图生成完成!')
