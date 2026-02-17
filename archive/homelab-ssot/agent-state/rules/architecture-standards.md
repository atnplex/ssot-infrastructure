# Architecture Standards

> **ID**: `architecture-standards`
> **Version**: 1.0.0
> **Status**: Active

## 1. Python MCP Tool Wrappers

All local Python-based MCP tools **MUST** use a launcher wrapper script.

### Rules

1. **Wrapper Required**: Every Python MCP tool MUST have a `start.bat` (Windows) or `start.sh` (Linux/macOS) wrapper script.

2. **Venv Isolation**: Wrappers MUST create a local `.venv` virtual environment, install dependencies from a co-located `requirements.txt`, and execute the tool using the venv's Python interpreter.

3. **No Global Python**: Never rely on global `pip`, global `python`, or system-level environment variables for dependency resolution. The wrapper is the single entry point.

4. **Self-Healing**: The wrapper MUST be idempotent — if the `.venv` is missing or corrupted, it recreates it automatically on next launch.

### Standard Directory Layout

```
.agent-state/mcp-proxies/<tool-name>/
├── start.bat          # Windows launcher
├── start.sh           # Linux/macOS launcher (if applicable)
├── requirements.txt   # Pinned dependencies
├── <tool_script>.py   # The MCP tool itself
└── .venv/             # Auto-created, gitignored
```

### Reference: Windows `start.bat` Template

```batch
@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "VENV_DIR=%SCRIPT_DIR%.venv"
set "PYTHON_EXE=%VENV_DIR%\Scripts\python.exe"

if not exist "%PYTHON_EXE%" (
    echo [Launcher] Creating venv... 1>&2
    python -m venv "%VENV_DIR%"
)

"%PYTHON_EXE%" -m pip install -q -r "%SCRIPT_DIR%requirements.txt"
"%PYTHON_EXE%" "%SCRIPT_DIR%<tool_script>.py" %*
```

## 2. MCP Configuration

- MCP config entries MUST point to the launcher wrapper, never directly to a `.py` file.
- The `command` field should be the absolute path to `start.bat` (or `start.sh`).
- The `args` field should be empty (or contain only runtime flags).
