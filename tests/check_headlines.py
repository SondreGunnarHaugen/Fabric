import os
import re
import sys
from pathlib import Path

def check_markdown_files():
    failed_files = []
    
    # Matches exactly one '#' followed by a space at the start of a line
    h1_pattern = re.compile(r'^#\s+(.*)')

    # Find all .md files in the repository
    md_files = Path('.').rglob('*.md')

    for file_path in md_files:
        h1_count = 0
        in_code_block = False
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    stripped_line = line.strip()
                    
                    # Toggle code block state to ignore `#` inside code snippets
                    if stripped_line.startswith('```'):
                        in_code_block = not in_code_block
                        continue
                        
                    if not in_code_block and h1_pattern.match(line):
                        h1_count += 1
                        
            # The script flags any file with more than 1 headline.
            # (If you also want to fail files with 0 headlines, change this to: if h1_count != 1:)
            if h1_count > 1:
                # This special print syntax creates an inline annotation in GitHub's UI
                print(f"::error file={file_path}::Found {h1_count} H1 headlines. Only 1 is allowed.")
                failed_files.append(file_path)
                
        except Exception as e:
            print(f"Error reading {file_path}: {e}")

    if failed_files:
        print(f"\nValidation failed: {len(failed_files)} file(s) contain multiple headlines.")
        sys.exit(1) # Exiting with 1 fails the GitHub Action
    else:
        print("Success: No Markdown files contain multiple H1 headlines.")
        sys.exit(0)

if __name__ == "__main__":
    check_markdown_files()