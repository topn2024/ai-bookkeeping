# -*- coding: utf-8 -*-
"""
添加10.6.2节到13.4节的交叉引用
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在10.6.2节末尾（AADetectionResult类结束后）添加交叉引用
    old_text = '''  });
}
```

### 10.7 上下文感知与连续记账'''

    new_text = '''  });
}
```

> 📎 **相关章节**：AA分摊业务逻辑实现详见[第13.4节 交易协作与分摊](#134-交易协作与分摊)

### 10.7 上下文感知与连续记账'''

    if old_text in content:
        if '> 📎 **相关章节**：AA分摊业务逻辑' not in content:
            content = content.replace(old_text, new_text)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print("已���加10.6.2节到13.4节的交叉引用")
        else:
            print("交叉引用已存在，无需重复添加")
    else:
        print("未找到目标位置")

if __name__ == '__main__':
    main()
