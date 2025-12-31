"""
时区工具模块 - 统一使用北京时间
"""
from datetime import datetime, timezone, timedelta

# 北京时区 (UTC+8)
BEIJING_TZ = timezone(timedelta(hours=8))


def beijing_now() -> datetime:
    """获取当前北京时间（带时区信息）"""
    return datetime.now(BEIJING_TZ)


def beijing_now_naive() -> datetime:
    """获取当前北京时间（不带时区信息，用于数据库存储）"""
    return datetime.now(BEIJING_TZ).replace(tzinfo=None)


def utc_to_beijing(dt: datetime) -> datetime:
    """将 UTC 时间转换为北京时间"""
    if dt is None:
        return None
    if dt.tzinfo is None:
        # 假设无时区的时间是 UTC
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(BEIJING_TZ)


def format_beijing_time(dt: datetime, fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """格式化为北京时间字符串"""
    if dt is None:
        return ""
    beijing_dt = utc_to_beijing(dt)
    return beijing_dt.strftime(fmt)
