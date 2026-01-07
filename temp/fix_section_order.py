# -*- coding: utf-8 -*-
"""
修复15.12章节编号顺序问题：
- 15.12.3.3 应该在 15.12.4 之前，但现在跑到 15.12.4.2 之后了
- 需要将 15.12.3.3 移到正确位置
"""

def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 定义标记
    section_3_3_start = '##### 15.12.3.3 语音配置示例库（扩展版）'
    section_4_3_start = '##### 15.12.4.3 语音导航与操作示例库（扩展版）'
    section_4_start = '#### 15.12.4 智能语音导航模块'

    # 找到各个位置
    idx_3_3 = content.find(section_3_3_start)
    idx_4_3 = content.find(section_4_3_start)
    idx_4 = content.find(section_4_start)

    print(f"15.12.3.3 位置: {idx_3_3}")
    print(f"15.12.4 位置: {idx_4}")
    print(f"15.12.4.3 位置: {idx_4_3}")

    if idx_3_3 == -1 or idx_4_3 == -1 or idx_4 == -1:
        print("Error: Cannot find all markers")
        return

    # 检查是否需要修复（15.12.3.3 应该在 15.12.4 之前）
    if idx_3_3 < idx_4:
        print("Order is already correct, no fix needed")
        return

    print(f"15.12.3.3 is after 15.12.4, need to fix...")

    # 提取 15.12.3.3 的内容（从开始到 15.12.4.3 之前）
    section_3_3_content = content[idx_3_3:idx_4_3].rstrip()

    # 删除原位置的 15.12.3.3 内容
    content_without_3_3 = content[:idx_3_3].rstrip() + '\n\n' + content[idx_4_3:]

    # 在 15.12.4 之前插入 15.12.3.3
    # 重新找 15.12.4 的位置（因为内容变了）
    new_idx_4 = content_without_3_3.find(section_4_start)

    new_content = (
        content_without_3_3[:new_idx_4].rstrip() +
        '\n\n' +
        section_3_3_content +
        '\n\n' +
        content_without_3_3[new_idx_4:]
    )

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully fixed section order!')
    print(f'Old size: {len(content)} characters')
    print(f'New size: {len(new_content)} characters')

    # 验证修复
    new_idx_3_3 = new_content.find(section_3_3_start)
    new_idx_4 = new_content.find(section_4_start)
    new_idx_4_3 = new_content.find(section_4_3_start)

    print(f'\n--- Verification ---')
    print(f'New 15.12.3.3 position: {new_idx_3_3}')
    print(f'New 15.12.4 position: {new_idx_4}')
    print(f'New 15.12.4.3 position: {new_idx_4_3}')

    if new_idx_3_3 < new_idx_4 < new_idx_4_3:
        print('Order is now correct!')
    else:
        print('ERROR: Order is still wrong!')

if __name__ == '__main__':
    main()
