"""Email binding endpoints for managing email account connections."""
from typing import List, Optional
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import encrypt_sensitive_data
from app.models.user import User
from app.models.email_binding import EmailBinding, EmailType
from app.api.deps import get_current_user


router = APIRouter(prefix="/email-bindings", tags=["Email Bindings"])


# Request/Response schemas
class EmailBindingCreate(BaseModel):
    """Schema for creating email binding."""
    email: EmailStr
    email_type: int  # 1: Gmail, 2: Outlook, 3: QQ, 4: 163, 5: IMAP

    # For IMAP (QQ/163/custom)
    imap_server: Optional[str] = None
    imap_port: Optional[int] = 993
    imap_password: Optional[str] = None


class EmailBindingResponse(BaseModel):
    """Schema for email binding response."""
    id: UUID
    email: str
    email_type: int
    email_type_name: str
    imap_server: Optional[str] = None
    last_sync_at: Optional[datetime] = None
    sync_error: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class EmailBindingUpdate(BaseModel):
    """Schema for updating email binding."""
    imap_password: Optional[str] = None
    is_active: Optional[bool] = None


class SyncResult(BaseModel):
    """Schema for sync result."""
    success: bool
    emails_found: int
    bills_parsed: int
    message: str


@router.get("", response_model=List[EmailBindingResponse])
async def list_email_bindings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all email bindings for current user."""
    result = await db.execute(
        select(EmailBinding)
        .where(EmailBinding.user_id == current_user.id)
        .order_by(EmailBinding.created_at.desc())
    )
    bindings = result.scalars().all()

    return [
        EmailBindingResponse(
            id=b.id,
            email=b.email,
            email_type=b.email_type,
            email_type_name=EmailType.get_name(b.email_type),
            imap_server=b.imap_server,
            last_sync_at=b.last_sync_at,
            sync_error=b.sync_error,
            is_active=b.is_active,
            created_at=b.created_at,
        )
        for b in bindings
    ]


@router.post("", response_model=EmailBindingResponse, status_code=status.HTTP_201_CREATED)
async def create_email_binding(
    data: EmailBindingCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new email binding."""
    # Check if email is already bound
    result = await db.execute(
        select(EmailBinding).where(
            EmailBinding.user_id == current_user.id,
            EmailBinding.email == data.email,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email is already bound to your account",
        )

    # Validate IMAP settings for non-OAuth providers
    if data.email_type in [EmailType.QQ, EmailType.NETEASE_163, EmailType.IMAP]:
        if not data.imap_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="IMAP password is required for this email type",
            )

        # Set default IMAP servers for known providers
        if data.email_type == EmailType.QQ and not data.imap_server:
            data.imap_server = "imap.qq.com"
        elif data.email_type == EmailType.NETEASE_163 and not data.imap_server:
            data.imap_server = "imap.163.com"
        elif data.email_type == EmailType.IMAP and not data.imap_server:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="IMAP server is required for custom IMAP",
            )

    # Create binding
    # Encrypt IMAP password before storing
    encrypted_password = encrypt_sensitive_data(data.imap_password) if data.imap_password else None

    binding = EmailBinding(
        user_id=current_user.id,
        email=data.email,
        email_type=data.email_type,
        imap_server=data.imap_server,
        imap_port=data.imap_port or 993,
        imap_password=encrypted_password,
    )

    db.add(binding)
    await db.commit()
    await db.refresh(binding)

    return EmailBindingResponse(
        id=binding.id,
        email=binding.email,
        email_type=binding.email_type,
        email_type_name=EmailType.get_name(binding.email_type),
        imap_server=binding.imap_server,
        last_sync_at=binding.last_sync_at,
        sync_error=binding.sync_error,
        is_active=binding.is_active,
        created_at=binding.created_at,
    )


@router.get("/{binding_id}", response_model=EmailBindingResponse)
async def get_email_binding(
    binding_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific email binding."""
    result = await db.execute(
        select(EmailBinding).where(
            EmailBinding.id == binding_id,
            EmailBinding.user_id == current_user.id,
        )
    )
    binding = result.scalar_one_or_none()

    if not binding:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email binding not found",
        )

    return EmailBindingResponse(
        id=binding.id,
        email=binding.email,
        email_type=binding.email_type,
        email_type_name=EmailType.get_name(binding.email_type),
        imap_server=binding.imap_server,
        last_sync_at=binding.last_sync_at,
        sync_error=binding.sync_error,
        is_active=binding.is_active,
        created_at=binding.created_at,
    )


@router.patch("/{binding_id}", response_model=EmailBindingResponse)
async def update_email_binding(
    binding_id: UUID,
    data: EmailBindingUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update an email binding."""
    result = await db.execute(
        select(EmailBinding).where(
            EmailBinding.id == binding_id,
            EmailBinding.user_id == current_user.id,
        )
    )
    binding = result.scalar_one_or_none()

    if not binding:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email binding not found",
        )

    # Update fields
    if data.imap_password is not None:
        # Encrypt IMAP password before storing
        binding.imap_password = encrypt_sensitive_data(data.imap_password)
    if data.is_active is not None:
        binding.is_active = data.is_active

    binding.sync_error = None  # Clear error on update

    await db.commit()
    await db.refresh(binding)

    return EmailBindingResponse(
        id=binding.id,
        email=binding.email,
        email_type=binding.email_type,
        email_type_name=EmailType.get_name(binding.email_type),
        imap_server=binding.imap_server,
        last_sync_at=binding.last_sync_at,
        sync_error=binding.sync_error,
        is_active=binding.is_active,
        created_at=binding.created_at,
    )


@router.delete("/{binding_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_email_binding(
    binding_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete an email binding."""
    result = await db.execute(
        select(EmailBinding).where(
            EmailBinding.id == binding_id,
            EmailBinding.user_id == current_user.id,
        )
    )
    binding = result.scalar_one_or_none()

    if not binding:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email binding not found",
        )

    await db.delete(binding)
    await db.commit()


@router.post("/{binding_id}/sync", response_model=SyncResult)
async def sync_email_binding(
    binding_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Trigger email sync for a binding to fetch and parse bills."""
    from app.services.email_service import EmailService

    result = await db.execute(
        select(EmailBinding).where(
            EmailBinding.id == binding_id,
            EmailBinding.user_id == current_user.id,
        )
    )
    binding = result.scalar_one_or_none()

    if not binding:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email binding not found",
        )

    if not binding.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email binding is not active",
        )

    # Sync emails
    email_service = EmailService()
    try:
        sync_result = await email_service.sync_and_parse_bills(binding, db)

        # Update sync status
        binding.last_sync_at = datetime.utcnow()
        binding.sync_error = None
        await db.commit()

        return sync_result

    except Exception as e:
        # Update error status
        binding.sync_error = str(e)[:500]
        await db.commit()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )
