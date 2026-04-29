#!/usr/bin/env python3
"""
📹 CCTV: 파일 수정 기록 장치
PostToolUse (Edit/Write/MultiEdit) 때 실행
누가 언제 어떤 파일을 건드렸는지 자동 기록
"""
import sys
import json
from datetime import datetime
from pathlib import Path


def main():
    try:
        input_data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    session_id = input_data.get("session_id", "unknown")

    # 파일 경로 추출 (Edit, Write, MultiEdit 공통 필드)
    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    log_dir = Path.home() / ".claude" / "logs"
    sessions_dir = log_dir / "sessions"
    log_dir.mkdir(parents=True, exist_ok=True)
    sessions_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%H:%M:%S")
    filename = Path(file_path).name

    # 영구 CCTV 로그 (모든 세션 누적)
    cctv_log = log_dir / "file-changes.log"
    with open(cctv_log, "a", encoding="utf-8") as f:
        f.write(f"{filename}\t{timestamp}\t{file_path}\n")

    # 세션별 수정 파일 목록 (중복 제거)
    session_file = sessions_dir / f"{session_id}.txt"
    existing = set()
    if session_file.exists():
        existing = set(session_file.read_text(encoding="utf-8").strip().splitlines())

    if file_path not in existing:
        with open(session_file, "a", encoding="utf-8") as f:
            f.write(f"{file_path}\n")


if __name__ == "__main__":
    main()
