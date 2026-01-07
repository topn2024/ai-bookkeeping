# -*- coding: utf-8 -*-
"""
添加交叉引用，解决第28、29章与现有章节的重复问题
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 1. 在2.5.2节末尾添加NPS交叉引用 (在 "#### 2.5.3" 之前)
    old_text1 = '''  ];
}
```

#### 2.5.3 用户反馈闭环机制'''

    new_text1 = '''  ];
}
```

> 📎 **相关章节**：完整NPS监测与提升设计详见[第28章 用户口碑与NPS提升设计](#28-用户口碑与nps提升设计)

#### 2.5.3 用户反馈闭环机制'''

    if old_text1 in content and new_text1 not in content:
        content = content.replace(old_text1, new_text1)
        print("已添加2.5.2节NPS交叉引用")
        changes += 1
    elif new_text1 in content:
        print("2.5.2节NPS交叉引用已存在")
    else:
        print("未找到2.5.2节插入位置")

    # 2. 在12.8节末尾添加分享功能交叉引用 (在 "### 12.9" 之前)
    old_text2 = '''  return file;
  }
}
```

### 12.9 与其他系统的集成'''

    new_text2 = '''  return file;
  }
}
```

> 📎 **相关章���**：增长导向的分享素材设计详见[第29.1节 产品内置增长引擎](#291-产品内置增长引擎)

### 12.9 与���他系统的集成'''

    if old_text2 in content and new_text2 not in content:
        content = content.replace(old_text2, new_text2)
        print("已添加12.8节分享功能交叉引用")
        changes += 1
    elif new_text2 in content:
        print("12.8节分享功能交叉引用已存在")
    else:
        print("未找到12.8节插入位置")

    # 3. 在13.2.2节末尾添加邀请机制交叉引用 (在 "### 13.3" 之前)
    old_text3 = '''enum InvitationStatus {
  active,
  expired,
  revoked,
}
```

### 13.3 家庭预算协作'''

    new_text3 = '''enum InvitationStatus {
  active,
  expired,
  revoked,
}
```

> 📎 **相关章节**：邀请裂变与增长优化设计详见[第29.4节 社交裂变机制设计](#294-社交裂变机制设计)

### 13.3 家庭预算协作'''

    if old_text3 in content and new_text3 not in content:
        content = content.replace(old_text3, new_text3)
        print("已添加13.2.2节邀请机制交叉引用")
        changes += 1
    elif new_text3 in content:
        print("13.2.2节邀请机制交叉引用已存在")
    else:
        print("未找到13.2.2节插入位置")

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n已完成 {changes} 处交叉引用添加")
    else:
        print("\n未做任何修改")

if __name__ == '__main__':
    main()
