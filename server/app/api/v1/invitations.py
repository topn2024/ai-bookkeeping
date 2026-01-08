"""Book invitation endpoints."""
import secrets
import random
from datetime import datetime, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_

from app.core.database import get_db
from app.core.timezone import beijing_now_naive
from app.models.user import User
from app.models.book import Book, BookMember, BookInvitation
from app.schemas.family import (
    InvitationCreate, InvitationResponse, InvitationAccept, InvitationAcceptResponse
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/books/{book_id}/invitations", tags=["Book Invitations"])


async def verify_book_admin_access(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
) -> Book:
    """Verify user has admin/owner access to the book."""
    # Check if user is owner
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == user_id)
    )
    book = result.scalar_one_or_none()
    if book:
        return book

    # Check if user is admin member
    result = await db.execute(
        select(BookMember).where(
            BookMember.book_id == book_id,
            BookMember.user_id == user_id,
            BookMember.role >= 2  # admin or owner
        )
    )
    member = result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )

    # Get book
    result = await db.execute(select(Book).where(Book.id == book_id))
    return result.scalar_one()


def generate_invite_code() -> str:
    """Generate a unique invitation code."""
    return secrets.token_urlsafe(12)


def generate_voice_code() -> str:
    """Generate a 6-digit voice code."""
    return ''.join([str(random.randint(0, 9)) for _ in range(6)])


def get_voice_code_semantic(code: str) -> str:
    """Generate semantic description for voice code."""
    spaced_code = ' '.join(code)
    return f"邀请码是 {spaced_code}，24小时内有效。请告诉对方在加入账本时输入此邀请码。"


@router.post("", response_model=InvitationResponse, status_code=status.HTTP_201_CREATED)
async def create_invitation(
    book_id: UUID,
    invitation_data: InvitationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new invitation for a book."""
    book = await verify_book_admin_access(db, book_id, current_user.id)

    # Check book settings for member invite permission
    settings = book.settings or {}
    if not settings.get("allow_member_invite", True):
        # Only owner can invite if allow_member_invite is False
        if book.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only book owner can invite members",
            )

    # Generate codes
    invite_code = generate_invite_code()
    voice_code = generate_voice_code() if invitation_data.generate_voice_code else None

    # Calculate expiry
    expires_at = beijing_now_naive() + timedelta(days=invitation_data.expires_in_days)

    invitation = BookInvitation(
        book_id=book_id,
        inviter_id=current_user.id,
        role=invitation_data.role,
        code=invite_code,
        voice_code=voice_code,
        max_uses=invitation_data.max_uses,
        expires_at=expires_at,
    )
    db.add(invitation)
    await db.commit()
    await db.refresh(invitation)

    return InvitationResponse(
        id=invitation.id,
        book_id=book_id,
        book_name=book.name,
        inviter_id=current_user.id,
        inviter_name=current_user.nickname,
        role=invitation.role,
        code=invitation.code,
        voice_code=invitation.voice_code,
        voice_code_semantic=get_voice_code_semantic(voice_code) if voice_code else None,
        status=invitation.status,
        max_uses=invitation.max_uses,
        used_count=invitation.used_count,
        created_at=invitation.created_at,
        expires_at=invitation.expires_at,
    )


@router.get("", response_model=list[InvitationResponse])
async def get_invitations(
    book_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all invitations for a book."""
    await verify_book_admin_access(db, book_id, current_user.id)

    result = await db.execute(
        select(BookInvitation, Book, User)
        .join(Book, BookInvitation.book_id == Book.id)
        .join(User, BookInvitation.inviter_id == User.id)
        .where(BookInvitation.book_id == book_id)
        .order_by(BookInvitation.created_at.desc())
    )
    rows = result.all()

    invitations = []
    for invitation, book, inviter in rows:
        invitations.append(InvitationResponse(
            id=invitation.id,
            book_id=invitation.book_id,
            book_name=book.name,
            inviter_id=invitation.inviter_id,
            inviter_name=inviter.nickname,
            role=invitation.role,
            code=invitation.code,
            voice_code=invitation.voice_code,
            voice_code_semantic=get_voice_code_semantic(invitation.voice_code) if invitation.voice_code else None,
            status=invitation.status,
            max_uses=invitation.max_uses,
            used_count=invitation.used_count,
            created_at=invitation.created_at,
            expires_at=invitation.expires_at,
        ))

    return invitations


@router.delete("/{invitation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_invitation(
    book_id: UUID,
    invitation_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke an invitation."""
    await verify_book_admin_access(db, book_id, current_user.id)

    result = await db.execute(
        select(BookInvitation).where(
            BookInvitation.id == invitation_id,
            BookInvitation.book_id == book_id,
        )
    )
    invitation = result.scalar_one_or_none()

    if not invitation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invitation not found",
        )

    invitation.status = 2  # revoked
    await db.commit()


# Public endpoint to accept invitation
accept_router = APIRouter(prefix="/invitations", tags=["Book Invitations"])


@accept_router.post("/accept", response_model=InvitationAcceptResponse)
async def accept_invitation(
    accept_data: InvitationAccept,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Accept a book invitation."""
    # Find invitation by code or voice_code
    result = await db.execute(
        select(BookInvitation, Book)
        .join(Book, BookInvitation.book_id == Book.id)
        .where(
            or_(
                BookInvitation.code == accept_data.code,
                BookInvitation.voice_code == accept_data.code,
            )
        )
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid invitation code",
        )

    invitation, book = row

    # Validate invitation
    if invitation.status != 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation is no longer valid",
        )

    if invitation.expires_at < beijing_now_naive():
        invitation.status = 1  # expired
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation has expired",
        )

    if invitation.max_uses and invitation.used_count >= invitation.max_uses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation has reached maximum uses",
        )

    # Check if user is already owner
    if book.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already the owner of this book",
        )

    # Check if user is already a member
    result = await db.execute(
        select(BookMember).where(
            BookMember.book_id == book.id,
            BookMember.user_id == current_user.id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of this book",
        )

    # Add member
    member = BookMember(
        book_id=book.id,
        user_id=current_user.id,
        role=invitation.role,
        nickname=accept_data.nickname,
        invited_by=invitation.inviter_id,
    )
    db.add(member)

    # Update invitation
    invitation.used_count += 1
    if invitation.max_uses and invitation.used_count >= invitation.max_uses:
        invitation.status = 3  # accepted (fully used)

    await db.commit()

    role_names = {0: "查看者", 1: "成员", 2: "管理员", 3: "所有者"}
    return InvitationAcceptResponse(
        success=True,
        book_id=book.id,
        book_name=book.name,
        role=invitation.role,
        message=f"成功加入「{book.name}」，你的角色是{role_names.get(invitation.role, '成员')}",
    )
