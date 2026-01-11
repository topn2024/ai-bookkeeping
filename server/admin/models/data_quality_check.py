"""数据质量检查记录模型"""
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Text, CheckConstraint, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class DataQualityCheck(Base):
    """数据质量检查记录"""

    __tablename__ = "data_quality_checks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    check_time = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    check_type = Column(
        String(50),
        nullable=False,
        comment="检查类型: null_check, range_check, consistency_check",
    )
    target_table = Column(String(100), nullable=False, comment="目标表名")
    target_column = Column(String(100), nullable=True, comment="目标字段名")
    severity = Column(
        String(20),
        nullable=False,
        comment="严重程度: low, medium, high, critical",
    )

    # 检查结果
    total_records = Column(Integer, nullable=False, comment="总记录数")
    affected_records = Column(Integer, nullable=False, comment="受影响记录数")
    issue_details = Column(JSONB, nullable=True, comment="问题详情")

    # 状态管理
    status = Column(
        String(20),
        nullable=False,
        default="detected",
        comment="状态: detected, investigating, fixed, ignored",
    )
    assigned_to = Column(String(100), nullable=True, comment="分配给")
    resolved_at = Column(DateTime, nullable=True, comment="解决时间")
    resolution_notes = Column(Text, nullable=True, comment="解决说明")

    # 约束
    __table_args__ = (
        CheckConstraint(
            "check_type IN ('null_check', 'range_check', 'consistency_check')",
            name="ck_data_quality_checks_type",
        ),
        CheckConstraint(
            "severity IN ('low', 'medium', 'high', 'critical')",
            name="ck_data_quality_checks_severity",
        ),
        CheckConstraint(
            "status IN ('detected', 'investigating', 'fixed', 'ignored')",
            name="ck_data_quality_checks_status",
        ),
        Index("idx_data_quality_checks_check_time", "check_time"),
        Index("idx_data_quality_checks_status", "status"),
        Index("idx_data_quality_checks_severity", "severity"),
        Index("idx_data_quality_checks_target", "target_table", "target_column"),
    )

    def __repr__(self):
        return (
            f"<DataQualityCheck(id={self.id}, "
            f"check_type={self.check_type}, "
            f"target_table={self.target_table}, "
            f"severity={self.severity}, "
            f"status={self.status})>"
        )
