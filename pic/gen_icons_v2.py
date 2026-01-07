#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用千问图像生成API生成App图标 - V2
"""

import requests
import json
import time
import os
import sys

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

API_KEY = "sk-f0a85d3e56a746509ec435af2446c67a"
API_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis"

# 图标列表 - 分批生成
ICONS = [
    ("food", "flat design app icon, food bowl with steam, minimalist, purple blue gradient, white background, vector style"),
    ("transport", "flat design app icon, subway train, minimalist, purple blue gradient, white background, vector style"),
    ("shopping", "flat design app icon, shopping bag, minimalist, purple blue gradient, white background, vector style"),
    ("entertainment", "flat design app icon, movie ticket, minimalist, purple blue gradient, white background, vector style"),
    ("wallet", "flat design app icon, digital wallet, minimalist, purple blue gradient, white background, vector style"),
]

def generate_icon(name, prompt):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable"
    }

    payload = {
        "model": "wanx-v1",
        "input": {
            "prompt": prompt
        },
        "parameters": {
            "style": "<auto>",
            "size": "1024*1024",
            "n": 1
        }
    }

    try:
        response = requests.post(API_URL, headers=headers, json=payload)
        result = response.json()
        print(f"[{name}] Response: {json.dumps(result, ensure_ascii=False)}")

        if "output" in result and "task_id" in result["output"]:
            return result["output"]["task_id"]
        return None
    except Exception as e:
        print(f"[{name}] Error: {e}")
        return None

def check_and_download(task_id, name, icons_dir):
    url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
    headers = {"Authorization": f"Bearer {API_KEY}"}

    for _ in range(30):  # 最多等待5分钟
        try:
            response = requests.get(url, headers=headers)
            result = response.json()

            if "output" in result:
                status = result["output"].get("task_status")
                print(f"[{name}] Status: {status}")

                if status == "SUCCEEDED":
                    results = result["output"].get("results", [])
                    if results:
                        image_url = results[0].get("url")
                        if image_url:
                            save_path = os.path.join(icons_dir, f"{name}.png")
                            img_response = requests.get(image_url)
                            with open(save_path, 'wb') as f:
                                f.write(img_response.content)
                            print(f"[{name}] Downloaded to {save_path}")
                            return True
                elif status == "FAILED":
                    print(f"[{name}] Failed: {result['output'].get('message', 'Unknown error')}")
                    return False

            time.sleep(10)
        except Exception as e:
            print(f"[{name}] Check error: {e}")
            time.sleep(10)

    return False

def main():
    icons_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    os.makedirs(icons_dir, exist_ok=True)

    # 生成图标
    for name, prompt in ICONS:
        print(f"\n=== Generating {name} ===")
        task_id = generate_icon(name, prompt)

        if task_id:
            print(f"[{name}] Task ID: {task_id}")
            time.sleep(2)  # 等待任务开始
            check_and_download(task_id, name, icons_dir)
        else:
            print(f"[{name}] Failed to submit task")

        time.sleep(1)

    print("\nDone!")

if __name__ == "__main__":
    main()
