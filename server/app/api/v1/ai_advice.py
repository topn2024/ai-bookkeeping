"""AI-generated advice and content endpoints."""
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.database import get_db
from app.models.user import User
from app.api.deps import get_current_user, get_llm_service
from app.services.llm_service import LLMService
from app.services.category_suggestion_generator import CategorySuggestionGenerator
from app.services.budget_allocation_optimizer import BudgetAllocationOptimizer
from app.services.financial_advice_generator import FinancialAdviceGenerator
from app.services.content_generators import (
    SavingsAdviceGenerator,
    AchievementDescriptionGenerator,
    AnnualReportGenerator,
)
from app.services.location_and_bill_generators import (
    LocationBasedAdviceGenerator,
    BillReminderGenerator,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/ai-advice", tags=["AI Advice"])


# ==================== Schemas ====================

class CategorySuggestionRequest(BaseModel):
    description: str
    amount: float
    merchant: Optional[str] = None
    time: Optional[datetime] = None
    location: Optional[str] = None
    user_history: Optional[List[Dict[str, Any]]] = None


class CategorySuggestionResponse(BaseModel):
    category: str
    confidence: float
    reason: str


class BudgetOptimizationRequest(BaseModel):
    monthly_income: float
    historical_expenses: Dict[str, float]
    financial_goals: Optional[List[Dict[str, Any]]] = None
    user_preferences: Optional[Dict[str, Any]] = None


class BudgetAllocationResponse(BaseModel):
    allocations: Dict[str, Any]
    category_budgets: Dict[str, float]
    reasoning: str
    tips: List[str]


class FinancialAdviceRequest(BaseModel):
    advice_type: str  # 'budget_warning', 'overspending', 'money_age', 'savings', 'category_insight'
    params: Dict[str, Any]


class SavingsPlanRequest(BaseModel):
    goal_name: str
    target_amount: float
    current_amount: float
    deadline: datetime
    monthly_income: float
    monthly_expense: float


class AchievementRequest(BaseModel):
    achievement_type: str
    achievement_data: Dict[str, Any]
    user_name: Optional[str] = None


class AnnualReportRequest(BaseModel):
    year: int
    total_income: float
    total_expense: float
    category_breakdown: Dict[str, float]
    highlights: List[str]
    user_name: Optional[str] = None


class LocationAdviceRequest(BaseModel):
    location_name: str
    spending_data: Dict[str, Any]
    nearby_alternatives: Optional[List[Dict[str, Any]]] = None


class BillReminderRequest(BaseModel):
    bill_type: str
    bill_name: str
    amount: float
    due_date: datetime
    account_balance: Optional[float] = None


class RepaymentStrategyRequest(BaseModel):
    bills: List[Dict[str, Any]]
    available_amount: float


# ==================== Endpoints ====================

@router.post("/suggest-category", response_model=CategorySuggestionResponse)
async def suggest_category(
    request: CategorySuggestionRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """AI-powered transaction category suggestion."""
    generator = CategorySuggestionGenerator(llm_service)

    result = await generator.suggest_category(
        description=request.description,
        amount=request.amount,
        merchant=request.merchant,
        time=request.time,
        location=request.location,
        user_history=request.user_history,
    )

    return CategorySuggestionResponse(**result)


@router.post("/optimize-budget", response_model=BudgetAllocationResponse)
async def optimize_budget(
    request: BudgetOptimizationRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Optimize budget allocation based on income and goals."""
    optimizer = BudgetAllocationOptimizer(llm_service)

    result = await optimizer.optimize_allocation(
        monthly_income=request.monthly_income,
        historical_expenses=request.historical_expenses,
        financial_goals=request.financial_goals,
        user_preferences=request.user_preferences,
    )

    return BudgetAllocationResponse(**result)


@router.post("/financial-advice")
async def generate_financial_advice(
    request: FinancialAdviceRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate personalized financial advice."""
    generator = FinancialAdviceGenerator(llm_service)

    advice_type = request.advice_type
    params = request.params

    if advice_type == 'budget_warning':
        result = await generator.generate_budget_warning_advice(**params)
    elif advice_type == 'overspending':
        result = await generator.generate_overspending_advice(**params)
    elif advice_type == 'money_age':
        result = await generator.generate_money_age_advice(**params)
    elif advice_type == 'savings':
        result = await generator.generate_savings_advice(**params)
    elif advice_type == 'category_insight':
        result = await generator.generate_category_insight(**params)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown advice type: {advice_type}")

    return {"advice": result}


@router.post("/savings-plan")
async def generate_savings_plan(
    request: SavingsPlanRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate personalized savings plan."""
    generator = SavingsAdviceGenerator(llm_service)

    result = await generator.generate_savings_plan(
        goal_name=request.goal_name,
        target_amount=request.target_amount,
        current_amount=request.current_amount,
        deadline=request.deadline,
        monthly_income=request.monthly_income,
        monthly_expense=request.monthly_expense,
    )

    return result


@router.post("/achievement-description")
async def generate_achievement_description(
    request: AchievementRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate celebratory achievement description."""
    generator = AchievementDescriptionGenerator(llm_service)

    result = await generator.generate_description(
        achievement_type=request.achievement_type,
        achievement_data=request.achievement_data,
        user_name=request.user_name,
    )

    return {"description": result}


@router.post("/annual-report")
async def generate_annual_report(
    request: AnnualReportRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate comprehensive annual financial report."""
    generator = AnnualReportGenerator(llm_service)

    result = await generator.generate_summary(
        year=request.year,
        total_income=request.total_income,
        total_expense=request.total_expense,
        category_breakdown=request.category_breakdown,
        highlights=request.highlights,
        user_name=request.user_name,
    )

    return result


@router.post("/location-advice")
async def generate_location_advice(
    request: LocationAdviceRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate location-based spending advice."""
    generator = LocationBasedAdviceGenerator(llm_service)

    result = await generator.generate_location_insight(
        location_name=request.location_name,
        spending_data=request.spending_data,
        nearby_alternatives=request.nearby_alternatives,
    )

    return {"advice": result}


@router.post("/bill-reminder")
async def generate_bill_reminder(
    request: BillReminderRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate smart bill reminder."""
    generator = BillReminderGenerator(llm_service)

    result = await generator.generate_reminder(
        bill_type=request.bill_type,
        bill_name=request.bill_name,
        amount=request.amount,
        due_date=request.due_date,
        account_balance=request.account_balance,
    )

    return result


@router.post("/repayment-strategy")
async def generate_repayment_strategy(
    request: RepaymentStrategyRequest,
    current_user: User = Depends(get_current_user),
    llm_service: LLMService = Depends(get_llm_service),
):
    """Generate optimal bill repayment strategy."""
    generator = BillReminderGenerator(llm_service)

    result = await generator.generate_repayment_strategy(
        bills=request.bills,
        available_amount=request.available_amount,
    )

    return result
