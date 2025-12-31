"""
Admin API Test Suite
Tests for the admin management platform backend API

This module tests against a live server at localhost:8001.
Ensure the admin API server is running before running these tests.
"""
import pytest
import httpx
from datetime import datetime, timedelta
import json

# Base URL for admin API
# Use remote server if localhost is not available
BASE_URL = "http://160.202.238.29:8001"


# ============ Module-level shared state ============
# Use module-level variables to ensure token is cached across all tests

_http_client = None
_auth_token = None


def get_http_client():
    """Get or create HTTP client"""
    global _http_client
    if _http_client is None:
        _http_client = httpx.Client(base_url=BASE_URL, timeout=30.0)
    return _http_client


def get_auth_token():
    """Get or create auth token"""
    global _auth_token
    if _auth_token is None:
        client = get_http_client()
        try:
            response = client.post(
                "/admin/auth/login",
                json={"username": "admin", "password": "admin123"}
            )
            if response.status_code != 200:
                pytest.skip(f"Admin login failed with status {response.status_code}")

            data = response.json()
            _auth_token = data.get("access_token")
            if not _auth_token:
                pytest.skip("No access token in login response")
        except httpx.ConnectError:
            pytest.skip("Admin API server not running at localhost:8001")
    return _auth_token


@pytest.fixture
def http_client():
    """Get HTTP client for testing"""
    return get_http_client()


@pytest.fixture
def auth_headers():
    """Get authentication headers"""
    token = get_auth_token()
    return {"Authorization": f"Bearer {token}"}


# ============ Authentication Tests ============

