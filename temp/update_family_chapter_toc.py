# -*- coding: utf-8 -*-
"""
更新目录和子节编号
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. 更新目录中的章节编号
    toc_updates = [
        ('- [13. 地理位置智能化应用]', '- [14. 地理位置智能化应用]'),
        ('(#13-地理位置智能化应用)', '(#14-地理位置智能化应用)'),
        ('- [14. 技术架构设计]', '- [15. 技术架构设计]'),
        ('(#14-技术架构设计)', '(#15-技术架构设计)'),
        ('- [15. 智能化技术方案]', '- [16. 智能化技术方案]'),
        ('(#15-智能化技术方案)', '(#16-智能化技术方案)'),
        ('- [16. 自学习与协同学习系统]', '- [17. 自学习与协同学习系统]'),
        ('(#16-自学习与协同学习系统)', '(#17-自学习与协同学习系统)'),
        ('- [17. 智能语音交互系统]', '- [18. 智能语音交互系统]'),
        ('(#17-智能语音交互系统)', '(#18-智能语音交互系统)'),
        ('- [18. 性能设计与优化]', '- [19. 性能设计与优化]'),
        ('(#18-性能设计与优化)', '(#19-性能设计与优化)'),
        ('- [19. 用户体验设计]', '- [20. 用户体验设计]'),
        ('(#19-用户体验设计)', '(#20-用户体验设计)'),
        ('- [20. 国际化与本地化]', '- [21. 国际化与本地化]'),
        ('(#20-国际化与本地化)', '(#21-国际化与本地化)'),
        ('- [21. 安全与隐私]', '- [22. 安全与隐私]'),
        ('(#21-安全与隐私)', '(#22-安全与隐私)'),
        ('- [22. 异常处理与容错设计]', '- [23. 异常处理与容错设计]'),
        ('(#22-异常处理与容错设计)', '(#23-异常处理与容错设计)'),
        ('- [23. 可扩展性与演进架构]', '- [24. 可扩展性与演进架构]'),
        ('(#23-可扩展性与演进架构)', '(#24-可扩展性与演进架构)'),
        ('- [24. 可观测性与监控]', '- [25. 可观测性与监控]'),
        ('(#24-可观测性与监控)', '(#25-可观测性与监控)'),
        ('- [25. 版本迁移策略]', '- [26. 版本迁移策略]'),
        ('(#25-版本迁移策略)', '(#26-版本迁移策略)'),
        ('- [26. 实施路线图]', '- [27. 实施路线图]'),
        ('(#26-实施路线图)', '(#27-实施路线图)'),
    ]

    for old, new in toc_updates:
        content = content.replace(old, new)

    # 2. 在目录中添加第13章
    toc_13 = '''- [13. 家庭账本与多成员管理系统](#13-家庭账本与多成员管理系统)
  - [13.0 设计原则回顾](#130-设计原则回顾)
  - [13.1 账本体系架构](#131-账本体系架构)
  - [13.2 成员管理系统](#132-成员管理系统)
  - [13.3 家庭预算协作](#133-家庭预算协作)
  - [13.4 交易协作与分摊](#134-交易协作与分摊)
  - [13.5 家庭统计与报表](#135-家庭统计与报表)
  - [13.6 家庭目标与激励](#136-家庭目标与激励)
  - [13.7 数据同步与冲突处理](#137-数据同步与冲突处理)
  - [13.8 隐私与安全](#138-隐私与安全)
  - [13.9 与其他系统的集成](#139-与其他系统的集成)
  - [13.10 目标达成检测](#1310-目标达成检测)
'''

    # 在第14章之前插入
    old_toc_14 = '- [14. 地理位置智能化应用]'
    new_toc_14 = toc_13 + '- [14. 地理位置智能化应用]'
    content = content.replace(old_toc_14, new_toc_14, 1)
    print("已添加第13章目录项")

    # 3. 更新后续章节的子节编号
    # 原14章(地理位置)->15章
    content = content.replace('### 13.', '### 14.')
    content = content.replace('#### 13.', '#### 14.')

    # 原15章(技术架构)->16章: 需要在特定范围内替换
    # 找到第15章和第16章的位置
    ch15_start = content.find('## 15. 技术架构设计')
    ch16_start = content.find('## 16. 智能化技术方案')

    if ch15_start != -1 and ch16_start != -1:
        ch15_content = content[ch15_start:ch16_start]
        ch15_content = ch15_content.replace('### 14.', '### 15.')
        ch15_content = ch15_content.replace('#### 14.', '#### 15.')
        content = content[:ch15_start] + ch15_content + content[ch16_start:]
        print("已更新第15章子节编号")

    # 原16章(智能化技术)->17章
    ch16_end = content.find('## 17. 自学习与协同学习系统')
    if ch16_start != -1 and ch16_end != -1:
        ch16_content = content[ch16_start:ch16_end]
        ch16_content = ch16_content.replace('### 15.', '### 16.')
        ch16_content = ch16_content.replace('#### 15.', '#### 16.')
        ch16_content = ch16_content.replace('##### 15.', '##### 16.')
        content = content[:ch16_start] + ch16_content + content[ch16_end:]
        print("已更新第16章子节编号")

    # 原17章(自学习)->18章
    ch17_start = content.find('## 17. 自学习与协同学习系统')
    ch18_start = content.find('## 18. 智能语音交互系统')
    if ch17_start != -1 and ch18_start != -1:
        ch17_content = content[ch17_start:ch18_start]
        ch17_content = ch17_content.replace('### 16.', '### 17.')
        ch17_content = ch17_content.replace('#### 16.', '#### 17.')
        content = content[:ch17_start] + ch17_content + content[ch18_start:]
        print("已更新第17章子节编号")

    # 原18章(语音交互)->19章
    ch18_end = content.find('## 19. 性能设计与优化')
    if ch18_start != -1 and ch18_end != -1:
        ch18_content = content[ch18_start:ch18_end]
        ch18_content = ch18_content.replace('### 17.', '### 18.')
        ch18_content = ch18_content.replace('#### 17.', '#### 18.')
        ch18_content = ch18_content.replace('##### 17.', '##### 18.')
        content = content[:ch18_start] + ch18_content + content[ch18_end:]
        print("已更新第18章子节编号")

    # 原19章(性能)->20章
    ch19_start = content.find('## 19. 性能设计与优化')
    ch20_start = content.find('## 20. 用户体验设计')
    if ch19_start != -1 and ch20_start != -1:
        ch19_content = content[ch19_start:ch20_start]
        ch19_content = ch19_content.replace('### 18.', '### 19.')
        ch19_content = ch19_content.replace('#### 18.', '#### 19.')
        content = content[:ch19_start] + ch19_content + content[ch20_start:]
        print("已更新第19章子节编号")

    # 原20章(用户体验)->21章
    ch20_end = content.find('## 21. 国际化与本地化')
    if ch20_start != -1 and ch20_end != -1:
        ch20_content = content[ch20_start:ch20_end]
        ch20_content = ch20_content.replace('### 19.', '### 20.')
        ch20_content = ch20_content.replace('#### 19.', '#### 20.')
        content = content[:ch20_start] + ch20_content + content[ch20_end:]
        print("已更新第20章子节编号")

    # 原21章(国际化)->22章
    ch21_start = content.find('## 21. 国际化与本地化')
    ch22_start = content.find('## 22. 安全与隐私')
    if ch21_start != -1 and ch22_start != -1:
        ch21_content = content[ch21_start:ch22_start]
        ch21_content = ch21_content.replace('### 20.', '### 21.')
        ch21_content = ch21_content.replace('#### 20.', '#### 21.')
        content = content[:ch21_start] + ch21_content + content[ch22_start:]
        print("已更新第21章子节编号")

    # 原22章(安全)->23章
    ch22_end = content.find('## 23. 异常处理与容错设计')
    if ch22_start != -1 and ch22_end != -1:
        ch22_content = content[ch22_start:ch22_end]
        ch22_content = ch22_content.replace('### 21.', '### 22.')
        ch22_content = ch22_content.replace('#### 21.', '#### 22.')
        content = content[:ch22_start] + ch22_content + content[ch22_end:]
        print("已更新第22章子节编号")

    # 原23章(异常处理)->24章
    ch23_start = content.find('## 23. 异常处理与容错设计')
    ch24_start = content.find('## 24. 可扩展性与演进架构')
    if ch23_start != -1 and ch24_start != -1:
        ch23_content = content[ch23_start:ch24_start]
        ch23_content = ch23_content.replace('### 22.', '### 23.')
        ch23_content = ch23_content.replace('#### 22.', '#### 23.')
        content = content[:ch23_start] + ch23_content + content[ch24_start:]
        print("已更新第23章子节编号")

    # 原24章(可扩展性)->25章
    ch24_end = content.find('## 25. 可观测性与监控')
    if ch24_start != -1 and ch24_end != -1:
        ch24_content = content[ch24_start:ch24_end]
        ch24_content = ch24_content.replace('### 23.', '### 24.')
        ch24_content = ch24_content.replace('#### 23.', '#### 24.')
        content = content[:ch24_start] + ch24_content + content[ch24_end:]
        print("已更新第24章子节编号")

    # 原25章(可观测性)->26章
    ch25_start = content.find('## 25. 可观测性与监控')
    ch26_start = content.find('## 26. 版本迁移策略')
    if ch25_start != -1 and ch26_start != -1:
        ch25_content = content[ch25_start:ch26_start]
        ch25_content = ch25_content.replace('### 24.', '### 25.')
        ch25_content = ch25_content.replace('#### 24.', '#### 25.')
        content = content[:ch25_start] + ch25_content + content[ch26_start:]
        print("已更新第25章子节编号")

    # 原26章(版本迁移)->27章
    ch26_end = content.find('## 27. 实施路线图')
    if ch26_start != -1 and ch26_end != -1:
        ch26_content = content[ch26_start:ch26_end]
        ch26_content = ch26_content.replace('### 25.', '### 26.')
        ch26_content = ch26_content.replace('#### 25.', '#### 26.')
        content = content[:ch26_start] + ch26_content + content[ch26_end:]
        print("已更新第26章子节编号")

    # 原27章(实施路线图)->27章（保持不变，但更新子节）
    ch27_start = content.find('## 27. 实施路线图')
    if ch27_start != -1:
        ch27_content = content[ch27_start:]
        ch27_content = ch27_content.replace('### 26.', '### 27.')
        ch27_content = ch27_content.replace('#### 26.', '#### 27.')
        content = content[:ch27_start] + ch27_content
        print("已更新第27章子节编号")

    # 保存
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n目录和子节编号更新完成！")

if __name__ == '__main__':
    main()
