"""Book endpoints."""
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.schemas.book import BookCreate, BookUpdate, BookResponse
from app.api.deps import get_current_user


router = APIRouter(prefix="/books", tags=["Books"])


@router.get("", response_model=List[BookResponse])
async def get_books(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all books for current user."""
    result = await db.execute(
        select(Book).where(Book.user_id == current_user.id).order_by(Book.created_at.desc())
    )
    books = result.scalars().all()
    return [BookResponse.model_validate(book) for book in books]


@router.post("", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
async def create_book(
    book_data: BookCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new book."""
    # If setting as default, unset other defaults
    if book_data.is_default:
        await db.execute(
            update(Book).where(Book.user_id == current_user.id).values(is_default=False)
        )

    book = Book(
        user_id=current_user.id,
        name=book_data.name,
        icon=book_data.icon,
        cover_image=book_data.cover_image,
        book_type=book_data.book_type,
        is_default=book_data.is_default,
    )
    db.add(book)
    await db.commit()
    await db.refresh(book)

    return BookResponse.model_validate(book)


@router.get("/{book_id}", response_model=BookResponse)
async def get_book(
    book_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific book."""
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == current_user.id)
    )
    book = result.scalar_one_or_none()

    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found",
        )

    return BookResponse.model_validate(book)


@router.put("/{book_id}", response_model=BookResponse)
async def update_book(
    book_id: UUID,
    book_data: BookUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a book."""
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == current_user.id)
    )
    book = result.scalar_one_or_none()

    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found",
        )

    # If setting as default, unset other defaults
    if book_data.is_default:
        await db.execute(
            update(Book).where(Book.user_id == current_user.id, Book.id != book_id).values(is_default=False)
        )

    # Update fields
    update_data = book_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(book, field, value)

    await db.commit()
    await db.refresh(book)

    return BookResponse.model_validate(book)


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_book(
    book_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a book."""
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == current_user.id)
    )
    book = result.scalar_one_or_none()

    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found",
        )

    if book.is_default:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete default book",
        )

    await db.delete(book)
    await db.commit()
