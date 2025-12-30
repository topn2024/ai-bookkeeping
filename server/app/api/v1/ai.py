"""AI recognition endpoints."""
from typing import Optional, List
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel

from app.models.user import User
from app.api.deps import get_current_user
from app.services.ai_service import AIService


router = APIRouter(prefix="/ai", tags=["AI Recognition"])


class RecognitionResult(BaseModel):
    """Schema for AI recognition result."""
    amount: Optional[Decimal] = None
    category_name: Optional[str] = None
    category_type: Optional[int] = None  # 1: expense, 2: income
    note: Optional[str] = None
    merchant: Optional[str] = None
    date: Optional[str] = None
    confidence: Optional[float] = None
    raw_text: Optional[str] = None


@router.post("/recognize-image", response_model=RecognitionResult)
async def recognize_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Recognize receipt/bill from image."""
    # Validate file type
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image",
        )

    # Read file content
    content = await file.read()

    # Use AI service to recognize
    ai_service = AIService()
    result = await ai_service.recognize_image(content)

    return result


@router.post("/recognize-voice", response_model=RecognitionResult)
async def recognize_voice(
    text: str = Form(..., description="Voice transcription text"),
    current_user: User = Depends(get_current_user),
):
    """Parse transaction from voice text."""
    ai_service = AIService()
    result = await ai_service.parse_voice_text(text)

    return result


@router.post("/parse-text", response_model=RecognitionResult)
async def parse_text(
    text: str = Form(..., description="Text to parse for transaction"),
    current_user: User = Depends(get_current_user),
):
    """Parse transaction from text input."""
    ai_service = AIService()
    result = await ai_service.parse_voice_text(text)

    return result


class AudioRecognitionResult(BaseModel):
    """Schema for audio recognition result."""
    transcription: Optional[str] = None
    amount: Optional[Decimal] = None
    category_name: Optional[str] = None
    category_type: Optional[int] = None  # 1: expense, 2: income
    note: Optional[str] = None
    confidence: Optional[float] = None
    raw_text: Optional[str] = None
    success: bool = False
    error: Optional[str] = None


@router.post("/recognize-audio", response_model=AudioRecognitionResult)
async def recognize_audio(
    file: UploadFile = File(..., description="Audio file (mp3, wav, aac, m4a)"),
    current_user: User = Depends(get_current_user),
):
    """Recognize transaction from audio using Qwen-Audio-Turbo.

    This endpoint directly processes audio without pre-transcription,
    using Qwen's audio understanding capability for better accuracy.

    Supported formats: mp3, wav, aac, m4a, ogg, flac
    """
    # Validate file type
    allowed_types = ["audio/mpeg", "audio/wav", "audio/aac", "audio/m4a", "audio/ogg", "audio/flac", "audio/x-wav", "audio/mp3"]
    content_type = file.content_type or ""

    # Also check by extension
    filename = file.filename or ""
    extension = filename.split(".")[-1].lower() if "." in filename else ""
    allowed_extensions = ["mp3", "wav", "aac", "m4a", "ogg", "flac"]

    if content_type not in allowed_types and extension not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format. Allowed: {', '.join(allowed_extensions)}",
        )

    # Determine audio format for API
    audio_format = extension if extension in allowed_extensions else "mp3"

    # Read file content
    content = await file.read()

    # Validate file size (max 10MB)
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file too large. Max size: 10MB",
        )

    # Use AI service to recognize
    ai_service = AIService()
    result = await ai_service.recognize_voice_audio(content, audio_format)

    return AudioRecognitionResult(
        transcription=result.get("transcription"),
        amount=result.get("amount"),
        category_name=result.get("category_name"),
        category_type=result.get("category_type"),
        note=result.get("note"),
        confidence=result.get("confidence"),
        raw_text=result.get("raw_text"),
        success=result.get("success", False),
        error=result.get("error"),
    )


class BillTransaction(BaseModel):
    """Schema for a single bill transaction."""
    date: Optional[str] = None
    description: Optional[str] = None
    amount: Optional[Decimal] = None
    category: Optional[str] = None


class BillParseResult(BaseModel):
    """Schema for bill parsing result."""
    bank_name: Optional[str] = None
    card_number_last4: Optional[str] = None
    bill_date: Optional[str] = None
    due_date: Optional[str] = None
    total_amount: Optional[Decimal] = None
    min_payment: Optional[Decimal] = None
    previous_balance: Optional[Decimal] = None
    current_balance: Optional[Decimal] = None
    transactions: List[BillTransaction] = []
    is_bill: bool = False
    confidence: float = 0


@router.post("/parse-bill", response_model=BillParseResult)
async def parse_bill(
    content: str = Form(..., description="Email content (HTML or plain text)"),
    subject: str = Form("", description="Email subject"),
    sender: str = Form("", description="Email sender address"),
    current_user: User = Depends(get_current_user),
):
    """Parse credit card bill from email content.

    This endpoint analyzes email content and extracts:
    - Bank and card information
    - Bill dates and amounts
    - Individual transactions with categories
    """
    ai_service = AIService()
    result = await ai_service.parse_bill_email(
        email_content=content,
        email_subject=subject,
        sender=sender,
    )

    # Convert transactions to proper schema
    transactions = [
        BillTransaction(
            date=tx.get("date"),
            description=tx.get("description"),
            amount=tx.get("amount"),
            category=tx.get("category"),
        )
        for tx in result.get("transactions", [])
    ]

    return BillParseResult(
        bank_name=result.get("bank_name"),
        card_number_last4=result.get("card_number_last4"),
        bill_date=result.get("bill_date"),
        due_date=result.get("due_date"),
        total_amount=result.get("total_amount"),
        min_payment=result.get("min_payment"),
        previous_balance=result.get("previous_balance"),
        current_balance=result.get("current_balance"),
        transactions=transactions,
        is_bill=result.get("is_bill", False),
        confidence=result.get("confidence", 0),
    )
