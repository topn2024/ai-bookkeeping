"""Book member endpoints."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book, BookMember
from app.schemas.book_member import BookMemberCreate, BookMemberUpdate, BookMemberResponse, BookMemberList
from app.api.deps import get_current_user


router = APIRouter(prefix="/books/{book_id}/members", tags=["Book Members"])


async def verify_book_access(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
    require_admin: bool = False,
) -> Book:
    """Verify user has access to the book."""
    # Check if user is owner
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == user_id)
    )
    book = result.scalar_one_or_none()
    if book:
        return book

    # Check if user is a member
    result = await db.execute(
        select(BookMember).where(
            BookMember.book_id == book_id,
            BookMember.user_id == user_id,
        )
    )
    member = result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found or access denied",
        )

    if require_admin and member.role < 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )

    # Get book
    result = await db.execute(select(Book).where(Book.id == book_id))
    return result.scalar_one()


@router.get("", response_model=BookMemberList)
async def get_book_members(
    book_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all members of a book."""
    await verify_book_access(db, book_id, current_user.id)

    # Get owner
    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one()

    # Get owner user info
    result = await db.execute(select(User).where(User.id == book.user_id))
    owner = result.scalar_one()

    members = [
        BookMemberResponse(
            id=book.id,  # Use book id as pseudo-member id for owner
            book_id=book.id,
            user_id=owner.id,
            role=2,  # Owner
            nickname=owner.nickname,
            joined_at=book.created_at,
        )
    ]

    # Get other members
    result = await db.execute(
        select(BookMember, User)
        .join(User, BookMember.user_id == User.id)
        .where(BookMember.book_id == book_id)
    )
    rows = result.all()

    for member, user in rows:
        members.append(
            BookMemberResponse(
                id=member.id,
                book_id=member.book_id,
                user_id=member.user_id,
                role=member.role,
                nickname=user.nickname,
                joined_at=member.joined_at,
            )
        )

    return BookMemberList(items=members, total=len(members))


@router.post("", response_model=BookMemberResponse, status_code=status.HTTP_201_CREATED)
async def add_book_member(
    book_id: UUID,
    member_data: BookMemberCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a member to a book. Requires admin/owner access."""
    book = await verify_book_access(db, book_id, current_user.id, require_admin=True)

    # Can't add self
    if member_data.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot add yourself as a member",
        )

    # Can't add owner
    if member_data.user_id == book.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already the owner",
        )

    # Check if user exists
    result = await db.execute(select(User).where(User.id == member_data.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found",
        )

    # Check if already a member
    result = await db.execute(
        select(BookMember).where(
            BookMember.book_id == book_id,
            BookMember.user_id == member_data.user_id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member",
        )

    # Create member
    member = BookMember(
        book_id=book_id,
        user_id=member_data.user_id,
        role=member_data.role,
    )
    db.add(member)
    await db.commit()
    await db.refresh(member)

    return BookMemberResponse(
        id=member.id,
        book_id=member.book_id,
        user_id=member.user_id,
        role=member.role,
        nickname=user.nickname,
        joined_at=member.joined_at,
    )


@router.put("/{member_id}", response_model=BookMemberResponse)
async def update_book_member(
    book_id: UUID,
    member_id: UUID,
    member_data: BookMemberUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a member's role. Requires admin/owner access."""
    await verify_book_access(db, book_id, current_user.id, require_admin=True)

    # Get member
    result = await db.execute(
        select(BookMember).where(BookMember.id == member_id, BookMember.book_id == book_id)
    )
    member = result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found",
        )

    member.role = member_data.role
    await db.commit()
    await db.refresh(member)

    # Get user info
    result = await db.execute(select(User).where(User.id == member.user_id))
    user = result.scalar_one()

    return BookMemberResponse(
        id=member.id,
        book_id=member.book_id,
        user_id=member.user_id,
        role=member.role,
        nickname=user.nickname,
        joined_at=member.joined_at,
    )


@router.delete("/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_book_member(
    book_id: UUID,
    member_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a member from a book. Requires admin/owner access or self-removal."""
    # Get member first
    result = await db.execute(
        select(BookMember).where(BookMember.id == member_id, BookMember.book_id == book_id)
    )
    member = result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found",
        )

    # Allow self-removal
    if member.user_id != current_user.id:
        await verify_book_access(db, book_id, current_user.id, require_admin=True)

    await db.delete(member)
    await db.commit()
