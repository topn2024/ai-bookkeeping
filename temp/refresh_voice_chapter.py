# -*- coding: utf-8 -*-
"""
刷新15.12智能语音交互系统章节：
1. 在15.12.0.3之后插入15.12.0.4页面分析表格
2. 确保章节结构完整
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取页面分析表格
    with open('d:/code/ai-bookkeeping/temp/prototype_pages_analysis.md', 'r', encoding='utf-8') as f:
        pages_analysis = f.read()

    # 查找插入点：在 "#### 15.12.1 意图识别引擎" 之前
    insert_marker = '#### 15.12.1 意图识别引擎'

    insert_idx = content.find(insert_marker)
    if insert_idx == -1:
        print(f"Error: Cannot find marker '{insert_marker}'")
        return

    print(f"Found insert marker at position: {insert_idx}")

    # 检查是否已经存在15.12.0.4
    if '15.12.0.4' in content:
        print("15.12.0.4 already exists, skipping insertion")
    else:
        # 构建新内容
        before = content[:insert_idx].rstrip()
        after = content[insert_idx:]

        content = before + '\n\n' + pages_analysis.strip() + '\n\n' + after
        print("Inserted 15.12.0.4 pages analysis")

    # 检查并修复章节结构
    # 确保15.12.4章节标题存在
    if '#### 15.12.4 智能语音导航模块' not in content:
        # 在15.12.4.1之前添加章节标题
        marker_4_1 = '##### 15.12.4.1 导航与操作能力全景图'
        idx_4_1 = content.find(marker_4_1)
        if idx_4_1 != -1:
            # 检查前面是否有正确的章节标题
            before_4_1 = content[max(0, idx_4_1-200):idx_4_1]
            if '#### 15.12.4' not in before_4_1:
                # 需要插入章节标题
                nav_intro = '''#### 15.12.4 智能语音导航模块

语音导航模块支持三层能力：页面导航、功能入口、直接操作。基于2.0版本110个原型页面分析，47个页面（43%）高度适配语音导航。

'''
                content = content[:idx_4_1] + nav_intro + content[idx_4_1:]
                print("Added 15.12.4 section header")

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print('Successfully refreshed voice interaction chapter!')
    print(f'New document size: {len(content)} characters')

    # 验证章节结构
    sections = [
        '### 15.12 智能语音交互系统',
        '#### 15.12.0 系统架构全景图',
        '#### 15.12.0.1 语音配置适配性分析',
        '#### 15.12.0.2 语音操作适配性分析',
        '#### 15.12.0.3 实现优先级建议',
        '#### 15.12.0.4 原型页面清单与语音导航适配性分析',
        '#### 15.12.1 意图识别引擎',
        '#### 15.12.2 语音记账模块',
        '#### 15.12.3 智能语音配置模块',
        '#### 15.12.4 智能语音导航模块',
        '#### 15.12.5 智能语音查询模块',
        '#### 15.12.6 语音交互会话管理',
        '#### 15.12.7 语音交互界面设计',
        '#### 15.12.8 与其他系统的集成',
        '#### 15.12.9 目标达成检测',
        '#### 15.12.10 智能语音反馈与客服系统',
    ]

    print('\n--- Section Verification ---')
    for section in sections:
        if section in content:
            print(f'OK: {section}')
        else:
            print(f'MISSING: {section}')

if __name__ == '__main__':
    main()
