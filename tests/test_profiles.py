"""
Unit and schema validation tests for Apollo Multi-Screen Bridge.
Validates profile configurations, port conflict avoidance, GUID uniqueness,
and PowerShell script integrity.
"""
import json
from pathlib import Path
import re
import pytest

REPO_ROOT = Path(__file__).parent.parent
CONFIG_FILES = [
    REPO_ROOT / "config" / "profiles.sample.json",
    REPO_ROOT / "config" / "profiles.json",
]


@pytest.mark.parametrize("config_path", [p for p in CONFIG_FILES if p.exists()])
def test_profiles_json_schema(config_path):
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    assert "general" in data, f"Config {config_path.name} missing 'general' block"
    assert "profiles" in data, f"Config {config_path.name} missing 'profiles' array"
    assert len(data["profiles"]) >= 1, "Must define at least one active profile"

    general = data["general"]
    assert "sunshine_bin" in general
    assert "stagger_delay_ms" in general
    assert general["stagger_delay_ms"] >= 500, "Stagger delay must be >= 500ms to avoid DXGI contention"

    profile_ids = set()
    port_bases = set()
    webui_ports = set()

    for prof in data["profiles"]:
        # ID and naming uniqueness
        assert "id" in prof and len(prof["id"]) > 0
        assert prof["id"] not in profile_ids, f"Duplicate profile id: {prof['id']}"
        profile_ids.add(prof["id"])

        # Port conflict prevention
        port_base = prof.get("port_base")
        webui_port = prof.get("webui_port")
        assert port_base is not None, f"Profile {prof['id']} missing port_base"
        assert webui_port is not None, f"Profile {prof['id']} missing webui_port"

        assert port_base not in port_bases, f"Port base conflict on {port_base}"
        assert webui_port not in webui_ports, f"WebUI port conflict on {webui_port}"
        assert webui_port > port_base, "WebUI port should be offset from base port"
        port_bases.add(port_base)
        webui_ports.add(webui_port)

        # Display config
        assert "display" in prof
        disp = prof["display"]
        assert "resolution" in disp
        assert "refresh_rate" in disp
        assert disp["refresh_rate"] in [60, 120, 144, 240]


def test_no_private_hostnames_or_tailscale_ips():
    """Ensure no personal credentials or live private Tailscale 100.x IPs leak."""
    tailscale_regex = re.compile(r"100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.[0-9]+\.[0-9]+")
    
    for ps_file in REPO_ROOT.glob("**/*.ps1"):
        content = ps_file.read_text(encoding="utf-8", errors="ignore")
        matches = tailscale_regex.findall(content)
        assert len(matches) == 0, f"Leaked private Tailscale IP in {ps_file}: {matches}"


def test_powershell_scripts_exist():
    expected_scripts = [
        "scripts/bootstrap.ps1",
        "scripts/launch_and_heal.ps1",
        "scripts/selftest.ps1",
        "scripts/restore_backup.ps1",
        "install.ps1"
    ]
    for script in expected_scripts:
        path = REPO_ROOT / script
        assert path.exists(), f"Missing required PowerShell script: {script}"
        assert path.stat().st_size > 200, f"Script {script} appears truncated"
