import os
import subprocess
import json
import base64

# Configuration
ORG = "atnplex"

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
        return None

def fetch_all_repos(org):
    print(f"Fetching all repositories for {org}...")
    # Fetch Topics and Description directly
    cmd = ['gh', 'repo', 'list', org, '--limit', '1000', '--json', 'name,description,repositoryTopics,defaultBranchRef']
    output = run_command(cmd)
    if output: return json.loads(output)
    return []

def check_file_exists(org, repo_name, file_path):
    cmd = ['gh', 'api', f'/repos/{org}/{repo_name}/contents/{file_path}', '--silent']
    # If 0, exists. If 1, not found.
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    print(f"Starting Repository Audit for {ORG}...\n")
    repos = fetch_all_repos(ORG)
    
    report_data = []
    
    # Print Header
    print(f"{'Repository':<30} | {'Topics':<8} | {'Desc':<8} | {'README':<8}")
    print("-" * 65)
    
    compliance_score = 0
    total_repos = len(repos)
    
    for repo in repos:
        name = repo['name']
        desc = repo.get('description', '')
        topics = repo.get('repositoryTopics', []) or []
        
        has_topics = len(topics) > 0
        has_desc = bool(desc)
        has_readme = check_file_exists(ORG, name, "README.md")
        # has_workflows = check_file_exists(ORG, name, ".github/workflows")

        # Score
        score = 0
        if has_topics: score += 1
        if has_desc: score += 1
        if has_readme: score += 1
        
        # print specific status
        t_icon = "✅" if has_topics else "❌"
        d_icon = "✅" if has_desc else "❌"
        r_icon = "✅" if has_readme else "❌"
        
        print(f"{name:<30} | {t_icon:<8} | {d_icon:<8} | {r_icon:<8}")
        
        if score == 3: compliance_score += 1
        
        report_data.append({
            "name": name,
            "has_topics": has_topics,
            "has_desc": has_desc,
            "has_readme": has_readme
        })

    print("-" * 65)
    print(f"\n Compliance Summary: {compliance_score}/{total_repos} Repositories are Fully Compliant.")
    
    # Generate Markdown Report
    with open("compliance_report.md", "w", encoding='utf-8') as f:
        f.write(f"# Compliance Report for {ORG}\n\n")
        f.write(f"**Score**: {compliance_score}/{total_repos} ({int(compliance_score/total_repos*100) if total_repos > 0 else 0}%)\n\n")
        f.write("| Repository | Topics | Description | README | Status |\n")
        f.write("|------------|--------|-------------|--------|--------|\n")
        for r in report_data:
            status = "✅" if (r['has_topics'] and r['has_desc'] and r['has_readme']) else "⚠️"
            f.write(f"| {r['name']} | {'✅' if r['has_topics'] else '❌'} | {'✅' if r['has_desc'] else '❌'} | {'✅' if r['has_readme'] else '❌'} | {status} |\n")
            
    print("Report saved to compliance_report.md")

if __name__ == "__main__":
    main()
