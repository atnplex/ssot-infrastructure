import os
import subprocess
import json
import datetime
import sys

# Configuration
ORG = "atnplex"
PROJECT_NUMBER = 4
# DRY_RUN defaults to False unless set to 'true' in env
DRY_RUN = os.getenv('DRY_RUN', 'False').lower() == 'true'

# Mappings for Label -> Priority (If Priority field exists)
LABEL_PRIORITY_MAP = {
    "critical": "P0",
    "high": "P1",
    "bug": "P1",
    "enhancement": "P2",
    "feature": "P2",
    "documentation": "P3"
}
DEFAULT_PRIORITY = "P2"

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
        print(f"Error running command: {command}")
        print(f"Stderr: {e.stderr}")
        return None

def fetch_project_data(org, number):
    print(f"Fetching Project Data for {org}/projects/{number}...")
    query = """
    query($org: String!, $number: Int!) {
      organization(login: $org) {
        projectV2(number: $number) {
          id
          fields(first: 20) {
            nodes {
              ... on ProjectV2Field { id, name, dataType }
              ... on ProjectV2SingleSelectField {
                id, name, dataType
                options { id, name }
              }
            }
          }
        }
      }
    }
    """
    cmd = ['gh', 'api', 'graphql', '-f', f'query={query}', '-F', f'org={org}', '-F', f'number={number}']
    output = run_command(cmd)
    if not output: return None, None
    data = json.loads(output)
    project = data['data']['organization']['projectV2']
    return project['id'], project['fields']['nodes']

def fetch_items(project_id):
    print("Fetching Project Items for Gardening...")
    query = """
    query($projectId: ID!) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100) {
            nodes {
              id
              updatedAt
              content {
                ... on Issue {
                  id
                  number
                  repository { name, owner { login } }
                  title
                  state
                  author { login }
                  labels(first: 10) { nodes { name } }
                  assignees(first: 1) { nodes { login } }
                }
                ... on PullRequest {
                  id
                  number
                  repository { name, owner { login } }
                  title
                  state
                  author { login }
                  labels(first: 10) { nodes { name } }
                  assignees(first: 1) { nodes { login } }
                }
              }
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    field { ... on ProjectV2FieldCommon { name } }
                    name
                  }
                  ... on ProjectV2ItemFieldTextValue {
                    field { ... on ProjectV2FieldCommon { name } }
                    text
                  }
                  ... on ProjectV2ItemFieldDateValue {
                   field { ... on ProjectV2FieldCommon { name } }
                    date
                  }
                }
              }
            }
          }
        }
      }
    }
    """
    cmd = ['gh', 'api', 'graphql', '-f', f'query={query}', '-F', f'projectId={project_id}']
    output = run_command(cmd)
    if output:
        return json.loads(output)['data']['node']['items']['nodes']
    return []

def update_item_field(project_id, item_id, field_id, value, is_single_select=True):
    print(f"    -> Updating field {field_id} to '{value}'...")
    if DRY_RUN: return

    if is_single_select:
        mutation = """
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(
            input: {
              projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
            }
          ) { projectV2Item { id } }
        }
        """
        variables = {"projectId": project_id, "itemId": item_id, "fieldId": field_id, "optionId": value}
        cmd = ['gh', 'api', 'graphql', '-f', f'query={mutation}', '-F', f'variables={json.dumps(variables)}']
        run_command(cmd)

def add_item_to_project(project_id, content_id):
    print(f"    -> Adding content {content_id} to project...")
    if DRY_RUN: return
    
    mutation = """
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
    """
    cmd = ['gh', 'api', 'graphql', '-f', f'query={mutation}', '-F', f'projectId={project_id}', '-F', f'contentId={content_id}']
    run_command(cmd)

def fetch_all_repos(org):
    print(f"Fetching all repositories for {org}...")
    cmd = ['gh', 'repo', 'list', org, '--limit', '1000', '--json', 'name']
    output = run_command(cmd)
    if output: return [r['name'] for r in json.loads(output)]
    return []

def fetch_repo_open_items(org, repo):
    # Fetch open issues and PRs with their IDs
    query = """
    query($owner: String!, $repo: String!) {
      repository(owner: $owner, name: $repo) {
        issues(states: OPEN, first: 100) { nodes { id, title } }
        pullRequests(states: OPEN, first: 100) { nodes { id, title } }
      }
    }
    """
    cmd = ['gh', 'api', 'graphql', '-f', f'query={query}', '-F', f'owner={org}', '-F', f'repo={repo}']
    output = run_command(cmd)
    items = []
    if output:
        data = json.loads(output)
        if 'data' in data and 'repository' in data['data'] and data['data']['repository']:
            repo_data = data['data']['repository']
            items.extend(repo_data['issues']['nodes'])
            items.extend(repo_data['pullRequests']['nodes'])
    return items

