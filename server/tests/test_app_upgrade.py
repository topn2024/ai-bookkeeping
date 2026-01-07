"""
Test cases for APP upgrade and update functionality.

Tests cover:
- Version check API
- Gradual rollout logic
- Incremental update (patch) support
- Upgrade analytics
"""

import pytest
import hashlib
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from httpx import AsyncClient

from app.main import app


class TestVersionCheck:
    """Test version check API."""

    @pytest.mark.asyncio
    async def test_check_update_no_update_available(self, client: AsyncClient, db_session):
        """Test check update when already on latest version."""
        response = await client.get(
            "/api/v1/app-upgrade/check",
            params={
                "version_name": "99.0.0",
                "version_code": 9999,
                "platform": "android",
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["has_update"] is False
        assert data["is_force_update"] is False
        assert data["current_version"] == "99.0.0"

    @pytest.mark.asyncio
    async def test_check_update_with_update_available(
        self, client: AsyncClient, db_session, test_app_version
    ):
        """Test check update when new version is available."""
        response = await client.get(
            "/api/v1/app-upgrade/check",
            params={
                "version_name": "1.0.0",
                "version_code": 1,
                "platform": "android",
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["has_update"] is True
        assert "latest_version" in data
        assert data["latest_version"]["version_code"] > 1

    @pytest.mark.asyncio
    async def test_check_update_force_update(
        self, client: AsyncClient, db_session, test_force_update_version
    ):
        """Test check update with force update required."""
        response = await client.get(
            "/api/v1/app-upgrade/check",
            params={
                "version_name": "0.9.0",
                "version_code": 1,
                "platform": "android",
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["has_update"] is True
        assert data["is_force_update"] is True


class TestGradualRollout:
    """Test gradual rollout logic."""

    def test_is_in_rollout_100_percent(self):
        """Test that 100% rollout always includes device."""
        from app.api.v1.app_upgrade import is_in_rollout

        assert is_in_rollout("device_001", 100) is True
        assert is_in_rollout("device_002", 100) is True
        assert is_in_rollout("any_device", 100) is True

    def test_is_in_rollout_0_percent(self):
        """Test that 0% rollout never includes device."""
        from app.api.v1.app_upgrade import is_in_rollout

        assert is_in_rollout("device_001", 0) is False
        assert is_in_rollout("device_002", 0) is False
        assert is_in_rollout("any_device", 0) is False

    def test_is_in_rollout_consistent(self):
        """Test that same device always gets same result."""
        from app.api.v1.app_upgrade import is_in_rollout

        device_id = "test_device_12345"
        result = is_in_rollout(device_id, 50)

        # Same device should get same result every time
        for _ in range(100):
            assert is_in_rollout(device_id, 50) == result

    def test_is_in_rollout_distribution(self):
        """Test rollout distribution is approximately correct."""
        from app.api.v1.app_upgrade import is_in_rollout

        rollout_percentage = 30
        included_count = 0
        total_devices = 1000

        for i in range(total_devices):
            device_id = f"device_{i:04d}"
            if is_in_rollout(device_id, rollout_percentage):
                included_count += 1

        # Allow 10% deviation
        expected_min = rollout_percentage * total_devices // 100 - 100
        expected_max = rollout_percentage * total_devices // 100 + 100

        assert expected_min <= included_count <= expected_max


class TestVersionComparison:
    """Test version comparison logic."""

    def test_compare_versions_equal(self):
        """Test comparing equal versions."""
        from app.api.v1.app_upgrade import compare_versions

        assert compare_versions("1.0.0", "1.0.0") == 0
        assert compare_versions("2.1.3", "2.1.3") == 0

    def test_compare_versions_less_than(self):
        """Test comparing when first version is less."""
        from app.api.v1.app_upgrade import compare_versions

        assert compare_versions("1.0.0", "2.0.0") == -1
        assert compare_versions("1.0.0", "1.1.0") == -1
        assert compare_versions("1.0.0", "1.0.1") == -1
        assert compare_versions("1.9.9", "2.0.0") == -1

    def test_compare_versions_greater_than(self):
        """Test comparing when first version is greater."""
        from app.api.v1.app_upgrade import compare_versions

        assert compare_versions("2.0.0", "1.0.0") == 1
        assert compare_versions("1.1.0", "1.0.0") == 1
        assert compare_versions("1.0.1", "1.0.0") == 1

    def test_compare_versions_different_lengths(self):
        """Test comparing versions with different segment counts."""
        from app.api.v1.app_upgrade import compare_versions

        assert compare_versions("1.0", "1.0.0") == 0
        assert compare_versions("1.0.0", "1.0") == 0
        assert compare_versions("1.0.1", "1.0") == 1


class TestIncrementalUpdate:
    """Test incremental update (patch) functionality."""

    @pytest.mark.asyncio
    async def test_check_update_with_patch(
        self, client: AsyncClient, db_session, test_version_with_patch
    ):
        """Test check update returns patch info when available."""
        version = test_version_with_patch

        response = await client.get(
            "/api/v1/app-upgrade/check",
            params={
                "version_name": version["patch_from_version"],
                "version_code": version["patch_from_code"],
                "platform": "android",
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["has_update"] is True
        assert data["has_patch"] is True
        assert data["latest_version"]["patch"] is not None
        assert data["latest_version"]["patch"]["from_version"] == version["patch_from_version"]

    @pytest.mark.asyncio
    async def test_check_update_no_patch_different_version(
        self, client: AsyncClient, db_session, test_version_with_patch
    ):
        """Test that patch is not returned when base version doesn't match."""
        response = await client.get(
            "/api/v1/app-upgrade/check",
            params={
                "version_name": "0.5.0",
                "version_code": 5,  # Different from patch base
                "platform": "android",
            }
        )
        assert response.status_code == 200
        data = response.json()
        # Should have update but no patch
        if data["has_update"]:
            assert data.get("has_patch", False) is False or \
                   data["latest_version"].get("patch") is None


class TestUpgradeAnalytics:
    """Test upgrade analytics API."""

    @pytest.mark.asyncio
    async def test_submit_analytics_event(self, client: AsyncClient, db_session):
        """Test submitting an analytics event."""
        event_data = {
            "event_type": "downloadStart",
            "from_version": "1.0.0",
            "to_version": "1.1.0",
            "platform": "android",
            "device_id": "test_device_001",
            "timestamp": datetime.utcnow().isoformat(),
        }

        response = await client.post(
            "/api/v1/app-upgrade/analytics",
            json=event_data
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_submit_analytics_download_complete(self, client: AsyncClient, db_session):
        """Test submitting download complete event with metrics."""
        event_data = {
            "event_type": "downloadComplete",
            "from_version": "1.0.0",
            "to_version": "1.1.0",
            "platform": "android",
            "device_id": "test_device_001",
            "download_progress": 100,
            "download_size": 52428800,  # 50 MB
            "download_duration_ms": 30000,  # 30 seconds
        }

        response = await client.post(
            "/api/v1/app-upgrade/analytics",
            json=event_data
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_submit_analytics_error_event(self, client: AsyncClient, db_session):
        """Test submitting error event."""
        event_data = {
            "event_type": "downloadFailed",
            "from_version": "1.0.0",
            "to_version": "1.1.0",
            "platform": "android",
            "error_message": "Network timeout",
            "error_code": "TIMEOUT",
        }

        response = await client.post(
            "/api/v1/app-upgrade/analytics",
            json=event_data
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_get_version_stats(
        self, client: AsyncClient, db_session, test_analytics_data
    ):
        """Test getting version statistics."""
        response = await client.get(
            "/api/v1/app-upgrade/stats/1.1.0",
            params={"platform": "android"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "version" in data
        assert "total_checks" in data
        assert "total_downloads" in data
        assert "download_success_rate" in data
        assert "events_by_type" in data


class TestLatestVersion:
    """Test get latest version API."""

    @pytest.mark.asyncio
    async def test_get_latest_version(
        self, client: AsyncClient, db_session, test_app_version
    ):
        """Test getting latest published version."""
        response = await client.get(
            "/api/v1/app-upgrade/latest",
            params={"platform": "android"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "version_name" in data
        assert "version_code" in data
        assert "release_notes" in data

    @pytest.mark.asyncio
    async def test_get_latest_version_no_published(self, client: AsyncClient, db_session):
        """Test getting latest version when none published."""
        # Assuming no published versions in clean DB
        response = await client.get(
            "/api/v1/app-upgrade/latest",
            params={"platform": "ios"}  # No iOS versions
        )
        # Should return null/empty for no versions
        assert response.status_code == 200


# ============== Fixtures ==============

@pytest.fixture
async def test_app_version(db_session):
    """Create a test app version."""
    from app.models.app_version import AppVersion
    import uuid

    version = AppVersion(
        id=uuid.uuid4(),
        version_name="1.1.0",
        version_code=10,
        platform="android",
        release_notes="Test release notes",
        is_force_update=False,
        status=1,  # Published
        published_at=datetime.utcnow(),
    )
    db_session.add(version)
    await db_session.commit()
    return version


@pytest.fixture
async def test_force_update_version(db_session):
    """Create a test version with force update."""
    from app.models.app_version import AppVersion
    import uuid

    version = AppVersion(
        id=uuid.uuid4(),
        version_name="2.0.0",
        version_code=20,
        platform="android",
        release_notes="Major update - force update required",
        is_force_update=True,
        min_supported_version="1.5.0",
        status=1,
        published_at=datetime.utcnow(),
    )
    db_session.add(version)
    await db_session.commit()
    return version


@pytest.fixture
async def test_version_with_patch(db_session):
    """Create a test version with patch support."""
    from app.models.app_version import AppVersion
    import uuid

    # Use high version codes to ensure this is the latest version
    # (avoids conflicts with other test fixtures creating lower versions)
    version_data = {
        "version_name": "3.0.0",
        "version_code": 100,
        "patch_from_version": "2.9.0",
        "patch_from_code": 99,
    }

    version = AppVersion(
        id=uuid.uuid4(),
        version_name=version_data["version_name"],
        version_code=version_data["version_code"],
        platform="android",
        release_notes="Update with patch support",
        file_url="https://example.com/app_3.0.0.apk",
        file_size=52428800,
        file_md5="abc123def456",
        patch_from_version=version_data["patch_from_version"],
        patch_from_code=version_data["patch_from_code"],
        patch_file_url="https://example.com/patch_2.9.0_to_3.0.0.patch",
        patch_file_size=5242880,
        patch_file_md5="patch123md5",
        status=1,
        published_at=datetime.utcnow(),
    )
    db_session.add(version)
    await db_session.commit()
    return version_data


@pytest.fixture
async def test_analytics_data(db_session):
    """Create test analytics data."""
    from app.models.upgrade_analytics import UpgradeAnalytics

    events = [
        UpgradeAnalytics(
            event_type="updateFound",
            platform="android",
            from_version="1.0.0",
            to_version="1.1.0",
            device_id=f"device_{i:03d}",
            event_time=datetime.utcnow(),
        )
        for i in range(10)
    ]

    # Add some download events
    for i in range(8):
        events.append(UpgradeAnalytics(
            event_type="downloadStart",
            platform="android",
            from_version="1.0.0",
            to_version="1.1.0",
            device_id=f"device_{i:03d}",
            event_time=datetime.utcnow(),
        ))

    # Add some complete events
    for i in range(6):
        events.append(UpgradeAnalytics(
            event_type="downloadComplete",
            platform="android",
            from_version="1.0.0",
            to_version="1.1.0",
            device_id=f"device_{i:03d}",
            download_duration_ms=30000 + i * 1000,
            event_time=datetime.utcnow(),
        ))

    for event in events:
        db_session.add(event)
    await db_session.commit()

    return events
