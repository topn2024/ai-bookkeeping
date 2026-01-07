#!/usr/bin/env python3
import re

# Read the original file
with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Read the new chapter 18 content
with open('D:/code/ai-bookkeeping/temp/chapter18_new.md', 'r', encoding='utf-8') as f:
    new_chapter = f.read()

# Pattern to match chapter 18 content (from ## 18. to just before ## 19.)
pattern = r'(## 18\. 测试策略.*?)(\n---\n\n## 19\. 异常处理与容错设计)'

# Replace the chapter
new_content = re.sub(pattern, new_chapter + r'\n## 19. 异常处理与容错设计', content, flags=re.DOTALL)

# Verify replacement happened
if new_content == content:
    print("WARNING: No replacement was made!")
else:
    # Write back
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Chapter 18 updated successfully!")
