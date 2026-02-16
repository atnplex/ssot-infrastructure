import os
import subprocess
import json
import time

# Configuration
ORG = "atnplex"
# DRY_RUN defaults to False unless set to 'true' in env
DRY_RUN = os.getenv('DRY_RUN', 'False').lower() == 'true'

# Heuristic Mapping
TOPIC_MAP = {
    "infra": ["infrastructure", "terraform", "automation"],
    "ai": ["ai", "machine-learning", "llm"],
    "docs": ["documentation", "knowledge-base"],
    "library": ["python", "library", "utility"],
    "action": ["github-actions", "ci-cd"],
    "docker": ["docker", "container"],
    "home": ["homelab", "self-hosted"],
    "bot": ["bot", "automation"],
    "api": ["api", "service"],
    "web": ["web", "frontend"],
    "repo": ["template", "scaffolding"]
}
DEFAULT_TOPICS = ["atnplex"]

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
        return None

def fetch_repos(org):
    print(f"Fetching all repositories for {org}...")
    # Fetch Topics and Description directly
    cmd = ['gh', 'repo', 'list', org, '--limit', '1000', '--json', 'name,description,repositoryTopics']
    output = run_command(cmd)
    if output: return json.loads(output)
    return []

def get_topics_for_repo(name):
    # Start with default
    topics = set(DEFAULT_TOPICS)
    
    # Add based on name matching
    name_lower = name.lower()
    for key, tags in TOPIC_MAP.items():
        if key in name_lower:
            topics.update(tags)
            
    # Add based on specific known repos
    if name == 'infrastructure': topics.update(['devops', 'management'])
    if name == '.github': topics.update(['configuration', 'governance'])
    
    return list(topics)

def main():
    print(f"Starting Compliance Remediation for {ORG}...\n")
    if DRY_RUN: print("[DRY RUN MODE] No changes will be applied.\n")
    
    repos = fetch_repos(ORG)
    
    for repo in repos:
        name = repo['name']
        desc = repo.get('description', '')
        current_topics = repo.get('repositoryTopics', []) or []
        
        print(f"Checking {name}...")
        
        # 1. Fix Topics
        if not current_topics:
            new_topics = get_topics_for_repo(name)
            print(f"  -> Missing Topics. Identifying: {new_topics}")
            
            if not DRY_RUN:
                # Construct command: gh repo edit ORG/REPO --add-topic topic1 --add-topic topic2
                cmd = ['gh', 'repo', 'edit', f"{ORG}/{name}"]
                for t in new_topics:
                    cmd.extend(['--add-topic', t])
                
                print(f"  -> Applying topics...")
                run_command(cmd)
        
        # 2. Fix Description
        if not desc:
            # Generate a smart default
            new_desc = f"Official repository for {name} within the atnplex ecosystem."
            if name == '.github': new_desc = "Organization-wide configuration and governance."
            
            print(f"  -> Missing Description. Setting to: '{new_desc}'")
            
            if not DRY_RUN:
                run_command(['gh', 'repo', 'edit', f"{ORG}/{name}", '--description', new_desc])

    print("\nRemediation Complete.")

if __name__ == "__main__":
    main()
