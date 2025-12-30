"""
Admin API Test Suite
Tests for the admin management platform backend API
"""
import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
import json


class TestAdminAuth:
    """Tests for admin authentication endpoints"""

    def test_admin_login_success(self, client: TestClient, mock_admin):
        """Test successful admin login"""
        response = client.post(
            "/admin/auth/login",
            json={"username": "admin", "password": "admin123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "admin" in data
        assert data["admin"]["username"] == "admin"

    def test_admin_login_invalid_credentials(self, client: TestClient):
        """Test login with invalid credentials"""
        response = client.post(
            "/admin/auth/login",
            json={"username": "admin", "password": "wrongpassword"}
        )
        assert response.status_code == 401

    def test_admin_login_mfa_required(self, client: TestClient, mock_admin_with_mfa):
        """Test login when MFA is required"""
        response = client.post(
            "/admin/auth/login",
            json={"username": "admin_mfa", "password": "admin123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "mfa_required" in data
        assert data["mfa_required"] is True

    def test_admin_logout(self, client: TestClient, admin_token):
        """Test admin logout"""
        response = client.post(
            "/admin/auth/logout",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_current_admin(self, client: TestClient, admin_token):
        """Test getting current admin info"""
        response = client.get(
            "/admin/auth/me",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "username" in data
        assert "permissions" in data


class TestDashboard:
    """Tests for dashboard endpoints"""

    def test_get_dashboard_stats(self, client: TestClient, admin_token):
        """Test getting dashboard statistics"""
        response = client.get(
            "/admin/dashboard/stats",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "total_users" in data
        assert "active_users" in data
        assert "total_transactions" in data

    def test_get_user_trend(self, client: TestClient, admin_token):
        """Test getting user growth trend"""
        response = client.get(
            "/admin/dashboard/user-trend?days=7",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "dates" in data
        assert "new_users" in data
        assert "active_users" in data

    def test_get_activity_heatmap(self, client: TestClient, admin_token):
        """Test getting activity heatmap data"""
        response = client.get(
            "/admin/dashboard/heatmap",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "heatmap" in data


class TestUserManagement:
    """Tests for user management endpoints"""

    def test_get_users_list(self, client: TestClient, admin_token):
        """Test getting paginated user list"""
        response = client.get(
            "/admin/users?page=1&page_size=10",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data
        assert "page" in data

    def test_get_users_with_filters(self, client: TestClient, admin_token):
        """Test getting users with filters"""
        response = client.get(
            "/admin/users?status=active&keyword=test",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data

    def test_get_user_detail(self, client: TestClient, admin_token, mock_user):
        """Test getting user detail"""
        response = client.get(
            f"/admin/users/{mock_user.id}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert "stats" in data
        assert "recent_transactions" in data

    def test_disable_user(self, client: TestClient, admin_token, mock_user):
        """Test disabling a user"""
        response = client.post(
            f"/admin/users/{mock_user.id}/disable",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_enable_user(self, client: TestClient, admin_token, mock_disabled_user):
        """Test enabling a user"""
        response = client.post(
            f"/admin/users/{mock_disabled_user.id}/enable",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_delete_user(self, client: TestClient, admin_token, mock_user):
        """Test deleting a user"""
        response = client.delete(
            f"/admin/users/{mock_user.id}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_batch_user_operations(self, client: TestClient, admin_token, mock_users):
        """Test batch user operations"""
        user_ids = [u.id for u in mock_users[:3]]
        response = client.post(
            "/admin/users/batch",
            json={"user_ids": user_ids, "action": "disable"},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_export_users(self, client: TestClient, admin_token):
        """Test exporting users"""
        response = client.get(
            "/admin/users/export?format=xlsx",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class TestDataManagement:
    """Tests for data management endpoints"""

    def test_get_transactions(self, client: TestClient, admin_token):
        """Test getting transactions"""
        response = client.get(
            "/admin/data/transactions?page=1&page_size=20",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    def test_get_transactions_with_filters(self, client: TestClient, admin_token):
        """Test getting transactions with filters"""
        response = client.get(
            "/admin/data/transactions?type=expense&min_amount=100",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_books(self, client: TestClient, admin_token):
        """Test getting books"""
        response = client.get(
            "/admin/data/books",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_categories(self, client: TestClient, admin_token):
        """Test getting categories"""
        response = client.get(
            "/admin/data/categories",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_backups(self, client: TestClient, admin_token):
        """Test getting backups"""
        response = client.get(
            "/admin/data/backups",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_create_backup(self, client: TestClient, admin_token):
        """Test creating a backup"""
        response = client.post(
            "/admin/data/backups",
            json={"type": "full", "expires_days": 30},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code in [200, 201, 202]


class TestStatistics:
    """Tests for statistics endpoints"""

    def test_get_user_stats(self, client: TestClient, admin_token):
        """Test getting user statistics"""
        response = client.get(
            "/admin/statistics/users?days=30",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "total_users" in data

    def test_get_transaction_stats(self, client: TestClient, admin_token):
        """Test getting transaction statistics"""
        response = client.get(
            "/admin/statistics/transactions?days=30",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_retention_analysis(self, client: TestClient, admin_token):
        """Test getting retention analysis"""
        response = client.get(
            "/admin/statistics/retention?days=30",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_cohort_analysis(self, client: TestClient, admin_token):
        """Test getting cohort analysis"""
        response = client.get(
            "/admin/statistics/cohort",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_reports(self, client: TestClient, admin_token):
        """Test getting reports list"""
        response = client.get(
            "/admin/statistics/reports",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200


class TestMonitoring:
    """Tests for system monitoring endpoints"""

    def test_get_system_health(self, client: TestClient, admin_token):
        """Test getting system health"""
        response = client.get(
            "/admin/monitor/health",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "services" in data

    def test_get_system_resources(self, client: TestClient, admin_token):
        """Test getting system resources"""
        response = client.get(
            "/admin/monitor/resources",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "resources" in data

    def test_get_active_alerts(self, client: TestClient, admin_token):
        """Test getting active alerts"""
        response = client.get(
            "/admin/monitor/alerts",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_alert_rules(self, client: TestClient, admin_token):
        """Test getting alert rules"""
        response = client.get(
            "/admin/monitor/alerts/rules",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200


class TestSettings:
    """Tests for system settings endpoints"""

    def test_get_system_settings(self, client: TestClient, admin_token):
        """Test getting system settings"""
        response = client.get(
            "/admin/settings/system",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_update_system_settings(self, client: TestClient, admin_token):
        """Test updating system settings"""
        response = client.put(
            "/admin/settings/system",
            json={"basic": {"system_name": "Test System"}},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_security_settings(self, client: TestClient, admin_token):
        """Test getting security settings"""
        response = client.get(
            "/admin/settings/security",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200


class TestAdminManagement:
    """Tests for admin management endpoints"""

    def test_get_admins(self, client: TestClient, superadmin_token):
        """Test getting admin list"""
        response = client.get(
            "/admin/settings/admins",
            headers={"Authorization": f"Bearer {superadmin_token}"}
        )
        assert response.status_code == 200

    def test_create_admin(self, client: TestClient, superadmin_token):
        """Test creating a new admin"""
        response = client.post(
            "/admin/settings/admins",
            json={
                "username": "newadmin",
                "password": "password123",
                "email": "newadmin@test.com"
            },
            headers={"Authorization": f"Bearer {superadmin_token}"}
        )
        assert response.status_code in [200, 201]

    def test_update_admin(self, client: TestClient, superadmin_token, mock_admin):
        """Test updating an admin"""
        response = client.put(
            f"/admin/settings/admins/{mock_admin.id}",
            json={"display_name": "Updated Name"},
            headers={"Authorization": f"Bearer {superadmin_token}"}
        )
        assert response.status_code == 200


class TestAuditLogs:
    """Tests for audit log endpoints"""

    def test_get_logs(self, client: TestClient, admin_token):
        """Test getting audit logs"""
        response = client.get(
            "/admin/logs?page=1&page_size=20",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data

    def test_get_logs_with_filters(self, client: TestClient, admin_token):
        """Test getting logs with filters"""
        response = client.get(
            "/admin/logs?action=login&module=auth",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_get_log_actions(self, client: TestClient, admin_token):
        """Test getting available log actions"""
        response = client.get(
            "/admin/logs/actions",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200

    def test_export_logs(self, client: TestClient, admin_token):
        """Test exporting logs"""
        response = client.get(
            "/admin/logs/export",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200


class TestPermissions:
    """Tests for permission checking"""

    def test_unauthorized_access(self, client: TestClient):
        """Test access without token"""
        response = client.get("/admin/dashboard/stats")
        assert response.status_code == 401

    def test_forbidden_without_permission(self, client: TestClient, limited_admin_token):
        """Test access without required permission"""
        response = client.get(
            "/admin/settings/admins",
            headers={"Authorization": f"Bearer {limited_admin_token}"}
        )
        assert response.status_code == 403

    def test_superadmin_bypass_permissions(self, client: TestClient, superadmin_token):
        """Test superadmin can access all endpoints"""
        endpoints = [
            "/admin/dashboard/stats",
            "/admin/users",
            "/admin/settings/admins",
            "/admin/logs",
        ]
        for endpoint in endpoints:
            response = client.get(
                endpoint,
                headers={"Authorization": f"Bearer {superadmin_token}"}
            )
            assert response.status_code == 200, f"Failed for {endpoint}"


# Pytest fixtures
@pytest.fixture
def client():
    """Create test client for admin API"""
    from admin.main import app
    return TestClient(app)


@pytest.fixture
def mock_admin():
    """Create mock admin user"""
    return MagicMock(
        id="1",
        username="admin",
        is_superadmin=False,
        permissions=["user:list", "data:transaction:view"]
    )


@pytest.fixture
def mock_admin_with_mfa():
    """Create mock admin with MFA enabled"""
    return MagicMock(
        id="2",
        username="admin_mfa",
        mfa_enabled=True
    )


@pytest.fixture
def mock_user():
    """Create mock app user"""
    return MagicMock(id="100", phone="13800138000", status="active")


@pytest.fixture
def mock_disabled_user():
    """Create mock disabled user"""
    return MagicMock(id="101", phone="13800138001", status="disabled")


@pytest.fixture
def mock_users():
    """Create list of mock users"""
    return [
        MagicMock(id=str(i), phone=f"1380013800{i}", status="active")
        for i in range(10)
    ]


@pytest.fixture
def admin_token():
    """Get admin JWT token"""
    return "mock_admin_token"


@pytest.fixture
def superadmin_token():
    """Get superadmin JWT token"""
    return "mock_superadmin_token"


@pytest.fixture
def limited_admin_token():
    """Get token for admin with limited permissions"""
    return "mock_limited_admin_token"
