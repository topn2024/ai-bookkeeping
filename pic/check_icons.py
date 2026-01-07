#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查图标生成任务状态并下载
"""

import requests
import time
import os
import sys

# Fix encoding for Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

API_KEY = "sk-f0a85d3e56a746509ec435af2446c67a"

# 任务ID列表
TASKS = {
    "food": "0e63a58f-7d38-4753-84f0-8dfc0d29b1a1",
    "transport": "14277aab-712a-42e5-b8fc-5f8121b64706",
    "shopping": "cb39223b-5c27-455c-b21d-8283bcb52eeb",
    "entertainment": "acc0b9db-6732-40b7-b4ae-846be77477f5",
    "home": "1c231458-b202-47cf-b94d-27863d24388d",
    "medical": "4ab128bd-ebcf-43e0-9f30-f491e9aa5720",
    "education": "1a44b25e-f718-49bb-aae5-f60fbcd89b9a",
    "clothing": "82347a4e-3279-4e86-8202-55677a0b6ef8",
    "salary": "62c8bea3-5357-42df-ab57-ad5cf13176c2",
    "camera": "902411b2-df28-4905-b364-d96c04e8bb48",
    "microphone": "59661793-2273-419e-9ff6-1c18926d280c",
    "chart": "16879692-6448-41c2-bfd1-d4271da61ecc",
    "wallet": "a0fb3a32-7ea5-48f3-8982-c1f457cde959",
    "target": "18e3449e-5586-4a65-9d29-ddcdf68547bd",
    "settings": "2ce7d942-d5aa-46ea-9c8b-b782ad57a0d5",
    "user": "b44abca9-489e-479a-91f7-10e82034c624",
    "ai_robot": "f7811e6d-11f7-44a0-81ae-1df97e455f2b",
    "crown": "df2b9654-6043-4387-8a57-6c0c2f46f5df",
    "notification": "db7221fd-4f08-44a9-8466-2a8c0a285300",
    "export": "abdc839c-80e3-42f6-9d66-b567b7e752b7",
}

def check_task_status(task_id):
    url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    try:
        response = requests.get(url, headers=headers)
        return response.json()
    except Exception as e:
        print(f"Error: {e}")
        return None

def download_image(url, save_path):
    try:
        response = requests.get(url)
        with open(save_path, 'wb') as f:
            f.write(response.content)
        return True
    except Exception as e:
        print(f"Download error: {e}")
        return False

def main():
    icons_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    os.makedirs(icons_dir, exist_ok=True)

    completed = 0
    failed = 0

    for name, task_id in TASKS.items():
        save_path = os.path.join(icons_dir, f"{name}.png")

        # Check if already downloaded
        if os.path.exists(save_path):
            print(f"[OK] {name} - already exists")
            completed += 1
            continue

        result = check_task_status(task_id)
        if result and "output" in result:
            status = result["output"].get("task_status")

            if status == "SUCCEEDED":
                results = result["output"].get("results", [])
                if results:
                    image_url = results[0].get("url")
                    if image_url and download_image(image_url, save_path):
                        print(f"[OK] {name} - downloaded")
                        completed += 1
                    else:
                        print(f"[FAIL] {name} - download failed")
                        failed += 1
            elif status == "FAILED":
                print(f"[FAIL] {name} - generation failed")
                failed += 1
            elif status == "RUNNING" or status == "PENDING":
                print(f"[WAIT] {name} - {status}")
            else:
                print(f"[?] {name} - {status}")
        else:
            print(f"[ERROR] {name} - cannot get status")

    print(f"\nCompleted: {completed}, Failed: {failed}, Pending: {len(TASKS) - completed - failed}")

if __name__ == "__main__":
    main()
