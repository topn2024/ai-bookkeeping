"""数据质量监控API的Pydantic schemas"""
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


# ==================== 请求Schemas ====================


class ResolveCheckRequest(BaseModel):
    """标记问题已解决的请求"""

    resolution_notes: str = Field(..., description="解决说明", min_length=1, max_length=1000)
    assigned_to: Optional[str] = Field(None, description="处理人")


# ==================== 响应Schemas ====================


class DataQualityCheckResponse(BaseModel):
    """数据质量检查记录响应"""

    id: int
    check_time: datetime
    check_type: str
    target_table: str
    target_column: Optional[str]
    severity: str
    total_records: int
    affected_records: int
    issue_details: Optional[Dict[str, Any]]
    status: str
    assigned_to: Optional[str]
    resolved_at: Optional[datetime]
    resolution_notes: Optional[str]

    class Config:
        from_attributes = True


class TableQualityScore(BaseModel):
    """表质量评分"""

    table_name: str
    score: float = Field(..., ge=0, le=100, description="质量评分（0-100）")
    total_records: int
    issue_count: int


class DataQualityOverviewResponse(BaseModel):
    """数据质量概览响应"""

    # 综合评分
    overall_score: float = Field(..., ge=0, le=100, description="综合质量评分")

    # 问题统计
    recent_issues: Dict[str, int] = Field(
        ...,
        description="按严重程度统计的问题数量",
        example={"critical": 2, "high": 5, "medium": 12, "low": 30},
    )

    # 各表质量评分
    by_table: List[TableQualityScore]

    # 最近的检查记录
    recent_checks: List[DataQualityCheckResponse]


class DataQualityChecksListResponse(BaseModel):
    """数据质量检查列表响应"""

    total: int = Field(..., description="总记录数")
    page: int = Field(..., description="当前页码")
    page_size: int = Field(..., description="每页大小")
    items: List[DataQualityCheckResponse]


class ResolveCheckResponse(BaseModel):
    """标记问题解决响应"""

    success: bool
    message: str
    check: DataQualityCheckResponse
