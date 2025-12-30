"""Client configuration endpoints."""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional

from app.core.config import get_settings
from app.api.deps import get_current_user, get_current_user_optional
from app.models.user import User


router = APIRouter(prefix="/config", tags=["Configuration"])


# ============== 基础配置模型 ==============

class AIConfig(BaseModel):
    """AI API configuration for client."""
    qwen_api_key: str
    zhipu_api_key: str | None = None


class AIModelConfig(BaseModel):
    """AI model configuration."""
    vision_model: str = "qwen-vl-plus"
    text_model: str = "qwen-turbo"
    audio_model: str = "qwen-omni-turbo"
    category_model: str = "qwen-turbo"
    bill_model: str = "qwen-plus"


class NetworkConfig(BaseModel):
    """Network configuration."""
    connect_timeout_seconds: int = 30
    receive_timeout_seconds: int = 30
    ai_receive_timeout_seconds: int = 60
    max_retries: int = 3
    retry_base_delay_seconds: int = 2
    retry_backoff_multiplier: float = 2.0


class DuplicateDetectionConfig(BaseModel):
    """Duplicate transaction detection configuration."""
    strict_time_minutes: int = 10
    loose_time_minutes: int = 60
    max_time_minutes: int = 120
    amount_tolerance: float = 0.01


class CategoryMapping(BaseModel):
    """Category mapping configuration."""
    # 有效分类ID列表
    valid_ids: list[str] = [
        "food", "transport", "shopping", "entertainment", "housing",
        "medical", "education", "other_expense", "other_income",
        "salary", "bonus", "parttime", "investment"
    ]

    # 精确匹配映射 (中文 -> 英文ID)
    exact_map: dict[str, str] = {
        # 支出分类
        "餐饮": "food",
        "食品": "food",
        "饮食": "food",
        "吃饭": "food",
        "美食": "food",
        "交通": "transport",
        "出行": "transport",
        "打车": "transport",
        "购物": "shopping",
        "网购": "shopping",
        "娱乐": "entertainment",
        "休闲": "entertainment",
        "住房": "housing",
        "房租": "housing",
        "居住": "housing",
        "医疗": "medical",
        "健康": "medical",
        "看病": "medical",
        "教育": "education",
        "学习": "education",
        "培训": "education",
        "其他": "other_expense",
        # 收入分类
        "工资": "salary",
        "薪水": "salary",
        "薪资": "salary",
        "奖金": "bonus",
        "年终奖": "bonus",
        "兼职": "parttime",
        "副业": "parttime",
        "理财": "investment",
        "投资": "investment",
        "收益": "investment",
    }

    # 关键词映射 (分类ID -> 关键词列表)
    keywords: dict[str, list[str]] = {
        "food": [
            "餐", "饭", "食", "吃", "喝", "咖啡", "奶茶", "外卖", "早餐", "午餐", "晚餐", "夜宵", "零食", "水果",
            "星巴克", "瑞幸", "喜茶", "奈雪", "蜜雪冰城", "茶百道", "COCO", "一点点",
            "麦当劳", "肯德基", "必胜客", "汉堡王", "德克士", "赛百味",
            "海底捞", "西贝", "外婆家", "绿茶", "太二", "九毛九",
            "美团外卖", "饿了么", "盒马", "永辉", "沃尔玛", "家乐福", "大润发", "物美",
            "便利店", "全家", "711", "罗森", "便利蜂", "美宜佳",
            "面包", "蛋糕", "烘焙", "甜品", "火锅", "烧烤", "小吃", "快餐",
        ],
        "transport": [
            "车", "交通", "打车", "出租", "地铁", "公交", "滴滴", "加油", "停车", "高铁", "火车", "飞机", "机票",
            "滴滴出行", "高德打车", "T3出行", "曹操出行", "首汽约车", "享道出行",
            "哈啰", "美团单车", "青桔", "共享单车", "摩拜",
            "中国石化", "中国石油", "壳牌", "加油站",
            "12306", "铁路", "携程", "去哪儿", "飞猪", "航空",
            "过路费", "高速", "ETC", "路费", "车费",
        ],
        "shopping": [
            "购", "买", "超市", "商场", "淘宝", "京东", "网购", "衣服", "鞋",
            "天猫", "拼多多", "唯品会", "苏宁", "国美", "当当", "亚马逊",
            "优衣库", "ZARA", "HM", "GAP", "无印良品", "MUJI",
            "苹果", "Apple", "小米", "华为", "OPPO", "vivo", "三星",
            "化妆品", "护肤", "口红", "香水", "丝芙兰", "屈臣氏",
            "日用品", "生活用品", "家居", "百货",
        ],
        "entertainment": [
            "娱乐", "电影", "游戏", "KTV", "唱歌", "旅游", "景点", "门票",
            "猫眼", "淘票票", "万达影城", "CGV", "金逸",
            "腾讯游戏", "网易游戏", "王者荣耀", "和平精英", "原神",
            "爱奇艺", "腾讯视频", "优酷", "B站", "芒果TV", "Netflix", "会员", "VIP",
            "Keep", "健身", "瑜伽", "游泳", "运动",
            "演唱会", "演出", "话剧", "音乐会", "展览",
            "迪士尼", "环球影城", "欢乐谷", "方特",
        ],
        "housing": [
            "房", "租", "水电", "物业", "装修", "家具", "家电",
            "房租", "租金", "押金", "中介费",
            "水费", "电费", "燃气", "煤气", "暖气",
            "物业费", "管理费", "停车位",
            "宽带", "网费", "中国移动", "中国联通", "中国电信",
            "装修", "建材", "红星美凯龙", "居然之家",
            "宜家", "顾家", "全友", "索菲亚",
        ],
        "medical": [
            "医", "药", "病", "健康", "体检", "牙",
            "医院", "诊所", "门诊", "挂号", "住院",
            "药店", "大参林", "益丰", "老百姓", "海王星辰", "一心堂",
            "美年大健康", "爱康国宾", "慈铭",
            "牙科", "口腔", "眼科", "皮肤科",
            "保健品", "维生素", "钙片",
        ],
        "education": [
            "教育", "学", "书", "课", "培训", "考试",
            "学费", "培训费", "补习", "辅导",
            "新东方", "好未来", "学而思", "猿辅导", "作业帮",
            "得到", "知乎", "网课", "慕课", "Coursera",
            "书店", "当当", "京东图书", "亚马逊图书",
            "文具", "笔记本", "打印",
        ],
        "salary": ["工资", "薪", "月薪", "底薪", "基本工资"],
        "bonus": ["奖金", "奖", "年终", "提成", "绩效", "分红"],
        "parttime": ["兼职", "副业", "外快", "私单", "接单"],
        "investment": ["理财", "投资", "收益", "利息", "分红", "股票", "基金", "债券", "余额宝", "零钱通"],
    }


class FeatureFlags(BaseModel):
    """Feature flags for A/B testing and gradual rollout."""
    enable_voice_recognition: bool = True
    enable_image_recognition: bool = True
    enable_ai_categorization: bool = True
    enable_duplicate_detection: bool = True
    enable_offline_mode: bool = True


class AppSettingsConfig(BaseModel):
    """Complete app settings configuration."""
    # 版本信息
    config_version: str = "1.0.0"
    min_app_version: str = "1.0.0"

    # API 配置
    api_base_url: str = "https://160.202.238.29/api/v1"
    skip_certificate_verification: bool = False  # 生产环境应为 False

    # AI 配置
    ai_models: AIModelConfig = AIModelConfig()

    # 网络配置
    network: NetworkConfig = NetworkConfig()

    # 重复检测配置
    duplicate_detection: DuplicateDetectionConfig = DuplicateDetectionConfig()

    # 分类映射
    categories: CategoryMapping = CategoryMapping()

    # 功能开关
    features: FeatureFlags = FeatureFlags()


class AppConfig(BaseModel):
    """Application configuration for client (legacy support)."""
    ai: AIConfig
    version: str = "1.0.0"


# ============== API 端点 ==============

@router.get("/ai", response_model=AIConfig)
async def get_ai_config(
    current_user: User = Depends(get_current_user),
):
    """Get AI API configuration.

    Returns API keys for AI services. Requires authentication.
    """
    settings = get_settings()
    return AIConfig(
        qwen_api_key=settings.QWEN_API_KEY,
        zhipu_api_key=settings.ZHIPU_API_KEY if settings.ZHIPU_API_KEY else None,
    )


@router.get("/app", response_model=AppConfig)
async def get_app_config(
    current_user: User = Depends(get_current_user),
):
    """Get full application configuration (legacy).

    Returns all client configuration. Requires authentication.
    """
    settings = get_settings()
    return AppConfig(
        ai=AIConfig(
            qwen_api_key=settings.QWEN_API_KEY,
            zhipu_api_key=settings.ZHIPU_API_KEY if settings.ZHIPU_API_KEY else None,
        ),
        version="1.0.0",
    )


@router.get("/app-settings", response_model=AppSettingsConfig)
async def get_app_settings(
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """Get complete app settings configuration.

    Returns all app configuration including:
    - API base URL
    - AI model configurations
    - Network settings
    - Category mappings
    - Feature flags

    Does not require authentication (for initial app setup).
    Sensitive data (API keys) requires authentication via /config/ai endpoint.
    """
    # 服务器当前使用自签名证书，需要跳过验证
    # TODO: 部署正式证书后改为 False
    skip_cert_verification = True

    return AppSettingsConfig(
        config_version="1.0.0",
        min_app_version="1.1.0",
        api_base_url="https://160.202.238.29/api/v1",
        skip_certificate_verification=skip_cert_verification,
        ai_models=AIModelConfig(),
        network=NetworkConfig(),
        duplicate_detection=DuplicateDetectionConfig(),
        categories=CategoryMapping(),
        features=FeatureFlags(),
    )


@router.get("/categories", response_model=CategoryMapping)
async def get_category_config():
    """Get category mapping configuration.

    Returns category IDs, exact mappings, and keyword mappings.
    Does not require authentication.
    """
    return CategoryMapping()
