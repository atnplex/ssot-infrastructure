import os
import subprocess
import json
import base64
import sys

# Configuration
ORG = "atnplex"
REUSABLE_WORKFLOW = "atnplex/legacy-actions/.github/workflows/reusable-governance.yml@main"
DRY_RUN = False # Set to True to verify first

def run_command(command, use_shell=False, input_text=None):
    """Run a shell command and return the output."""
    try:
        if isinstance(command, list):
            use_shell = False
        result = subprocess.run(
            command,
            cwd=os.getcwd(), 
            shell=use_shell,
            check=True,
            capture_output=True,
            text=True,
            encoding='utf-8',
            input=input_text
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        # print(f"Error running command: {command}")
        # print(f"Stderr: {e.stderr}")
        return None

def fetch_all_repos(org):
    print(f"Fetching all repositories for {org}...")
    cmd = ['gh', 'repo', 'list', org, '--limit', '1000', '--json', 'name,defaultBranchRef']
    output = run_command(cmd)
    if output: return json.loads(output)
    return []

def create_workflow_file(repo_name, default_branch):
    content = f"""name: CI

on:
  push:
    branches: [ "{default_branch}" ]
  pull_request:
    branches: [ "{default_branch}" ]
  workflow_dispatch:

jobs:
  governance:
    uses: {REUSABLE_WORKFLOW}
"""
    return content

def deploy_to_repo(repo):
    name = repo['name']
    default_branch = repo.get('defaultBranchRef', {}).get('name', 'main')
    
    # Skip infrastructure and legacy-actions (they manage themselves)
    if name in ['infrastructure', 'legacy-actions', '.github']:
        print(f"Skipping special repo {name}")
        return

    print(f"Deploying to {name} (branch: {default_branch})...")

    workflow_content = create_workflow_file(name, default_branch)
    
    file_path = ".github/workflows/ci.yml"
    message = "Deploy Organization-wide Governance Workflow"
    
    # 1. Get SHA if exists
    sha = None
    try:
        cmd_get = ['gh', 'api', f'/repos/{ORG}/{name}/contents/{file_path}']
        output = run_command(cmd_get)
        if output:
            data = json.loads(output)
            sha = data.get('sha')
    except:
        pass # File doesn't exist
        
    # 2. Update/Create
    content_b64 = base64.b64encode(workflow_content.encode('utf-8')).decode('utf-8')
    
    data = {
        "message": message,
        "content": content_b64,
        "branch": default_branch
    }
    if sha:
        data["sha"] = sha
        print(f"  -> Updating existing workflow...")
    else:
        print(f"  -> Creating new workflow...")
        
    if not DRY_RUN:
        cmd_put = ['gh', 'api', f'/repos/{ORG}/{name}/contents/{file_path}', '-X', 'PUT', '--input', '-']
        # Use input_text argument for run_command to pass JSON body
        result = run_command(cmd_put, input_text=json.dumps(data))
        if result:
            print(f"  -> Success.")
        else:
            print(f"  -> Failed.")
    else:
        print(f"  -> [DRY RUN] Would deploy.")

def main():
    print("Starting Workflow Deployment...")
    repos = fetch_all_repos(ORG)
    for repo in repos:
        deploy_to_repo(repo)

if __name__ == "__main__":
    main()
