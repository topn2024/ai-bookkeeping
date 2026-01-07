#!/usr/bin/env python3
"""
使用千问图像生成API生成App图标
"""

import requests
import json
import time
import base64
import os

API_KEY = "sk-f0a85d3e56a746509ec435af2446c67a"
API_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis"

# 图标列表 - 名称和提示词
ICONS = [
    ("food", "A modern flat design icon for food and dining, showing a bowl with steam, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("transport", "A modern flat design icon for transportation, showing a subway train, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("shopping", "A modern flat design icon for shopping, showing a shopping bag, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("entertainment", "A modern flat design icon for entertainment, showing a movie clapperboard, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("home", "A modern flat design icon for home and housing, showing a house, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("medical", "A modern flat design icon for medical and health, showing a medical cross or pill, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("education", "A modern flat design icon for education, showing a book or graduation cap, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("clothing", "A modern flat design icon for clothing and fashion, showing a t-shirt or dress, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("salary", "A modern flat design icon for salary and income, showing coins or money bag, minimalist style, gradient green colors, app icon style, white background, 512x512"),
    ("camera", "A modern flat design icon for camera and photography, showing a camera lens, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("microphone", "A modern flat design icon for voice recording, showing a microphone, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("chart", "A modern flat design icon for statistics and charts, showing a bar chart or pie chart, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("wallet", "A modern flat design icon for wallet and accounts, showing a wallet or credit card, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("target", "A modern flat design icon for goals and budget, showing a target or bullseye, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("settings", "A modern flat design icon for settings, showing a gear or cog, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("user", "A modern flat design icon for user profile, showing a person silhouette, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("ai_robot", "A modern flat design icon for AI assistant, showing a friendly robot face, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("crown", "A modern flat design icon for VIP membership, showing a golden crown, minimalist style, gradient gold colors, app icon style, white background, 512x512"),
    ("notification", "A modern flat design icon for notifications, showing a bell, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
    ("export", "A modern flat design icon for data export, showing an upload arrow, minimalist style, gradient purple and blue colors, app icon style, white background, 512x512"),
]

def generate_icon(name, prompt):
    """调用千问API生成图标"""
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
            "size": "512*512",
            "n": 1
        }
    }

    try:
        # 提交任务
        response = requests.post(API_URL, headers=headers, json=payload)
        result = response.json()

        if "output" in result and "task_id" in result["output"]:
            task_id = result["output"]["task_id"]
            print(f"[{name}] 任务已提交，task_id: {task_id}")
            return task_id
        else:
            print(f"[{name}] 提交失败: {result}")
            return None
    except Exception as e:
        print(f"[{name}] 请求异常: {e}")
        return None

def check_task_status(task_id):
    """检查任务状态"""
    url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
    headers = {
        "Authorization": f"Bearer {API_KEY}"
    }

    try:
        response = requests.get(url, headers=headers)
        return response.json()
    except Exception as e:
        print(f"检查状态异常: {e}")
        return None

def download_image(url, save_path):
    """下载图片"""
    try:
        response = requests.get(url)
        with open(save_path, 'wb') as f:
            f.write(response.content)
        return True
    except Exception as e:
        print(f"下载失败: {e}")
        return False

def main():
    icons_dir = os.path.dirname(os.path.abspath(__file__))
    icons_output_dir = os.path.join(icons_dir, "icons")
    os.makedirs(icons_output_dir, exist_ok=True)

    # 提交所有任务
    tasks = {}
    for name, prompt in ICONS:
        task_id = generate_icon(name, prompt)
        if task_id:
            tasks[name] = task_id
        time.sleep(1)  # 避免请求过快

    print(f"\n已提交 {len(tasks)} 个任务，等待生成...\n")

    # 轮询检查任务状态
    completed = set()
    max_attempts = 60  # 最多等待60次，每次10秒

    for attempt in range(max_attempts):
        all_done = True

        for name, task_id in tasks.items():
            if name in completed:
                continue

            result = check_task_status(task_id)
            if result and "output" in result:
                status = result["output"].get("task_status")

                if status == "SUCCEEDED":
                    # 下载图片
                    results = result["output"].get("results", [])
                    if results:
                        image_url = results[0].get("url")
                        if image_url:
                            save_path = os.path.join(icons_output_dir, f"{name}.png")
                            if download_image(image_url, save_path):
                                print(f"✓ [{name}] 已保存")
                                completed.add(name)
                            else:
                                print(f"✗ [{name}] 下载失败")
                                completed.add(name)
                elif status == "FAILED":
                    print(f"✗ [{name}] 生成失败: {result}")
                    completed.add(name)
                else:
                    all_done = False
                    print(f"... [{name}] {status}")

        if len(completed) == len(tasks):
            break

        if not all_done:
            time.sleep(10)

    print(f"\n完成！成功生成 {len(completed)} 个图标")
    print(f"图标保存在: {icons_output_dir}")

if __name__ == "__main__":
    main()
