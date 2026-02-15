import os
import subprocess
import json
import time

# Configuration
ORG = "atnplex"
LABEL_TRIGGER = "ai-assigned"
LABEL_RESOLVED = "ai-resolved"
# DRY_RUN defaults to False unless set to 'true' in env
DRY_RUN = os.getenv('DRY_RUN', 'False').lower() == 'true'

def run_command(command, use_shell=False, input_text=None):
    """Run a shell command and return the output."""
    try:
        if isinstance(command, list): use_shell = False
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
        print(f"Error running command: {command}")
        print(f"Stderr: {e.stderr}")
        return None

def fetch_ai_tasks(org):
    print(f"Fetching issues with label '{LABEL_TRIGGER}' in {org}...")
    # Getting issues across the org is tricky with `gh issue list` because it's repo-scoped.
    # We must search.
    query = f"org:{org} label:{LABEL_TRIGGER} state:open"
    cmd = ['gh', 'search', 'issues', query, '--json', 'repository,number,title,body,url']
    output = run_command(cmd)
    try:
        if output: return json.loads(output)
    except json.JSONDecodeError:
        print(f"Error decoding output: {output}")
        return []
    return []

def process_issue(issue):
    repo_object = issue.get('repository', {})
    if not repo_object: return

    repo_url = repo_object.get('url')
    full_name = repo_object.get('nameWithOwner') # e.g. atnplex/repo
    if not full_name: return

    number = issue.get('number')
    title = issue.get('title')
    body = issue.get('body', "")
    
    print(f"Processing Task: {full_name}#{number}: {title}")
    
    if DRY_RUN:
        print(f"  [DRY RUN] Would acknowledge and respond to issue #{number}")
        return

    # 1. Acknowledge
    print(f"  -> Acknowledging on {full_name}#{number}...")
    ack_cmd = ['gh', 'issue', 'comment', str(number), '--repo', full_name, '--body', "🤖 **AI Worker:** I am analyzing this request..."]
    run_command(ack_cmd)
    
    # 2. "Think" (Simulated LLM)
    # response = llm.generate(body)
    
    simulated_response = f"""
**AI Analysis**:
I receive your request: "{title}".

**Proposed Action**:
(This is a simulated response. The AI Worker script is running successfully but currently in "Stub" mode. To enable real AI reasoning, configure the `AI_WORKER_KEY` secret and uncomment the LLM logic in `steps/ai_worker.py`.)

**Context**:
> {title}
"""
    
    # 3. Respond
    print(f"  -> Responding on {full_name}#{number}...")
    resp_cmd = ['gh', 'issue', 'comment', str(number), '--repo', full_name, '--body', simulated_response]
    run_command(resp_cmd)
        
    # 4. Resolve (Swap Labels)
    print(f"  -> Resolving (swap label to '{LABEL_RESOLVED}')...")
    # remove ai-assigned, add ai-resolved
    edit_cmd = ['gh', 'issue', 'edit', str(number), '--repo', full_name, '--remove-label', LABEL_TRIGGER, '--add-label', LABEL_RESOLVED]
    run_command(edit_cmd)

def main():
    print("Starting AI Worker...")
    tasks = fetch_ai_tasks(ORG)
    if not tasks:
        print("No tasks found.")
        return

    print(f"Found {len(tasks)} tasks.")
    
    for task in tasks:
        process_issue(task)

if __name__ == "__main__":
    main()
