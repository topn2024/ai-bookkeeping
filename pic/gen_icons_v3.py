#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成更多图标
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

# 更多图标
ICONS = [
    ("home", "flat design app icon, modern house, minimalist, purple blue gradient, white background, vector style"),
    ("medical", "flat design app icon, medical cross symbol, minimalist, purple blue gradient, white background, vector style"),
    ("education", "flat design app icon, open book, minimalist, purple blue gradient, white background, vector style"),
    ("clothing", "flat design app icon, t-shirt, minimalist, purple blue gradient, white background, vector style"),
    ("salary", "flat design app icon, golden coins stack, minimalist, green gradient, white background, vector style"),
    ("camera", "flat design app icon, camera lens, minimalist, purple blue gradient, white background, vector style"),
    ("microphone", "flat design app icon, microphone, minimalist, purple blue gradient, white background, vector style"),
    ("chart", "flat design app icon, bar chart graph, minimalist, purple blue gradient, white background, vector style"),
    ("target", "flat design app icon, target bullseye, minimalist, purple blue gradient, white background, vector style"),
    ("settings", "flat design app icon, gear cog, minimalist, purple blue gradient, white background, vector style"),
    ("user", "flat design app icon, person avatar silhouette, minimalist, purple blue gradient, white background, vector style"),
    ("ai_robot", "flat design app icon, friendly robot face, minimalist, purple blue gradient, white background, vector style"),
    ("crown", "flat design app icon, royal golden crown, minimalist, gold gradient, white background, vector style"),
    ("notification", "flat design app icon, bell notification, minimalist, purple blue gradient, white background, vector style"),
    ("export", "flat design app icon, upload arrow, minimalist, purple blue gradient, white background, vector style"),
    ("logo", "flat design app icon, wallet with AI chip inside, minimalist, purple blue gradient, white background, vector style, modern fintech"),
]

def generate_and_download(name, prompt, icons_dir):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable"
    }

    payload = {
        "model": "wanx-v1",
        "input": {"prompt": prompt},
        "parameters": {"style": "<auto>", "size": "1024*1024", "n": 1}
    }

    # Check if already exists
    save_path = os.path.join(icons_dir, f"{name}.png")
    if os.path.exists(save_path):
        print(f"[{name}] Already exists, skipping")
        return True

    try:
        response = requests.post(API_URL, headers=headers, json=payload)
        result = response.json()

        if "output" not in result or "task_id" not in result["output"]:
            print(f"[{name}] Failed to submit: {result}")
            return False

        task_id = result["output"]["task_id"]
        print(f"[{name}] Task: {task_id}")

        # Poll for completion
        for _ in range(30):
            time.sleep(10)
            check_url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
            check_response = requests.get(check_url, headers={"Authorization": f"Bearer {API_KEY}"})
            check_result = check_response.json()

            status = check_result.get("output", {}).get("task_status")
            print(f"[{name}] {status}")

            if status == "SUCCEEDED":
                results = check_result["output"].get("results", [])
                if results:
                    image_url = results[0].get("url")
                    if image_url:
                        img_response = requests.get(image_url)
                        with open(save_path, 'wb') as f:
                            f.write(img_response.content)
                        print(f"[{name}] OK - saved")
                        return True
            elif status == "FAILED":
                print(f"[{name}] FAILED")
                return False

        return False
    except Exception as e:
        print(f"[{name}] Error: {e}")
        return False

def main():
    icons_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    os.makedirs(icons_dir, exist_ok=True)

    success = 0
    for name, prompt in ICONS:
        print(f"\n=== {name} ===")
        if generate_and_download(name, prompt, icons_dir):
            success += 1
        time.sleep(1)

    print(f"\n\nCompleted: {success}/{len(ICONS)}")

if __name__ == "__main__":
    main()