def main():
    print("Starting Project Gardener...")
    if DRY_RUN: print("[DRY RUN MODE] No changes will be applied.")

    project_id, fields = fetch_project_data(ORG, PROJECT_NUMBER)
    if not project_id:
        print("Failed to fetch project.")
        return

    # Map Fields
    field_map = {f['name']: f for f in fields}
    status_field = field_map.get('Status')
    priority_field = field_map.get('Priority')
    
    status_options = {opt['name']: opt['id'] for opt in status_field['options']} if status_field else {}
    priority_options = {opt['name']: opt['id'] for opt in priority_field['options']} if priority_field else {}

    # --- Phase 1: Garden Existing Items ---
    project_items = fetch_items(project_id)
    print(f"Gardening {len(project_items)} existing items...")
    
    # Store IDs of content (Issues/PRs) already on board to check for orphans
    content_ids_on_board = set()

    for item in project_items:
        item_id = item['id']
        content = item['content']
        if not content: continue 
        
        # Track content ID
        content_id = content.get('id')
        if content_id: content_ids_on_board.add(content_id)

        title = content.get('title', 'Unknown')
        state = content.get('state') # OPEN, CLOSED, MERGED
        author = content.get('author', {}).get('login') if content.get('author') else None
        labels = [l['name'] for l in content.get('labels', {}).get('nodes', [])]
        assignees = content.get('assignees', {}).get('nodes', [])
        updated_at_str = item.get('updatedAt')
        
        is_closed = state in ['CLOSED', 'MERGED']
        
        current_values = {}
        for fv in item['fieldValues']['nodes']:
            if not fv: continue
            field_name = fv['field'].get('name')
            if 'name' in fv: val = fv['name'] 
            elif 'text' in fv: val = fv['text']
            elif 'date' in fv: val = fv['date']
            else: val = None
            current_values[field_name] = val
            
        current_status = current_values.get('Status')
        status_updated_in_this_pass = False

        print(f"Checking '{title}' (State: {state}, Status: {current_status})...")

        # 1. State Sync: Closed/Merged -> Done
        if is_closed and status_field and current_values.get('Status') != 'Done':
            done_option_id = status_options.get('Done')
            if done_option_id:
                print(f"  [Sync] Content is closed. Setting Project Status to 'Done'.")
                update_item_field(project_id, item_id, status_field['id'], done_option_id)
                status_updated_in_this_pass = True
            else:
                print(f"  [Warning] 'Done' status option not found for Status field.")

        # 2a. Auto-Progression: AI Assigned -> In Progress
        if not status_updated_in_this_pass and not is_closed and 'ai-assigned' in labels and current_values.get('Status') != 'In Progress':
             wip_option_id = status_options.get('In Progress')
             if wip_option_id:
                 print(f"  [Progression] Item is AI Assigned. Setting Status to 'In Progress'.")
                 update_item_field(project_id, item_id, status_field['id'], wip_option_id)
                 status_updated_in_this_pass = True

        # 2b. Auto-Progression: PR Open -> In Progress
        if not status_updated_in_this_pass and not is_closed and content.get('__typename') == 'PullRequest' and current_values.get('Status') != 'In Progress':
            wip_option_id = status_options.get('In Progress')
            if wip_option_id:
                print(f"  [Progression] PR is Open. Setting Status to 'In Progress'.")
                update_item_field(project_id, item_id, status_field['id'], wip_option_id)
                status_updated_in_this_pass = True

        # 3. Auto-Progression: Issue Assigned -> In Progress (if currently Todo or Empty)
        if not status_updated_in_this_pass and not is_closed and content.get('__typename') == 'Issue' and assignees and current_values.get('Status') in [None, 'Todo']:
             wip_option_id = status_options.get('In Progress')
             if wip_option_id:
                 print(f"  [Progression] Issue is Assigned. Setting Status to 'In Progress'.")
                 update_item_field(project_id, item_id, status_field['id'], wip_option_id)
                 status_updated_in_this_pass = True

        # 4. Rule: Set Status to Todo if empty (and still empty after above checks)
        if not status_updated_in_this_pass and not is_closed and not current_status and status_field:
            todo_option_id = status_options.get('Todo')
            if todo_option_id:
                print(f"  [Triage] Status is empty. Setting to 'Todo'.")
                update_item_field(project_id, item_id, status_field['id'], todo_option_id)
                status_updated_in_this_pass = True

        # 5. Priority: Derived from labels (Dynamic)
        # Check for Critical first (Enforcement)
        target_priority = None
        force_update = False
        
        # Check for High/Critical labels that should FORCE an update
        for label in labels:
            n_label = label.lower()
            if 'critical' in n_label or 'p0' in n_label:
                target_priority = 'P0'
                force_update = True
                break
            if 'high' in n_label or 'p1' in n_label:
                target_priority = 'P1'
                # Optional: Force update for P1 too? Let's say yes for consistency.
                force_update = True
                break
        
        # If no forced priority, check if empty and derive defaults
        if not target_priority and 'Priority' not in current_values and state == 'OPEN':
            for label in labels:
                normalized = label.lower()
                for key, prio in LABEL_PRIORITY_MAP.items():
                    if key in normalized:
                        target_priority = prio
                        break
                if target_priority: break
            if not target_priority: target_priority = DEFAULT_PRIORITY

        # Apply Update if needed
        if target_priority:
             # Map target string (P0, P1) to Option ID
             target_option_id = None
             for name, opt_id in priority_options.items():
                 # Fuzzy match "P0" in "P0 - Critical"
                 if target_priority in name:
                     target_option_id = opt_id
                     break
             
             if target_option_id:
                 current_prio_val = current_values.get('Priority')
                 # Update if: Forced (and different) OR Empty
                 if (force_update and current_prio_val != target_priority) or (not current_prio_val and not force_update):
                      reason = "Enforced" if force_update else "Derived"
                      print(f"  [Priority] {reason} '{target_priority}' from labels.")
                      update_item_field(project_id, item_id, priority_field['id'], target_option_id)
                      status_updated_in_this_pass = True

        # 5. Stale Detection
        if state == 'OPEN' and updated_at_str:
            last_update = datetime.datetime.fromisoformat(updated_at_str.replace('Z', '+00:00'))
            days_inactive = (datetime.datetime.now(datetime.timezone.utc) - last_update).days
            if days_inactive > 30 and current_status != 'Done':
                print(f"  [Stale] Inactive for {days_inactive} days. Review required.")

        # 6. AI Dispatcher
        if 'ai-pending' in labels:
            # We need repo/number from content
            if content and 'number' in content and 'repository' in content:
                repo_name = content['repository']['name']
                repo_owner = content['repository']['owner']['login']
                issue_num = content['number']
                print(f"  [AI Dispatch] Found 'ai-pending'. Dispatching Agent...")
                assign_ai_to_issue(repo_owner, repo_name, issue_num)

    # --- Phase 2: The Sweeper (Find Orphans) ---
    print("\nStarting Sweeper (Orphan Detection)...")
    repos = fetch_all_repos(ORG)
    for repo in repos:
        # print(f"Scanning {repo}...")
        open_items = fetch_repo_open_items(ORG, repo)
        for item in open_items:
            if item['id'] not in content_ids_on_board:
                print(f"  [Sweeper] Found Orphan in {repo}: '{item['title']}'")
                add_item_to_project(project_id, item['id'])

