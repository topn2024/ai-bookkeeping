"""
Admin API Test Suite
Tests for the admin management platform backend API
"""
import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
import json


# ============ Authentication Tests ============

class TestAdminAuth:
    """Tests for admin authentication endpoints"""

    def test_admin_login_success(self, client: TestClient):
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

    def test_admin_logout(self, client: TestClient, auth_headers):
        """Test admin logout"""
        response = client.post(
            "/admin/auth/logout",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_current_admin(self, client: TestClient, auth_headers):
        """Test getting current admin info"""
        response = client.get(
            "/admin/auth/me",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "username" in data


# ============ Dashboard Tests ============

class TestDashboard:
    """Tests for dashboard endpoints"""

    def test_get_dashboard_stats(self, client: TestClient, auth_headers):
        """Test getting dashboard statistics"""
        response = client.get(
            "/admin/dashboard/stats",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "total_users" in data or "today_new_users" in data

    def test_get_user_trend(self, client: TestClient, auth_headers):
        """Test getting user growth trend"""
        response = client.get(
            "/admin/dashboard/trend/users?period=7d",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "new_users" in data or "period" in data

    def test_get_transaction_trend(self, client: TestClient, auth_headers):
        """Test getting transaction trend"""
        response = client.get(
            "/admin/dashboard/trend/transactions?period=7d",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_activity_heatmap(self, client: TestClient, auth_headers):
        """Test getting activity heatmap data"""
        response = client.get(
            "/admin/dashboard/heatmap/activity",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_recent_transactions(self, client: TestClient, auth_headers):
        """Test getting recent transactions"""
        response = client.get(
            "/admin/dashboard/recent-transactions",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_top_users(self, client: TestClient, auth_headers):
        """Test getting top users"""
        response = client.get(
            "/admin/dashboard/top-users",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ User Management Tests ============

class TestUserManagement:
    """Tests for user management endpoints"""

    def test_get_users_list(self, client: TestClient, auth_headers):
        """Test getting paginated user list"""
        response = client.get(
            "/admin/users?page=1&page_size=10",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    def test_get_users_with_search(self, client: TestClient, auth_headers):
        """Test getting users with search"""
        response = client.get(
            "/admin/users?search=test",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data

    def test_export_users_csv(self, client: TestClient, auth_headers):
        """Test exporting users as CSV"""
        response = client.get(
            "/admin/users/export?format=csv",
            headers=auth_headers
        )
        assert response.status_code == 200
        assert "text/csv" in response.headers.get("content-type", "")


# ============ Transaction Management Tests ============

class TestTransactionManagement:
    """Tests for transaction management endpoints"""

    def test_get_transactions(self, client: TestClient, auth_headers):
        """Test getting transactions"""
        response = client.get(
            "/admin/transactions?page=1&page_size=20",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or "transactions" in data or isinstance(data, list)

    def test_get_transaction_stats(self, client: TestClient, auth_headers):
        """Test getting transaction statistics"""
        response = client.get(
            "/admin/transactions/stats",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Data Management Tests ============

class TestDataManagement:
    """Tests for data management endpoints"""

    def test_get_books(self, client: TestClient, auth_headers):
        """Test getting books"""
        response = client.get(
            "/admin/data/books",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_accounts(self, client: TestClient, auth_headers):
        """Test getting accounts"""
        response = client.get(
            "/admin/data/accounts",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_categories(self, client: TestClient, auth_headers):
        """Test getting categories"""
        response = client.get(
            "/admin/categories",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_backups(self, client: TestClient, auth_headers):
        """Test getting backups"""
        response = client.get(
            "/admin/backups",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Statistics Tests ============

class TestStatistics:
    """Tests for statistics endpoints"""

    def test_get_user_retention(self, client: TestClient, auth_headers):
        """Test getting user retention analysis"""
        response = client.get(
            "/admin/statistics/users/retention",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_transaction_frequency(self, client: TestClient, auth_headers):
        """Test getting transaction frequency"""
        response = client.get(
            "/admin/statistics/transactions/frequency",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_daily_report(self, client: TestClient, auth_headers):
        """Test getting daily report"""
        response = client.get(
            "/admin/statistics/reports/daily",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_weekly_report(self, client: TestClient, auth_headers):
        """Test getting weekly report"""
        response = client.get(
            "/admin/statistics/reports/weekly",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Monitoring Tests ============

class TestMonitoring:
    """Tests for system monitoring endpoints"""

    def test_get_system_health(self, client: TestClient, auth_headers):
        """Test getting system health"""
        response = client.get(
            "/admin/monitoring/health",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_system_resources(self, client: TestClient, auth_headers):
        """Test getting system resources"""
        response = client.get(
            "/admin/monitoring/resources",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_database_status(self, client: TestClient, auth_headers):
        """Test getting database status"""
        response = client.get(
            "/admin/monitoring/database",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_storage_status(self, client: TestClient, auth_headers):
        """Test getting storage status"""
        response = client.get(
            "/admin/monitoring/storage",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_alert_rules(self, client: TestClient, auth_headers):
        """Test getting alert rules"""
        response = client.get(
            "/admin/monitoring/alerts/rules",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Settings Tests ============

class TestSettings:
    """Tests for system settings endpoints"""

    def test_get_all_settings(self, client: TestClient, auth_headers):
        """Test getting all settings"""
        response = client.get(
            "/admin/settings/all",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_system_info(self, client: TestClient, auth_headers):
        """Test getting system info"""
        response = client.get(
            "/admin/settings/system-info",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_login_security(self, client: TestClient, auth_headers):
        """Test getting login security settings"""
        response = client.get(
            "/admin/settings/login-security",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_registration_settings(self, client: TestClient, auth_headers):
        """Test getting registration settings"""
        response = client.get(
            "/admin/settings/registration",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Admin Management Tests ============

class TestAdminManagement:
    """Tests for admin management endpoints"""

    def test_get_admins(self, client: TestClient, auth_headers):
        """Test getting admin list"""
        response = client.get(
            "/admin/admins",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_current_admin_profile(self, client: TestClient, auth_headers):
        """Test getting current admin profile"""
        response = client.get(
            "/admin/admins/me",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_roles_list(self, client: TestClient, auth_headers):
        """Test getting roles list"""
        response = client.get(
            "/admin/admins/roles/list",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_permissions_list(self, client: TestClient, auth_headers):
        """Test getting permissions list"""
        response = client.get(
            "/admin/admins/permissions/list",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Audit Logs Tests ============

class TestAuditLogs:
    """Tests for audit log endpoints"""

    def test_get_logs(self, client: TestClient, auth_headers):
        """Test getting audit logs"""
        response = client.get(
            "/admin/logs?page=1&page_size=20",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or isinstance(data, list)

    def test_get_log_actions(self, client: TestClient, auth_headers):
        """Test getting available log actions"""
        response = client.get(
            "/admin/logs/actions",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_log_modules(self, client: TestClient, auth_headers):
        """Test getting log modules"""
        response = client.get(
            "/admin/logs/modules",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_log_stats(self, client: TestClient, auth_headers):
        """Test getting log statistics"""
        response = client.get(
            "/admin/logs/stats",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_export_logs(self, client: TestClient, auth_headers):
        """Test exporting logs"""
        response = client.get(
            "/admin/logs/export",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Permission Tests ============

class TestPermissions:
    """Tests for permission checking"""

    def test_unauthorized_access(self, client: TestClient):
        """Test access without token returns 401"""
        response = client.get("/admin/dashboard/stats")
        assert response.status_code == 401

    def test_health_endpoint_public(self, client: TestClient):
        """Test health endpoint is public"""
        response = client.get("/health")
        assert response.status_code == 200


# ============ Fixtures ============

@pytest.fixture
def client():
    """Create test client for admin API"""
    from admin.main import app
    return TestClient(app)


@pytest.fixture
def auth_headers(client: TestClient):
    """Get authentication headers by logging in"""
    response = client.post(
        "/admin/auth/login",
        json={"username": "admin", "password": "admin123"}
    )
    if response.status_code != 200:
        pytest.skip("Admin login failed - test admin user may not exist")

    data = response.json()
    token = data.get("access_token")
    if not token:
        pytest.skip("No access token in login response")

    return {"Authorization": f"Bearer {token}"}
