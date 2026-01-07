# -*- coding: utf-8 -*-
"""
修复第18章（性能设计与优化）的子节编号
原来是16.X，需要改为18.X
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到第18章的位置
    ch18_start = content.find('## 18. 性能设计与优化')
    ch19_start = content.find('## 19. 用户体验设计')

    if ch18_start == -1 or ch19_start == -1:
        print("❌ 未找到章节位置")
        return

    # 提取第18章内容
    ch18_content = content[ch18_start:ch19_start]

    # 修复子节编号
    ch18_content = ch18_content.replace('### 16.0 ', '### 18.0 ')
    ch18_content = ch18_content.replace('### 16.1 ', '### 18.1 ')
    ch18_content = ch18_content.replace('### 16.2 ', '### 18.2 ')
    ch18_content = ch18_content.replace('### 16.3 ', '### 18.3 ')
    ch18_content = ch18_content.replace('### 16.4 ', '### 18.4 ')
    ch18_content = ch18_content.replace('### 16.5 ', '### 18.5 ')
    ch18_content = ch18_content.replace('### 16.6 ', '### 18.6 ')
    ch18_content = ch18_content.replace('### 16.7 ', '### 18.7 ')
    ch18_content = ch18_content.replace('### 16.8 ', '### 18.8 ')
    ch18_content = ch18_content.replace('### 16.9 ', '### 18.9 ')
    ch18_content = ch18_content.replace('#### 16.', '#### 18.')

    # 重新组装
    new_content = content[:ch18_start] + ch18_content + content[ch19_start:]

    # 同样检查并修复其他章节
    # 第19章（用户体验设计）
    ch19_start_new = new_content.find('## 19. 用户体验设计')
    ch20_start = new_content.find('## 20. 国际化与本地化')
    if ch19_start_new != -1 and ch20_start != -1:
        ch19_content = new_content[ch19_start_new:ch20_start]
        ch19_content = ch19_content.replace('### 17.', '### 19.')
        ch19_content = ch19_content.replace('#### 17.', '#### 19.')
        new_content = new_content[:ch19_start_new] + ch19_content + new_content[ch20_start:]

    # 第20章（国际化与本地化）
    ch20_start_new = new_content.find('## 20. 国际化与本地化')
    ch21_start = new_content.find('## 21. 安全与隐私')
    if ch20_start_new != -1 and ch21_start != -1:
        ch20_content = new_content[ch20_start_new:ch21_start]
        ch20_content = ch20_content.replace('### 18.', '### 20.')
        ch20_content = ch20_content.replace('#### 18.', '#### 20.')
        new_content = new_content[:ch20_start_new] + ch20_content + new_content[ch21_start:]

    # 第21章（安全与隐私）
    ch21_start_new = new_content.find('## 21. 安全与隐私')
    ch22_start = new_content.find('## 22. 异常处理与容错设计')
    if ch21_start_new != -1 and ch22_start != -1:
        ch21_content = new_content[ch21_start_new:ch22_start]
        ch21_content = ch21_content.replace('### 19.', '### 21.')
        ch21_content = ch21_content.replace('#### 19.', '#### 21.')
        new_content = new_content[:ch21_start_new] + ch21_content + new_content[ch22_start:]

    # 第22章（异常处理与容错设计）
    ch22_start_new = new_content.find('## 22. 异常处理与容错设计')
    ch23_start = new_content.find('## 23. 可扩展性与演进架构')
    if ch22_start_new != -1 and ch23_start != -1:
        ch22_content = new_content[ch22_start_new:ch23_start]
        ch22_content = ch22_content.replace('### 20.', '### 22.')
        ch22_content = ch22_content.replace('#### 20.', '#### 22.')
        new_content = new_content[:ch22_start_new] + ch22_content + new_content[ch23_start:]

    # 第23章（可扩展性与演进架构）
    ch23_start_new = new_content.find('## 23. 可扩展性与演进架构')
    ch24_start = new_content.find('## 24. 可观测性与监控')
    if ch23_start_new != -1 and ch24_start != -1:
        ch23_content = new_content[ch23_start_new:ch24_start]
        ch23_content = ch23_content.replace('### 21.', '### 23.')
        ch23_content = ch23_content.replace('#### 21.', '#### 23.')
        new_content = new_content[:ch23_start_new] + ch23_content + new_content[ch24_start:]

    # 第24章（可观测性与监控）
    ch24_start_new = new_content.find('## 24. 可观测性与监控')
    ch25_start = new_content.find('## 25. 版本迁移策略')
    if ch24_start_new != -1 and ch25_start != -1:
        ch24_content = new_content[ch24_start_new:ch25_start]
        ch24_content = ch24_content.replace('### 22.', '### 24.')
        ch24_content = ch24_content.replace('#### 22.', '#### 24.')
        new_content = new_content[:ch24_start_new] + ch24_content + new_content[ch25_start:]

    # 第25章（版本迁移策略）
    ch25_start_new = new_content.find('## 25. 版本迁移策略')
    ch26_start = new_content.find('## 26. 实施路线图')
    if ch25_start_new != -1 and ch26_start != -1:
        ch25_content = new_content[ch25_start_new:ch26_start]
        ch25_content = ch25_content.replace('### 23.', '### 25.')
        ch25_content = ch25_content.replace('#### 23.', '#### 25.')
        new_content = new_content[:ch25_start_new] + ch25_content + new_content[ch26_start:]

    # 第26章（实施路线图）
    ch26_start_new = new_content.find('## 26. 实施路线图')
    if ch26_start_new != -1:
        ch26_content = new_content[ch26_start_new:]
        ch26_content = ch26_content.replace('### 24.', '### 26.')
        ch26_content = ch26_content.replace('#### 24.', '#### 26.')
        new_content = new_content[:ch26_start_new] + ch26_content

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("✅ 章节子节编号修复完成")

if __name__ == '__main__':
    main()
