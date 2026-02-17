from mcp.server.fastmcp import FastMCP
import subprocess
import json
import os

mcp = FastMCP("bws")


def run_bws(args):
    token = os.environ.get("BWS_ACCESS_TOKEN")
    if not token:
        raise ValueError("BWS_ACCESS_TOKEN not set")

    cmd = ["bws"] + args + ["--output", "json", "--color", "no"]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env={**os.environ, "BWS_ACCESS_TOKEN": token},
    )
    if result.returncode != 0:
        raise RuntimeError(f"BWS Error: {result.stderr}")

    try:
        return json.loads(result.stdout) if result.stdout.strip() else {}
    except json.JSONDecodeError:
        return {"stdout": result.stdout}


@mcp.tool()
def list_projects(org_id: str = None):
    """List projects in an organization"""
    args = ["project", "list"]
    if org_id:
        args.extend(["--organization-id", org_id])
    return run_bws(args)


@mcp.tool()
def list_secrets(org_id: str = None, project_id: str = None):
    """List secrets, optionally filtered by project"""
    args = ["secret", "list"]
    if org_id:
        args.extend(["--organization-id", org_id])
    if project_id:
        args.extend(["--project-id", project_id])
    return run_bws(args)


@mcp.tool()
def get_secret(secret_id: str):
    """Get full details of a secret by ID"""
    return run_bws(["secret", "get", secret_id])


@mcp.tool()
def create_secret(name: str, value: str, project_id: str, note: str = None):
    """Create a new secret"""
    args = [
        "secret",
        "create",
        "--name",
        name,
        "--value",
        value,
        "--project-id",
        project_id,
    ]
    if note:
        args.extend(["--note", note])
    return run_bws(args)


@mcp.tool()
def delete_secret(secret_id: str):
    """Delete a secret by ID"""
    return run_bws(["secret", "delete", secret_id])


if __name__ == "__main__":
    mcp.run()
