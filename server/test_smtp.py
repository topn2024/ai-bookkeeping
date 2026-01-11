#!/usr/bin/env python3
"""测试SMTP邮件发送功能"""
import smtplib
import asyncio
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header
from email.utils import formataddr

# 从环境变量读取配置
import os
from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.qq.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", SMTP_USER)
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "AI智能记账")
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "false").lower() == "true"


def test_smtp_connection():
    """测试SMTP连接和邮件发送"""
    print("=" * 60)
    print("SMTP配置测试")
    print("=" * 60)
    print(f"SMTP服务器: {SMTP_HOST}")
    print(f"SMTP端口: {SMTP_PORT}")
    print(f"SMTP用户: {SMTP_USER}")
    print(f"SMTP密码: {'*' * len(SMTP_PASSWORD) if SMTP_PASSWORD else '(未设置)'}")
    print(f"使用TLS: {SMTP_USE_TLS}")
    print(f"发件人邮箱: {SMTP_FROM_EMAIL}")
    print(f"发件人名称: {SMTP_FROM_NAME}")
    print("=" * 60)

    if not SMTP_HOST or not SMTP_USER or not SMTP_PASSWORD:
        print("\n❌ 错误: SMTP配置不完整，请检查.env文件")
        return False

    try:
        # 创建邮件
        msg = MIMEMultipart("alternative")
        msg["Subject"] = Header("【测试】密码重置验证码", "utf-8")
        msg["From"] = formataddr((str(Header(SMTP_FROM_NAME, "utf-8")), SMTP_FROM_EMAIL))
        msg["To"] = SMTP_USER  # 发送给自己测试

        # 测试验证码
        reset_code = "123456"

        html_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center;">
                <h1 style="color: white; margin: 0;">密码重置测试</h1>
            </div>
            <div style="padding: 30px; background: #f9f9f9;">
                <p>这是一封测试邮件</p>
                <p>您的测试验证码是：</p>
                <div style="background: white; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #667eea;">{reset_code}</span>
                </div>
            </div>
        </body>
        </html>
        """

        text_body = f"""
密码重置验证码测试

这是一封测试邮件。
您的测试验证码是：{reset_code}
"""

        msg.attach(MIMEText(text_body, "plain", "utf-8"))
        msg.attach(MIMEText(html_body, "html", "utf-8"))

        print("\n正在连接SMTP服务器...")

        # 根据配置选择连接方式
        if SMTP_USE_TLS:
            print(f"使用 SMTP + STARTTLS 连接到 {SMTP_HOST}:{SMTP_PORT}")
            server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30)
            server.set_debuglevel(1)  # 启用调试输出
            server.starttls()
        else:
            print(f"使用 SMTP_SSL 连接到 {SMTP_HOST}:{SMTP_PORT}")
            server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=30)
            server.set_debuglevel(1)  # 启用调试输出

        print("\n正在登录...")
        server.login(SMTP_USER, SMTP_PASSWORD)
        print("✅ 登录成功")

        print("\n正在发送邮件...")
        server.sendmail(SMTP_FROM_EMAIL, SMTP_USER, msg.as_string())
        print("✅ 邮件发送成功")

        server.quit()
        print("\n" + "=" * 60)
        print("✅ 测试完成！请检查邮箱: " + SMTP_USER)
        print("=" * 60)
        return True

    except smtplib.SMTPAuthenticationError as e:
        print(f"\n❌ SMTP认证失败: {e}")
        print("\n可能的原因:")
        print("1. QQ邮箱授权码错误或已过期")
        print("2. 需要在QQ邮箱设置中重新生成授权码")
        print("3. 请访问: https://mail.qq.com/")
        print("   设置 -> 账户 -> 开启SMTP服务 -> 生成授权码")
        return False

    except smtplib.SMTPException as e:
        print(f"\n❌ SMTP错误: {e}")
        return False

    except Exception as e:
        print(f"\n❌ 发送失败: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    test_smtp_connection()
