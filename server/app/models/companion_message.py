"""伙伴化消息库模型"""
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, String, Text, Integer, Float, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class CompanionMessageLibrary(Base):
    """AI生成的伙伴化消息库"""
    __tablename__ = 'companion_message_library'

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    scene_type = Column(String(50), nullable=False, index=True)
    emotion_type = Column(String(50), nullable=False, index=True)
    time_of_day = Column(String(20), nullable=True, index=True)
    content = Column(Text, nullable=False)
    language = Column(String(10), server_default='zh_CN', index=True)
    generation_method = Column(String(20), server_default='ai')  # 'ai' or 'manual'
    quality_score = Column(Float, nullable=True)
    usage_count = Column(Integer, server_default='0')
    positive_feedback = Column(Integer, server_default='0')
    negative_feedback = Column(Integer, server_default='0')
    is_active = Column(Boolean, server_default='true')
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_used_at = Column(DateTime, nullable=True)

    # 关系
    feedbacks = relationship('CompanionMessageFeedback', back_populates='message', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_companion_msg_scene_emotion', 'scene_type', 'emotion_type', 'language', 'is_active'),
    )

    def __repr__(self):
        return f'<CompanionMessageLibrary {self.scene_type}/{self.emotion_type}: {self.content[:30]}...>'


class CompanionMessageGenerationLog(Base):
    """消息生成日志"""
    __tablename__ = 'companion_message_generation_log'

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    batch_id = Column(String(50), nullable=False, index=True)
    scene_type = Column(String(50), nullable=False)
    emotion_type = Column(String(50), nullable=False)
    generated_count = Column(Integer, nullable=False)
    success_count = Column(Integer, nullable=False)
    failed_count = Column(Integer, nullable=False)
    generation_time_ms = Column(Integer, nullable=True)
    model_name = Column(String(100), nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self):
        return f'<CompanionMessageGenerationLog {self.batch_id}: {self.success_count}/{self.generated_count}>'


class CompanionMessageFeedback(Base):
    """用户反馈"""
    __tablename__ = 'companion_message_feedback'

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    message_id = Column(PGUUID(as_uuid=True), ForeignKey('companion_message_library.id', ondelete='CASCADE'), nullable=False)
    feedback_type = Column(String(20), nullable=False)  # 'like', 'dislike', 'report'
    feedback_reason = Column(String(100), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    # 关系
    message = relationship('CompanionMessageLibrary', back_populates='feedbacks')

    __table_args__ = (
        Index('idx_companion_feedback_user', 'user_id', 'created_at'),
    )

    def __repr__(self):
        return f'<CompanionMessageFeedback {self.feedback_type} by {self.user_id}>'
