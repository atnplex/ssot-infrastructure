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
            cwd=os.getcwd(), # Use current directory
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
    # Fetch Project ID and Fields
    query = """
    query($org: String!, $number: Int!) {
      organization(login: $org) {
        projectV2(number: $number) {
          id
          fields(first: 20) {
            nodes {
              ... on ProjectV2Field {
                id
                name
                dataType
              }
              ... on ProjectV2SingleSelectField {
                id
                name
                dataType
                options {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }
    """
    cmd = ['gh', 'api', 'graphql', '-f', f'query={query}', '-F', f'org={org}', '-F', f'number={number}']
    
    output = run_command(cmd)
    if not output:
        return None, None
    
    data = json.loads(output)
    project = data['data']['organization']['projectV2']
    return project['id'], project['fields']['nodes']

def fetch_items(project_id):
    print("Fetching Project Items...")
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
                  title
                  author { login }
                  labels(first: 10) { nodes { name } }
                  assignees(first: 1) { nodes { login } }
                }
                ... on PullRequest {
                  title
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
    print(f"  -> Updating field {field_id} to '{value}'...")
    if DRY_RUN:
        return

    if is_single_select:
        mutation = """
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(
            input: {
              projectId: $projectId
              itemId: $itemId
              fieldId: $fieldId
              value: { singleSelectOptionId: $optionId }
            }
          ) {
            projectV2Item { id }
          }
        }
        """
        variables = {"projectId": project_id, "itemId": item_id, "fieldId": field_id, "optionId": value}
    else:
        return 

    cmd = ['gh', 'api', 'graphql', '-f', f'query={mutation}', '-F', f'variables={json.dumps(variables)}']
    run_command(cmd)

def main():
    print("Starting Project Gardener...")
    if DRY_RUN:
        print("[DRY RUN MODE] No changes will be applied.")

    project_id, fields = fetch_project_data(ORG, PROJECT_NUMBER)
    if not project_id:
        print("Failed to fetch project.")
        return

    # Map Fields
    field_map = {f['name']: f for f in fields}
    
    status_field = field_map.get('Status')
    priority_field = field_map.get('Priority')
    
    # Get Option IDs
    status_options = {opt['name']: opt['id'] for opt in status_field['options']} if status_field else {}
    priority_options = {opt['name']: opt['id'] for opt in priority_field['options']} if priority_field else {}

    items = fetch_items(project_id)
    print(f"Processing {len(items)} items...")

    for item in items:
        item_id = item['id']
        content = item['content']
        if not content: continue 
        
        title = content.get('title', 'Unknown')
        author = content.get('author', {}).get('login') if content.get('author') else None
        labels = [l['name'] for l in content.get('labels', {}).get('nodes', [])]
        assignees = content.get('assignees', {}).get('nodes', [])
        updated_at_str = item.get('updatedAt')
        
        current_values = {}
        for fv in item['fieldValues']['nodes']:
            if not fv: continue
            field_name = fv['field'].get('name')
            if 'name' in fv: val = fv['name'] 
            elif 'text' in fv: val = fv['text']
            elif 'date' in fv: val = fv['date']
            else: val = None
            current_values[field_name] = val

        print(f"Checking '{title}'...")

        # 1. Rule: Set Status to Todo if empty
        if 'Status' not in current_values and status_field:
            todo_option_id = status_options.get('Todo')
            if todo_option_id:
                print(f"  [Action] Status is empty. Setting to 'Todo'.")
                update_item_field(project_id, item_id, status_field['id'], todo_option_id)

        # 2. Rule: Set Priority based on labels if empty
        if priority_field and 'Priority' not in current_values:
            target_priority = None
            for label in labels:
                normalized = label.lower()
                for key, prio in LABEL_PRIORITY_MAP.items():
                    if key in normalized:
                        target_priority = prio
                        break
                if target_priority: break
            
            if not target_priority:
                target_priority = DEFAULT_PRIORITY
                
            target_option_id = None
            for name, opt_id in priority_options.items():
                if target_priority in name:
                    target_option_id = opt_id
                    break
            
            if target_option_id:
                print(f"  [Action] Priority empty. Derived '{target_priority}' from labels/default.")
                update_item_field(project_id, item_id, priority_field['id'], target_option_id)

        # 3. Rule: Auto-assign Creator
        if not assignees and author:
             print(f"  [Suggestion] Issue unassigned. Should assign to creator @{author}.")

        # 4. Rule: Stale Item Detection
        if updated_at_str:
            last_update = datetime.datetime.fromisoformat(updated_at_str.replace('Z', '+00:00'))
            days_inactive = (datetime.datetime.now(datetime.timezone.utc) - last_update).days
            if days_inactive > 30 and current_values.get('Status') != 'Done':
                print(f"  [Suggestion] Item is stale ({days_inactive} days). Consider closing or downgrading priority.")

if __name__ == "__main__":
    main()