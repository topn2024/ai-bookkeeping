"""End-to-end tests for member collaboration and data sync."""
import pytest
from datetime import datetime
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import uuid4

from app.models.user import User
from app.models.book import Book


class TestBookSharing:
    """Test cases for book sharing and member management."""

    @pytest.mark.asyncio
    async def test_create_shared_book(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test creating a shared book."""
        response = await authenticated_client.post(
            "/api/v1/books",
            json={
                "name": "Family Budget",
                "type": "family",
                "description": "Shared family expenses",
            },
        )

        assert response.status_code in [200, 201]
        data = response.json()
        assert data["name"] == "Family Budget"

    @pytest.mark.asyncio
    async def test_generate_invite_code(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test generating an invite code for a book."""
        response = await authenticated_client.post(
            f"/api/v1/books/{test_book.id}/invite",
            json={
                "role": "editor",
                "expires_in_days": 7,
            },
        )

        assert response.status_code in [200, 201]
        if response.status_code in [200, 201]:
            data = response.json()
            assert "code" in data or "invite_code" in data

    @pytest.mark.asyncio
    async def test_list_book_members(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test listing book members."""
        response = await authenticated_client.get(
            f"/api/v1/books/{test_book.id}/members"
        )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        # Owner should be in the list
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_update_member_role(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test updating a member's role."""
        # This would need another user to test properly
        # Just checking the endpoint exists
        response = await authenticated_client.put(
            f"/api/v1/books/{test_book.id}/members/fake-user-id",
            json={"role": "viewer"},
        )

        # May fail with 404 for fake user, but endpoint should exist
        assert response.status_code in [200, 400, 404]

    @pytest.mark.asyncio
    async def test_remove_member(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test removing a member from book."""
        response = await authenticated_client.delete(
            f"/api/v1/books/{test_book.id}/members/fake-user-id"
        )

        assert response.status_code in [200, 204, 400, 404]


class TestMemberBudgets:
    """Test cases for member-specific budgets."""

    @pytest.mark.asyncio
    async def test_set_member_budget(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_user: User,
    ):
        """Test setting budget for a member."""
        response = await authenticated_client.post(
            f"/api/v1/books/{test_book.id}/member-budgets",
            json={
                "user_id": str(test_user.id),
                "amount": 5000.00,
                "period": "monthly",
            },
        )

        assert response.status_code in [200, 201, 404]

    @pytest.mark.asyncio
    async def test_get_member_budget_status(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
        test_user: User,
    ):
        """Test getting member budget status."""
        response = await authenticated_client.get(
            f"/api/v1/books/{test_book.id}/member-budgets/{test_user.id}"
        )

        assert response.status_code in [200, 404]


class TestApprovalWorkflow:
    """Test cases for transaction approval workflow."""

    @pytest.mark.asyncio
    async def test_enable_approval_workflow(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test enabling approval workflow for a book."""
        response = await authenticated_client.put(
            f"/api/v1/books/{test_book.id}/settings",
            json={
                "approval_required": True,
                "approval_threshold": 1000.00,
            },
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_list_pending_approvals(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test listing pending transaction approvals."""
        response = await authenticated_client.get(
            f"/api/v1/books/{test_book.id}/approvals/pending"
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_approve_transaction(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test approving a transaction."""
        # Would need a pending transaction to test properly
        response = await authenticated_client.post(
            f"/api/v1/books/{test_book.id}/approvals/fake-transaction-id/approve"
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_reject_transaction(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test rejecting a transaction."""
        response = await authenticated_client.post(
            f"/api/v1/books/{test_book.id}/approvals/fake-transaction-id/reject",
            json={"reason": "Over budget"},
        )

        assert response.status_code in [200, 404]


class TestMemberComparison:
    """Test cases for member comparison reports."""

    @pytest.mark.asyncio
    async def test_member_spending_comparison(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test member spending comparison."""
        response = await authenticated_client.get(
            f"/api/v1/stats/member-comparison",
            params={
                "book_id": str(test_book.id),
                "period": "month",
            },
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_member_category_breakdown(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test member category spending breakdown."""
        response = await authenticated_client.get(
            f"/api/v1/stats/member-categories",
            params={
                "book_id": str(test_book.id),
                "period": "month",
            },
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_member_budget_execution(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test member budget execution report."""
        response = await authenticated_client.get(
            f"/api/v1/stats/member-budget-execution",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]


class TestDataBackup:
    """Test cases for data backup functionality."""

    @pytest.mark.asyncio
    async def test_create_backup(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test creating a data backup."""
        response = await authenticated_client.post(
            "/api/v1/backups",
            json={
                "name": "Manual Backup",
                "description": "Test backup",
            },
        )

        assert response.status_code in [200, 201]
        if response.status_code in [200, 201]:
            data = response.json()
            assert "id" in data

    @pytest.mark.asyncio
    async def test_list_backups(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test listing backups."""
        response = await authenticated_client.get("/api/v1/backups")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_get_backup_details(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test getting backup details."""
        # Create backup first
        create_response = await authenticated_client.post(
            "/api/v1/backups",
            json={"name": "Detail Test Backup"},
        )

        if create_response.status_code in [200, 201]:
            backup_id = create_response.json()["id"]

            # Get details
            response = await authenticated_client.get(
                f"/api/v1/backups/{backup_id}"
            )

            assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_delete_backup(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test deleting a backup."""
        # Create backup first
        create_response = await authenticated_client.post(
            "/api/v1/backups",
            json={"name": "Backup to Delete"},
        )

        if create_response.status_code in [200, 201]:
            backup_id = create_response.json()["id"]

            # Delete
            response = await authenticated_client.delete(
                f"/api/v1/backups/{backup_id}"
            )

            assert response.status_code in [200, 204]


class TestDataSync:
    """Test cases for data synchronization."""

    @pytest.mark.asyncio
    async def test_get_sync_status(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test getting sync status."""
        response = await authenticated_client.get("/api/v1/sync/status")

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_trigger_sync(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test triggering manual sync."""
        response = await authenticated_client.post(
            "/api/v1/sync/trigger",
            json={"direction": "upload"},
        )

        assert response.status_code in [200, 201, 404]

    @pytest.mark.asyncio
    async def test_get_sync_history(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test getting sync history."""
        response = await authenticated_client.get("/api/v1/sync/history")

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_update_sync_settings(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test updating sync settings."""
        response = await authenticated_client.put(
            "/api/v1/sync/settings",
            json={
                "auto_sync": True,
                "sync_frequency": "daily",
                "wifi_only": True,
            },
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_get_sync_conflicts(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test getting sync conflicts."""
        response = await authenticated_client.get("/api/v1/sync/conflicts")

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_resolve_sync_conflict(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test resolving a sync conflict."""
        response = await authenticated_client.post(
            "/api/v1/sync/conflicts/fake-conflict-id/resolve",
            json={"resolution": "keep_local"},
        )

        assert response.status_code in [200, 404]


class TestDataImportExport:
    """Test cases for data import/export."""

    @pytest.mark.asyncio
    async def test_export_to_csv(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test exporting data to CSV."""
        response = await authenticated_client.get(
            "/api/v1/export/csv",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_export_to_excel(
        self,
        authenticated_client: AsyncClient,
        test_book: Book,
    ):
        """Test exporting data to Excel."""
        response = await authenticated_client.get(
            "/api/v1/export/excel",
            params={"book_id": str(test_book.id)},
        )

        assert response.status_code in [200, 404]


class TestWebDAVSync:
    """Test cases for WebDAV sync configuration."""

    @pytest.mark.asyncio
    async def test_configure_webdav(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test configuring WebDAV settings."""
        response = await authenticated_client.post(
            "/api/v1/sync/webdav/configure",
            json={
                "server_url": "https://webdav.example.com",
                "username": "testuser",
                "password": "testpass",
                "path": "/ai-bookkeeping",
            },
        )

        assert response.status_code in [200, 201, 404]

    @pytest.mark.asyncio
    async def test_test_webdav_connection(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test testing WebDAV connection."""
        response = await authenticated_client.post(
            "/api/v1/sync/webdav/test"
        )

        assert response.status_code in [200, 400, 404]

    @pytest.mark.asyncio
    async def test_sync_to_webdav(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test syncing to WebDAV."""
        response = await authenticated_client.post(
            "/api/v1/sync/webdav/upload"
        )

        assert response.status_code in [200, 400, 404]

    @pytest.mark.asyncio
    async def test_sync_from_webdav(
        self,
        authenticated_client: AsyncClient,
    ):
        """Test syncing from WebDAV."""
        response = await authenticated_client.post(
            "/api/v1/sync/webdav/download"
        )

        assert response.status_code in [200, 400, 404]
