# -*- coding: utf-8 -*-
"""
重构第20章用户体验设计
将22个小节整合为10个左右
"""

import re

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def extract_section(content, section_pattern, next_section_pattern=None):
    """提取一个章节的内容"""
    match = re.search(section_pattern, content)
    if not match:
        return None, None
    start = match.start()

    if next_section_pattern:
        next_match = re.search(next_section_pattern, content[match.end():])
        if next_match:
            end = match.end() + next_match.start()
        else:
            end = len(content)
    else:
        end = len(content)

    return start, content[start:end]

def main():
    content = read_file('docs/design/app_v2_design.md')

    # 找到第20章和第21章的位置
    ch20_match = re.search(r'^## 20\. 用户体验设计', content, re.MULTILINE)
    ch21_match = re.search(r'^## 21\. 国际化与本地化', content, re.MULTILINE)

    if not ch20_match or not ch21_match:
        print("找不到章节边界")
        return

    before_ch20 = content[:ch20_match.start()]
    after_ch20 = content[ch21_match.start():]
    old_ch20 = content[ch20_match.start():ch21_match.start()]

    # 提取各个小节
    sections = {}
    section_patterns = [
        (r'### 20\.0 设计原则回顾', '20.0'),
        (r'### 20\.1 页面设计参考', '20.1'),
        (r'### 20\.2 视觉设计规范', '20.2'),
        (r'### 20\.3 主题系统设计', '20.3'),
        (r'### 20\.4 页面布局规范', '20.4'),
        (r'### 20\.5 手势交互设计', '20.5'),
        (r'### 20\.6 与其他系统集成', '20.6'),
        (r'### 20\.7 微交互与动效设计系统', '20.7'),
        (r'### 20\.8 离线体验设计', '20.8'),
        (r'### 20\.9 错误处理的用户体验设计', '20.9'),
        (r'### 20\.10 个性化定制设计', '20.10'),
        (r'### 20\.11 分享体验设计', '20.11'),
        (r'### 20\.12 极端边界场景设计', '20.12'),
        (r'### 20\.13 跨设备一致性体验设计', '20.13'),
        (r'### 20\.14 深度个性化闭环设计', '20.14'),
        (r'### 20\.15 峰值体验与长期里程碑设计', '20.15'),
        (r'### 20\.16 真实记账流程与耗时设计', '20.16'),
        (r'### 20\.17 渐进式准确率提升路径', '20.17'),
        (r'### 20\.18 零配置快速开始设计', '20.18'),
        (r'### 20\.19 可行建议型伙伴文案设计', '20.19'),
        (r'### 20\.20 简化版家庭账本模式', '20.20'),
        (r'### 20\.21 竞品借鉴与体验优化设计', '20.21'),
    ]

    # 提取每个小节的内容
    for i, (pattern, key) in enumerate(section_patterns):
        match = re.search(pattern, old_ch20)
        if match:
            start = match.start()
            # 找下一个小节的开始
            if i < len(section_patterns) - 1:
                next_pattern = section_patterns[i + 1][0]
                next_match = re.search(next_pattern, old_ch20)
                if next_match:
                    end = next_match.start()
                else:
                    end = len(old_ch20)
            else:
                end = len(old_ch20)
            sections[key] = old_ch20[start:end].strip()
            print(f"提取 {key}: {len(sections[key])} 字符")

    # 构建新的第20章
    new_ch20 = """<a id="20-用户体验设计"></a>

## 20. 用户体验设计

"""

    # 20.0 保持不变，但更新导航
    if '20.0' in sections:
        # 更新20.0中的内容导航
        section_0 = sections['20.0']
        # 替换旧的导航表格
        nav_start = section_0.find('#### 20.0.4 本章内容导航')
        if nav_start != -1:
            nav_end = section_0.find('---', nav_start)
            if nav_end == -1:
                nav_end = len(section_0)
            section_0 = section_0[:nav_start] + """#### 20.0.4 本章内容导航

```
+----------------------------------------------------------------------------+
|                         第20章 用户体验设计 - 内容导航                        |
+----------------------------------------------------------------------------+
|                                                                            |
|  20.1 页面设计参考     - 指向前端原型文档                                    |
|  20.2 视觉与交互规范   - 色彩、字体、主题、布局、手势、动效                    |
|  20.3 系统集成设计     - 语音UI、AI展示、家庭UI、新手引导、成就系统            |
|  20.4 体验保障设计     - 离线体验、错误处理、极端边界、跨设备一致性            |
|  20.5 个性化体验设计   - 个性定制、深度个性化闭环                             |
|  20.6 社交与成就设计   - 分享体验、峰值体验、里程碑                           |
|  20.7 记账体验优化     - 记账流程、准确率、零配置、文案、家庭账本              |
|  20.8 竞品借鉴设计     - Spendee最佳实践                                     |
|                                                                            |
+----------------------------------------------------------------------------+
```

""" + section_0[nav_end:]

        # 更新设计原则表格中的章节引用
        section_0 = re.sub(r'20\.8, 20\.22', '20.7', section_0)
        section_0 = re.sub(r'20\.23', '20.7', section_0)
        section_0 = re.sub(r'20\.19', '20.6', section_0)
        section_0 = re.sub(r'20\.7, 20\.19', '20.2, 20.6', section_0)
        section_0 = re.sub(r'20\.17', '20.4', section_0)
        section_0 = re.sub(r'20\.21', '20.7', section_0)
        section_0 = re.sub(r'20\.22', '20.7', section_0)
        section_0 = re.sub(r'20\.16', '20.4', section_0)
        section_0 = re.sub(r'20\.18', '20.5', section_0)

        new_ch20 += section_0 + "\n\n---\n\n"

    # 20.1 页面设计参考 - 保持简洁
    if '20.1' in sections:
        new_ch20 += sections['20.1'] + "\n\n---\n\n"

    # 20.2 视觉与交互规范 - 合并20.2视觉+20.3主题+20.4布局+20.5手势+20.7动效
    new_ch20 += """### 20.2 视觉与交互规范

本节整合视觉设计规范、主题系统、页面布局、手势交互和微交互动效的设计规范。

"""

    # 添加20.2的内容（移除标题）
    if '20.2' in sections:
        content_20_2 = re.sub(r'^### 20\.2 视觉设计规范\s*\n', '', sections['20.2'])
        # 将#### 20.2.x 改为 #### 20.2.1.x (色彩系统相关)
        content_20_2 = re.sub(r'#### 20\.2\.', '#### 20.2.1.', content_20_2)
        new_ch20 += "#### 20.2.1 色彩与字体规范\n\n" + content_20_2.strip() + "\n\n"

    # 添加20.3主题系统的内容
    if '20.3' in sections:
        content_20_3 = re.sub(r'^### 20\.3 主题系统设计\s*\n', '', sections['20.3'])
        content_20_3 = re.sub(r'#### 20\.3\.', '#### 20.2.2.', content_20_3)
        new_ch20 += "#### 20.2.2 主题系统\n\n" + content_20_3.strip() + "\n\n"

    # 添加20.4页面布局的内容
    if '20.4' in sections:
        content_20_4 = re.sub(r'^### 20\.4 页面布局规范\s*\n', '', sections['20.4'])
        content_20_4 = re.sub(r'#### 20\.4\.', '#### 20.2.3.', content_20_4)
        new_ch20 += "#### 20.2.3 页面布局规范\n\n" + content_20_4.strip() + "\n\n"

    # 添加20.5手势交互的内容
    if '20.5' in sections:
        content_20_5 = re.sub(r'^### 20\.5 手势交互设计\s*\n', '', sections['20.5'])
        content_20_5 = re.sub(r'#### 20\.5\.', '#### 20.2.4.', content_20_5)
        new_ch20 += "#### 20.2.4 手势交互规范\n\n" + content_20_5.strip() + "\n\n"

    # 添加20.7微交互动效的内容
    if '20.7' in sections:
        content_20_7 = re.sub(r'^### 20\.7 微交互与动效设计系统\s*\n', '', sections['20.7'])
        content_20_7 = re.sub(r'#### 20\.7\.', '#### 20.2.5.', content_20_7)
        new_ch20 += "#### 20.2.5 微交互与动效\n\n" + content_20_7.strip() + "\n\n"

    new_ch20 += "---\n\n"

    # 20.3 系统集成设计 - 来自原20.6
    if '20.6' in sections:
        content_20_6 = sections['20.6'].replace('### 20.6', '### 20.3')
        content_20_6 = re.sub(r'#### 20\.6\.', '#### 20.3.', content_20_6)
        new_ch20 += content_20_6 + "\n\n---\n\n"

    # 20.4 体验保障设计 - 合并20.8离线+20.9错误+20.12极端+20.13跨设备
    new_ch20 += """### 20.4 体验保障设计

本节整合离线体验、错误处理、极端边界场景和跨设备一致性的设计规范，确保用户在各种场景下都能获得可靠的体验。

"""

    if '20.8' in sections:
        content_20_8 = re.sub(r'^### 20\.8 离线体验设计\s*\n', '', sections['20.8'])
        content_20_8 = re.sub(r'#### 20\.8\.', '#### 20.4.1.', content_20_8)
        new_ch20 += "#### 20.4.1 离线体验设计\n\n" + content_20_8.strip() + "\n\n"

    if '20.9' in sections:
        content_20_9 = re.sub(r'^### 20\.9 错误处理的用户体验设计\s*\n', '', sections['20.9'])
        content_20_9 = re.sub(r'#### 20\.9\.', '#### 20.4.2.', content_20_9)
        new_ch20 += "#### 20.4.2 错误处理体验\n\n" + content_20_9.strip() + "\n\n"

    if '20.12' in sections:
        content_20_12 = re.sub(r'^### 20\.12 极端边界场景设计\s*\n', '', sections['20.12'])
        content_20_12 = re.sub(r'#### 20\.12\.', '#### 20.4.3.', content_20_12)
        new_ch20 += "#### 20.4.3 极端边界场景\n\n" + content_20_12.strip() + "\n\n"

    if '20.13' in sections:
        content_20_13 = re.sub(r'^### 20\.13 跨设备一致性体验设计\s*\n', '', sections['20.13'])
        content_20_13 = re.sub(r'#### 20\.13\.', '#### 20.4.4.', content_20_13)
        new_ch20 += "#### 20.4.4 跨设备一致性\n\n" + content_20_13.strip() + "\n\n"

    new_ch20 += "---\n\n"

    # 20.5 个性化体验设计 - 合并20.10+20.14
    new_ch20 += """### 20.5 个性化体验设计

本节整合个性化定制和深度个性化闭环的设计，打造千人千面的用户体验。

"""

    if '20.10' in sections:
        content_20_10 = re.sub(r'^### 20\.10 个性化定制设计\s*\n', '', sections['20.10'])
        content_20_10 = re.sub(r'#### 20\.10\.', '#### 20.5.1.', content_20_10)
        new_ch20 += "#### 20.5.1 个性化定制\n\n" + content_20_10.strip() + "\n\n"

    if '20.14' in sections:
        content_20_14 = re.sub(r'^### 20\.14 深度个性化闭环设计\s*\n', '', sections['20.14'])
        content_20_14 = re.sub(r'#### 20\.14\.', '#### 20.5.2.', content_20_14)
        new_ch20 += "#### 20.5.2 深度个性化闭环\n\n" + content_20_14.strip() + "\n\n"

    new_ch20 += "---\n\n"

    # 20.6 社交与成就设计 - 合并20.11+20.15
    new_ch20 += """### 20.6 社交与成就设计

本节整合分享体验和峰值体验里程碑的设计，增强用户的成就感和社交互动。

"""

    if '20.11' in sections:
        content_20_11 = re.sub(r'^### 20\.11 分享体验设计\s*\n', '', sections['20.11'])
        content_20_11 = re.sub(r'#### 20\.11\.', '#### 20.6.1.', content_20_11)
        new_ch20 += "#### 20.6.1 分享体验\n\n" + content_20_11.strip() + "\n\n"

    if '20.15' in sections:
        content_20_15 = re.sub(r'^### 20\.15 峰值体验与长期里程碑设计\s*\n', '', sections['20.15'])
        content_20_15 = re.sub(r'#### 20\.15\.', '#### 20.6.2.', content_20_15)
        new_ch20 += "#### 20.6.2 峰值体验与里程碑\n\n" + content_20_15.strip() + "\n\n"

    new_ch20 += "---\n\n"

    # 20.7 记账体验优化 - 合并20.16+20.17+20.18+20.19+20.20
    new_ch20 += """### 20.7 记账体验优化

本节整合真实记账流程、准确率提升、零配置开始、伙伴文案和家庭账本的设计，打造极致的记账体验。

"""

    if '20.16' in sections:
        content_20_16 = re.sub(r'^### 20\.16 真实记账流程与耗时设计\s*\n', '', sections['20.16'])
        content_20_16 = re.sub(r'#### 20\.16\.', '#### 20.7.1.', content_20_16)
        new_ch20 += "#### 20.7.1 真实记账流程\n\n" + content_20_16.strip() + "\n\n"

    if '20.17' in sections:
        content_20_17 = re.sub(r'^### 20\.17 渐进式准确率提升路径\s*\n', '', sections['20.17'])
        content_20_17 = re.sub(r'#### 20\.17\.', '#### 20.7.2.', content_20_17)
        new_ch20 += "#### 20.7.2 准确率提升路径\n\n" + content_20_17.strip() + "\n\n"

    if '20.18' in sections:
        content_20_18 = re.sub(r'^### 20\.18 零配置快速开始设计\s*\n', '', sections['20.18'])
        content_20_18 = re.sub(r'#### 20\.18\.', '#### 20.7.3.', content_20_18)
        new_ch20 += "#### 20.7.3 零配置快速开始\n\n" + content_20_18.strip() + "\n\n"

    if '20.19' in sections:
        content_20_19 = re.sub(r'^### 20\.19 可行建议型伙伴文案设计\s*\n', '', sections['20.19'])
        content_20_19 = re.sub(r'#### 20\.19\.', '#### 20.7.4.', content_20_19)
        new_ch20 += "#### 20.7.4 伙伴文案设计\n\n" + content_20_19.strip() + "\n\n"

    if '20.20' in sections:
        content_20_20 = re.sub(r'^### 20\.20 简化版家庭账本模式\s*\n', '', sections['20.20'])
        content_20_20 = re.sub(r'#### 20\.20\.', '#### 20.7.5.', content_20_20)
        new_ch20 += "#### 20.7.5 家庭账本模式\n\n" + content_20_20.strip() + "\n\n"

    new_ch20 += "---\n\n"

    # 20.8 竞品借鉴设计 - 来自原20.21
    if '20.21' in sections:
        content_20_21 = sections['20.21'].replace('### 20.21', '### 20.8')
        content_20_21 = re.sub(r'#### 20\.21\.', '#### 20.8.', content_20_21)
        new_ch20 += content_20_21 + "\n\n"

    new_ch20 += "---\n\n"

    # 组合最终内容
    final_content = before_ch20 + new_ch20 + after_ch20

    # 写入文件
    write_file('docs/design/app_v2_design.md', final_content)
    print("重构完成！")

    # 验证新的章节结构
    new_sections = re.findall(r'^### 20\.\d+', final_content, re.MULTILINE)
    print(f"新的小节数量: {len(new_sections)}")
    for s in new_sections:
        print(f"  {s}")

if __name__ == '__main__':
    main()
