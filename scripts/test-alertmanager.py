#!/usr/bin/env python3
"""Exercise the real renderer; --image also checks with the pinned image/amtool."""
import argparse
from collections import Counter
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
TOKEN = "123456:test-only-secret"
CREDENTIALS = {
    "SMTP_SMARTHOST": "smtp.example.com:587",
    "SMTP_FROM": "alerts@example.com",
    "SMTP_AUTH_USERNAME": "alerts@example.com",
    "SMTP_AUTH_PASSWORD": "test-password",
    "SMTP_REQUIRE_TLS": "true",
    "ALERT_EMAIL_TO": "oncall@example.com",
    "SLACK_API_URL": "https://hooks.slack.com/services/test/test/test",
    "SLACK_CHANNEL_CRITICAL": "#critical",
    "SLACK_CHANNEL_WARNING": "#warning",
}
ROUTES = [
    ({"severity": "critical"}, ["critical-receiver"]),
    ({"severity": "warning"}, ["warning-receiver"]),
    ({"job": "blackbox-http", "severity": "critical"},
     ["critical-receiver", "probe-receiver"]),
    ({"job": "blackbox-http", "severity": "warning"}, ["warning-receiver"]),
    ({"job": "blackbox-http"}, ["probe-receiver"]),
    ({"alertname": "TelegramSmokeTest"}, ["default-receiver"]),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", help="Alertmanager image from Docker Compose")
    args = parser.parse_args()
    windows_shell = Path("C:/Program Files/Git/usr/bin/sh.exe")
    shell = (str(windows_shell) if os.name == "nt" and windows_shell.exists()
             else shutil.which("sh"))
    if not args.image and not shell:
        parser.error("Install a POSIX shell or use --image with Docker")

    def run(command, **kwargs):
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=90, **kwargs)

    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        # The official image runs as an unprivileged user and must write here.
        work.chmod(0o777)
        config = work / "alertmanager.yml"
        shutil.copyfile(ROOT / "alertmanager/alertmanager.yml.tmpl",
                        work / "alertmanager.yml.tmpl")
        # Production paths remain unchanged; the local-only runner uses temp paths.
        script = (ROOT / "alertmanager/entrypoint.sh").read_text()
        script = script.replace("/etc/alertmanager/", work.as_posix() + "/")
        script = script.replace("/tmp/alertmanager.yml.subst",
                                (work / "subst.yml").as_posix())
        runner = work / "entrypoint.sh"
        runner.write_text(script, newline="\n")

        def docker(binary, arguments, values=None):
            command = ["docker", "run", "--rm", "-v",
                       f"{work.as_posix()}:/etc/alertmanager", "-v",
                       f"{(ROOT / 'alertmanager/entrypoint.sh').as_posix()}:/entrypoint.sh:ro"]
            for key, value in (values or {}).items():
                command += ["-e", f"{key}={value}"]
            return run(command + ["--entrypoint", binary, args.image] + arguments)

        def render(values):
            config.unlink(missing_ok=True)
            values = {"AM_RENDER_ONLY": "1", **values}
            if args.image:
                return docker("/bin/sh", ["/entrypoint.sh"], values)
            env = {key: value for key, value in os.environ.items()
                   if key not in CREDENTIALS and not key.startswith("TELEGRAM_")
                   and key not in {"SMTP_TLS_INSECURE_SKIP_VERIFY",
                                   "ALERTMANAGER_HTTP_INSECURE_SKIP_VERIFY"}}
            env.update(values)
            env["PATH"] = str(Path(shell).parent) + os.pathsep + env.get("PATH", "")
            return run([shell, runner.as_posix()], env=env)

        # IDs cover groups, decimal normalization, and signed int64 boundaries.
        cases = [({}, None), ({"TELEGRAM_BOT_TOKEN": "", "TELEGRAM_CHAT_ID": ""}, None),
                 (CREDENTIALS, None)]
        for chat in ["123456", "-1001234567890", "000123", "-000123",
                     "9223372036854775807", "-9223372036854775808"]:
            cases.append(({"TELEGRAM_BOT_TOKEN": TOKEN, "TELEGRAM_CHAT_ID": chat},
                          int(chat)))
        cases.append(({**CREDENTIALS, "TELEGRAM_BOT_TOKEN": TOKEN,
                       "TELEGRAM_CHAT_ID": "-1001234567890"}, -1001234567890))
        cases.append(({**CREDENTIALS, "TELEGRAM_BOT_TOKEN": TOKEN,
                       "TELEGRAM_CHAT_ID": "123",
                       "SMTP_TLS_INSECURE_SKIP_VERIFY": "true",
                       "ALERTMANAGER_HTTP_INSECURE_SKIP_VERIFY": "true"}, 123))
        # Check YAML escaping without exposing the dummy credential in output.
        cases.append(({"TELEGRAM_BOT_TOKEN": "test:'&\\${literal}",
                       "TELEGRAM_CHAT_ID": "123"}, 123))
        for values, chat in cases:
            result = render(values)
            assert result.returncode == 0, result.stderr
            for secret in [values.get("TELEGRAM_BOT_TOKEN"),
                           values.get("SMTP_AUTH_PASSWORD")]:
                assert not secret or secret not in result.stdout + result.stderr
            text = config.read_text()
            assert not re.search(r"\{\{[A-Z_]+\}\}", text), "Unexpanded marker"
            data = yaml.safe_load(text)
            receivers = {item["name"]: item for item in data["receivers"]}
            assert data["global"]["http_config"]["tls_config"]["insecure_skip_verify"] is (
                values.get("ALERTMANAGER_HTTP_INSECURE_SKIP_VERIFY") == "true")
            assert ("telegram-receiver" in receivers) == (chat is not None)
            if chat is not None:
                telegram = receivers["telegram-receiver"]["telegram_configs"][0]
                assert telegram["chat_id"] == chat
                assert isinstance(telegram["chat_id"], int)
                assert telegram["bot_token"] == values["TELEGRAM_BOT_TOKEN"]
                assert telegram["parse_mode"] == ""
                assert telegram["send_resolved"] is True
                for field in ["Status:", "Alert:", "Severity:", "Instance:",
                              "Summary:", "Description:"]:
                    assert field in telegram["message"]
                route = data["route"]["routes"][0]
                assert route == {"receiver": "telegram-receiver", "continue": True}
            assert data["route"]["group_wait"] == "30s"
            assert data["route"]["group_interval"] == "5m"
            assert data["route"]["repeat_interval"] == "4h"
            for name in ["default", "critical", "warning", "probe"]:
                assert ("email_configs" in receivers[name + "-receiver"]) == bool(
                    values.get("SMTP_SMARTHOST"))
            for name in ["critical", "warning"]:
                assert ("slack_configs" in receivers[name + "-receiver"]) == bool(
                    values.get("SLACK_API_URL"))
            if values.get("SMTP_SMARTHOST"):
                assert data["global"]["smtp_tls_config"]["insecure_skip_verify"] is (
                    values.get("SMTP_TLS_INSECURE_SKIP_VERIFY") == "true")
            if args.image:
                checked = docker("/bin/amtool", ["check-config",
                                                  "/etc/alertmanager/alertmanager.yml"])
                assert checked.returncode == 0, checked.stderr
            # Compare routing against original receiver sets, including fallback.
            def select(route, labels):
                found = []
                for child in route.get("routes", []):
                    if all(labels.get(k) == v for k, v in child.get("match", {}).items()):
                        found.extend(select(child, labels))
                        if not child.get("continue", False):
                            break
                return found or [route["receiver"]]
            for labels, original in ROUTES:
                expected = original + (["telegram-receiver"] if chat is not None else [])
                assert Counter(select(data["route"], labels)) == Counter(expected)
                if args.image:
                    checked = docker("/bin/amtool", ["config", "routes", "test",
                        "--config.file=/etc/alertmanager/alertmanager.yml",
                        *[f"{k}={v}" for k, v in labels.items()]])
                    assert checked.returncode == 0, checked.stderr
                    actual = re.findall(r"\b[a-z]+-receiver\b", checked.stdout)
                    assert Counter(actual) == Counter(expected), checked.stdout

        invalid = [
            {"TELEGRAM_BOT_TOKEN": TOKEN}, {"TELEGRAM_CHAT_ID": "123"},
            *[{"TELEGRAM_BOT_TOKEN": TOKEN, "TELEGRAM_CHAT_ID": value}
              for value in ["0", "-0", "000", "abc", "1.5", "1e3", "+123",
                            " 123", "123\n456", "123\n", "123\nother: value",
                            "9223372036854775808", "-9223372036854775809"]],
        ]
        for values in invalid:
            result = render(values)
            assert result.returncode != 0, "Invalid configuration accepted"
            assert "TELEGRAM_" in result.stderr
            assert TOKEN not in result.stdout + result.stderr
            assert not config.exists(), "Invalid credentials reached rendering"
    print(f"PASS: {len(cases)} valid renders, {len(invalid)} rejections, "
          f"{len(cases) * len(ROUTES)} routing checks, no credential logging")
    print("PASS: official-image amtool validation" if args.image else
          "NOTE: Docker/amtool checks require --image; local checks use shell and PyYAML")


if __name__ == "__main__":
    main()