class TestAdminAuth:
    """Tests for admin authentication endpoints"""

    def test_admin_login_success(self, http_client):
        """Test successful admin login"""
        response = http_client.post(
            "/admin/auth/login",
            json={"username": "admin", "password": "admin123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "admin" in data
        assert data["admin"]["username"] == "admin"

    def test_admin_login_invalid_credentials(self, http_client):
        """Test login with invalid credentials"""
        response = http_client.post(
            "/admin/auth/login",
            json={"username": "admin", "password": "wrongpassword"}
        )
        assert response.status_code == 401

    def test_admin_logout(self, http_client, auth_headers):
        """Test admin logout"""
        response = http_client.post(
            "/admin/auth/logout",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_current_admin(self, http_client, auth_headers):
        """Test getting current admin info"""
        response = http_client.get(
            "/admin/auth/me",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "username" in data


# ============ Dashboard Tests ============

class TestDashboard:
    """Tests for dashboard endpoints"""

    def test_get_dashboard_stats(self, http_client, auth_headers):
        """Test getting dashboard statistics"""
        response = http_client.get(
            "/admin/dashboard/stats",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "total_users" in data or "today_new_users" in data

    def test_get_user_trend(self, http_client, auth_headers):
        """Test getting user growth trend"""
        response = http_client.get(
            "/admin/dashboard/trend/users?period=7d",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_transaction_trend(self, http_client, auth_headers):
        """Test getting transaction trend"""
        response = http_client.get(
            "/admin/dashboard/trend/transactions?period=7d",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_activity_heatmap(self, http_client, auth_headers):
        """Test getting activity heatmap data"""
        response = http_client.get(
            "/admin/dashboard/heatmap/activity",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_recent_transactions(self, http_client, auth_headers):
        """Test getting recent transactions"""
        response = http_client.get(
            "/admin/dashboard/recent-transactions",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_top_users(self, http_client, auth_headers):
        """Test getting top users"""
        response = http_client.get(
            "/admin/dashboard/top-users",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ User Management Tests ============

class TestUserManagement:
    """Tests for user management endpoints"""

    def test_get_users_list(self, http_client, auth_headers):
        """Test getting paginated user list"""
        response = http_client.get(
            "/admin/users?page=1&page_size=10",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    def test_get_users_with_search(self, http_client, auth_headers):
        """Test getting users with search"""
        response = http_client.get(
            "/admin/users?search=test",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data

    def test_export_users_csv(self, http_client, auth_headers):
        """Test exporting users as CSV"""
        response = http_client.get(
            "/admin/users/export?format=csv",
            headers=auth_headers
        )
        assert response.status_code == 200
        assert "text/csv" in response.headers.get("content-type", "")


# ============ Transaction Management Tests ============

class TestTransactionManagement:
    """Tests for transaction management endpoints"""

    def test_get_transactions(self, http_client, auth_headers):
        """Test getting transactions"""
        response = http_client.get(
            "/admin/transactions?page=1&page_size=20",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or "transactions" in data or isinstance(data, list)

    def test_get_transaction_stats(self, http_client, auth_headers):
        """Test getting transaction statistics"""
        response = http_client.get(
            "/admin/transactions/stats",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Data Management Tests ============

class TestDataManagement:
    """Tests for data management endpoints"""

    def test_get_books(self, http_client, auth_headers):
        """Test getting books"""
        response = http_client.get(
            "/admin/data/books",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_accounts(self, http_client, auth_headers):
        """Test getting accounts"""
        response = http_client.get(
            "/admin/data/accounts",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_categories(self, http_client, auth_headers):
        """Test getting categories"""
        response = http_client.get(
            "/admin/categories",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_backups(self, http_client, auth_headers):
        """Test getting backups"""
        response = http_client.get(
            "/admin/backups",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Statistics Tests ============

class TestStatistics:
    """Tests for statistics endpoints"""

    def test_get_user_retention(self, http_client, auth_headers):
        """Test getting user retention analysis"""
        response = http_client.get(
            "/admin/statistics/users/retention",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_transaction_frequency(self, http_client, auth_headers):
        """Test getting transaction frequency"""
        response = http_client.get(
            "/admin/statistics/transactions/frequency",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_daily_report(self, http_client, auth_headers):
        """Test getting daily report"""
        response = http_client.get(
            "/admin/statistics/reports/daily",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_weekly_report(self, http_client, auth_headers):
        """Test getting weekly report"""
        response = http_client.get(
            "/admin/statistics/reports/weekly",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Monitoring Tests ============

class TestMonitoring:
    """Tests for system monitoring endpoints"""

    def test_get_system_health(self, http_client, auth_headers):
        """Test getting system health"""
        response = http_client.get(
            "/admin/monitoring/health",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_system_resources(self, http_client, auth_headers):
        """Test getting system resources"""
        response = http_client.get(
            "/admin/monitoring/resources",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_database_status(self, http_client, auth_headers):
        """Test getting database status"""
        response = http_client.get(
            "/admin/monitoring/database",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_storage_status(self, http_client, auth_headers):
        """Test getting storage status"""
        response = http_client.get(
            "/admin/monitoring/storage",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_alert_rules(self, http_client, auth_headers):
        """Test getting alert rules"""
        response = http_client.get(
            "/admin/monitoring/alerts/rules",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Settings Tests ============

class TestSettings:
    """Tests for system settings endpoints"""

    def test_get_all_settings(self, http_client, auth_headers):
        """Test getting all settings"""
        response = http_client.get(
            "/admin/settings/all",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_system_info(self, http_client, auth_headers):
        """Test getting system info"""
        response = http_client.get(
            "/admin/settings/system-info",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_login_security(self, http_client, auth_headers):
        """Test getting login security settings"""
        response = http_client.get(
            "/admin/settings/login-security",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_registration_settings(self, http_client, auth_headers):
        """Test getting registration settings"""
        response = http_client.get(
            "/admin/settings/registration",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Admin Management Tests ============

class TestAdminManagement:
    """Tests for admin management endpoints"""

    def test_get_admins(self, http_client, auth_headers):
        """Test getting admin list"""
        response = http_client.get(
            "/admin/admins",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_current_admin_profile(self, http_client, auth_headers):
        """Test getting current admin profile"""
        response = http_client.get(
            "/admin/admins/me",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_roles_list(self, http_client, auth_headers):
        """Test getting roles list"""
        response = http_client.get(
            "/admin/admins/roles/list",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_permissions_list(self, http_client, auth_headers):
        """Test getting permissions list"""
        response = http_client.get(
            "/admin/admins/permissions/list",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Audit Logs Tests ============

class TestAuditLogs:
    """Tests for audit log endpoints"""

    def test_get_logs(self, http_client, auth_headers):
        """Test getting audit logs"""
        response = http_client.get(
            "/admin/logs?page=1&page_size=20",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data or isinstance(data, list)

    def test_get_log_actions(self, http_client, auth_headers):
        """Test getting available log actions"""
        response = http_client.get(
            "/admin/logs/actions",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_log_modules(self, http_client, auth_headers):
        """Test getting log modules"""
        response = http_client.get(
            "/admin/logs/modules",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_log_stats(self, http_client, auth_headers):
        """Test getting log statistics"""
        response = http_client.get(
            "/admin/logs/stats",
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_export_logs(self, http_client, auth_headers):
        """Test exporting logs"""
        response = http_client.get(
            "/admin/logs/export",
            headers=auth_headers
        )
        assert response.status_code == 200


# ============ Permission Tests ============

class TestPermissions:
    """Tests for permission checking"""

    def test_unauthorized_access(self, http_client):
        """Test access without token returns 401 or 403"""
        response = http_client.get("/admin/dashboard/stats")
        assert response.status_code in [401, 403]

    def test_health_endpoint_public(self, http_client):
        """Test health endpoint is public"""
        response = http_client.get("/health")
        assert response.status_code == 200