def assign_ai_to_issue(owner, repo, issue_number):
    print(f"  -> Assigning Copilot to issue {owner}/{repo}#{issue_number}...")
    if DRY_RUN: return
    
    # We use gh api to invoke the copilot assignment if possible, 
    # OR we use the mcp tool directly if we were running as an agent.
    # But this script runs in GH Actions. GH Actions doesn't have access to 'mcp tools'.
    # We will use `gh issue edit` to manage the state via labels.
    
    # Workaround: 
    # I will simply ADD a specific label "copilot:assigned" using `gh issue edit`.
    # GitHub Copilot Workspace often listens for specific triggers or UI interactions.
    
    # Let's assume for now I will just swap the labels, 
    # and IF the user has the workspace trigger set up, it works.
    
    cmd = ['gh', 'issue', 'edit', str(issue_number), '--repo', f"{owner}/{repo}", '--remove-label', 'ai-pending', '--add-label', 'ai-assigned']
    run_command(cmd)

    # Note: Real "Assignment" to Copilot Workspace might need to be done manually 
    # or via the specific "Open in Workspace" button until a public API is stable.
    # But managing the *intent* via labels is a good first step.

    # Also, we can add a comment to summon it?
    # "@github-copilot can you handle this?"
    comment_cmd = ['gh', 'issue', 'comment', str(issue_number), '--repo', f"{owner}/{repo}", '--body', f"@{ORG}/copilot please handle this issue."]
    # run_command(comment_cmd) # commenting might be noisy, let's stick to labels.

    pass

if __name__ == "__main__":
    main()
