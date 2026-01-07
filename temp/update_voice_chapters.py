# -*- coding: utf-8 -*-
"""
更新语音配置和语音导航章节，使用完整的1.x版本配置项和页面覆盖
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取更新后的内容
    with open('d:/code/ai-bookkeeping/temp/updated_voice_config_nav.md', 'r', encoding='utf-8') as f:
        new_content = f.read()

    # 查找替换范围
    # 开始标记：##### 15.12.3.1 可配置项全景图
    # 结束标记：#### 15.12.5 智能语音查询模块

    start_marker = '##### 15.12.3.1 可配置项全景图'
    end_marker = '#### 15.12.5 智能语音查询模块'

    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker)

    if start_idx == -1:
        print(f"Error: Cannot find start marker '{start_marker}'")
        return

    if end_idx == -1:
        print(f"Error: Cannot find end marker '{end_marker}'")
        return

    print(f"Found start marker at position: {start_idx}")
    print(f"Found end marker at position: {end_idx}")
    print(f"Content to replace: {end_idx - start_idx} characters")

    # 构建新内容
    # 保留开始之前的内容 + 新内容 + 保留结束标记及之后的内容
    before = content[:start_idx]
    after = content[end_idx:]  # 包含 end_marker 及之后的内容

    new_doc = before + new_content.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_doc)

    print('Successfully updated voice configuration and navigation chapters!')
    print(f'Old document size: {len(content)} characters')
    print(f'New document size: {len(new_doc)} characters')
    print(f'Size change: {len(new_doc) - len(content):+d} characters')

    # 验证新内容
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        verify_content = f.read()

    # 检查关键内容是否存在
    checks = [
        ('可配置项全景图（完整版）', '完整版配置项全景图'),
        ('200+项', '200+配置项数量'),
        ('48个页面全覆盖', '48个页面覆盖'),
        ('直接操作映射（60+项）', '60+直接操作'),
        ('十三、网络与性能配置', '第13类配置'),
        ('语音导航与操作示例库（扩展版）', '扩展版示例库'),
    ]

    print('\n--- Verification ---')
    all_passed = True
    for keyword, desc in checks:
        if keyword in verify_content:
            print(f'✓ {desc}: Found')
        else:
            print(f'✗ {desc}: NOT Found - "{keyword}"')
            all_passed = False

    if all_passed:
        print('\n✓ All verifications passed!')
    else:
        print('\n✗ Some verifications failed!')

if __name__ == '__main__':
    main()
