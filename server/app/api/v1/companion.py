"""伙伴化消息API端点"""
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from pydantic import BaseModel

from app.core.database import get_db
from app.models.companion_message import (
    CompanionMessageLibrary,
    CompanionMessageFeedback,
)
from app.services.companion_message_generator import CompanionMessageGenerator
from app.services.llm_service import LLMService
from app.api.deps import get_llm_service

router = APIRouter(prefix="/api/v1/companion", tags=["companion"])


# ==================== Schemas ====================

class CompanionMessageResponse(BaseModel):
    id: UUID
    content: str
    scene_type: str
    emotion_type: str
    time_of_day: Optional[str]
    quality_score: Optional[float]

    class Config:
        from_attributes = True


class CompanionMessagesListResponse(BaseModel):
    messages: List[CompanionMessageResponse]
    total: int


class MessageFeedbackRequest(BaseModel):
    message_id: UUID
    feedback_type: str  # 'like', 'dislike', 'report'
    feedback_reason: Optional[str] = None


class RefreshRequest(BaseModel):
    messages_per_scene: int = 10


# ==================== Endpoints ====================

@router.get("/messages", response_model=CompanionMessagesListResponse)
async def get_companion_messages(
    scene_type: str = Query(..., description="场景类型"),
    emotion_type: str = Query(..., description="情感类型"),
    time_of_day: Optional[str] = Query(None, description="时间段"),
    language: str = Query("zh_CN", description="语言"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: AsyncSession = Depends(get_db),
):
    """获取指定场景和情感的伙伴化消息"""
    # 构建查询
    conditions = [
        CompanionMessageLibrary.scene_type == scene_type,
        CompanionMessageLibrary.emotion_type == emotion_type,
        CompanionMessageLibrary.language == language,
        CompanionMessageLibrary.is_active == True,
    ]

    if time_of_day:
        conditions.append(CompanionMessageLibrary.time_of_day == time_of_day)

    stmt = (
        select(CompanionMessageLibrary)
        .where(and_(*conditions))
        .order_by(func.random())  # 随机排序
        .limit(limit)
    )

    result = await db.execute(stmt)
    messages = result.scalars().all()

    # 更新使用次数和最后使用时间
    for msg in messages:
        msg.usage_count += 1
        msg.last_used_at = func.now()

    await db.commit()

    return CompanionMessagesListResponse(
        messages=[CompanionMessageResponse.from_orm(msg) for msg in messages],
        total=len(messages),
    )


@router.post("/feedback")
async def submit_feedback(
    feedback: MessageFeedbackRequest,
    user_id: UUID = Query(..., description="用户ID"),
    db: AsyncSession = Depends(get_db),
):
    """提交消息反馈"""
    # 检查消息是否存在
    stmt = select(CompanionMessageLibrary).where(
        CompanionMessageLibrary.id == feedback.message_id
    )
    result = await db.execute(stmt)
    message = result.scalar_one_or_none()

    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    # 创建反馈记录
    feedback_record = CompanionMessageFeedback(
        user_id=user_id,
        message_id=feedback.message_id,
        feedback_type=feedback.feedback_type,
        feedback_reason=feedback.feedback_reason,
    )
    db.add(feedback_record)

    # 更新消息的反馈计数
    if feedback.feedback_type == 'like':
        message.positive_feedback += 1
    elif feedback.feedback_type == 'dislike':
        message.negative_feedback += 1

    await db.commit()

    return {"status": "success", "message": "Feedback submitted"}


@router.post("/refresh")
async def trigger_refresh(
    request: RefreshRequest,
    db: AsyncSession = Depends(get_db),
    llm_service: LLMService = Depends(get_llm_service),
):
    """手动触发消息库刷新（管理员功能）"""
    generator = CompanionMessageGenerator(llm_service)

    results = await generator.refresh_all_scenes(
        db=db,
        messages_per_scene=request.messages_per_scene,
    )

    return {
        "status": "success",
        "results": results,
    }


@router.get("/stats")
async def get_stats(
    db: AsyncSession = Depends(get_db),
):
    """获取消息库统计信息"""
    # 总消息数
    total_stmt = select(func.count(CompanionMessageLibrary.id))
    total_result = await db.execute(total_stmt)
    total_messages = total_result.scalar()

    # 活跃消息数
    active_stmt = select(func.count(CompanionMessageLibrary.id)).where(
        CompanionMessageLibrary.is_active == True
    )
    active_result = await db.execute(active_stmt)
    active_messages = active_result.scalar()

    # 按场景统计
    scene_stmt = select(
        CompanionMessageLibrary.scene_type,
        func.count(CompanionMessageLibrary.id).label('count')
    ).group_by(CompanionMessageLibrary.scene_type)
    scene_result = await db.execute(scene_stmt)
    scene_stats = {row[0]: row[1] for row in scene_result}

    # 总使用次数
    usage_stmt = select(func.sum(CompanionMessageLibrary.usage_count))
    usage_result = await db.execute(usage_stmt)
    total_usage = usage_result.scalar() or 0

    # 反馈统计
    feedback_stmt = select(
        func.sum(CompanionMessageLibrary.positive_feedback).label('positive'),
        func.sum(CompanionMessageLibrary.negative_feedback).label('negative'),
    )
    feedback_result = await db.execute(feedback_stmt)
    feedback_row = feedback_result.one()

    return {
        "total_messages": total_messages,
        "active_messages": active_messages,
        "scene_stats": scene_stats,
        "total_usage": total_usage,
        "feedback": {
            "positive": feedback_row[0] or 0,
            "negative": feedback_row[1] or 0,
        },
    }
