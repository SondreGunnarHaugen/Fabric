# This script recursively walks through the repository, finds all .py and .json files, and replaces any occurrences of the specified sandbox workspace and lakehouse IDs with the corresponding development IDs. 
# It uses repository variables to get the IDs, so make sure to set those in your GitHub Actions workflow before running this script.

import os
import sys

# Read IDs from repository variables
OLD_WORKSPACE_ID   = os.environ["DEV_SANDBOX_SONDRE_WORKSPACE_ID"]
OLD_LAKEHOUSE_ID   = os.environ["DEV_SANDBOX_SONDRE_LAKEHOUSE_ID"]
NEW_WORKSPACE_ID = os.environ["UTVIKLING_WORKSPACE_ID"]
NEW_LAKEHOUSE_ID = os.environ["UTVIKLING_LAKEHOUSE_ID"]

# Define which IDs to replace
# It should only replace the ID's if the ID's are connected to sanbox objects (lakehouse and workspace). If they are conneted to prod objects, they should not be replaced.
REPLACEMENTS = {
    OLD_WORKSPACE_ID: NEW_WORKSPACE_ID,
    OLD_LAKEHOUSE_ID: NEW_LAKEHOUSE_ID,
}

# Define scope of files to process
EXTENSIONS = (".py", ".json")

# Read each file, replace IDs, and write back if changes were made
def process_file(path):
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()

    updated = original
    for old, new in REPLACEMENTS.items():
        updated = updated.replace(old, new)

    if updated != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(updated)
        print(f"Updated: {path}")


def walk_repo(root="."):
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip hidden dirs like .git
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for filename in filenames:
            if filename.endswith(EXTENSIONS):
                process_file(os.path.join(dirpath, filename))

if __name__ == "__main__":
    walk_repo()