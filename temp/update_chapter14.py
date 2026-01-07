#!/usr/bin/env python3
import re

# Read the original file
with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Read the new chapter 14 content
with open('D:/code/ai-bookkeeping/temp/chapter14_new.md', 'r', encoding='utf-8') as f:
    new_chapter = f.read()

# Pattern to match chapter 14 content (from ## 14. to just before ## 15.)
pattern = r'(## 14\. 国际化与本地化.*?)(\n---\n\n## 15\. 安全与隐私)'

# Replace the chapter
new_content = re.sub(pattern, new_chapter + r'\n## 15. 安全与隐私', content, flags=re.DOTALL)

# Write back
with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Chapter 14 updated successfully!")
