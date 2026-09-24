import os
import json
from pathlib import Path
from typing import Dict, Any
from openai import OpenAI
from .models import ExecutionPlan, SubTask
from .config import Config

def scan_codebase_context(target_dir: Path, max_depth: int = 3, max_files: int = 60) -> str:
    """
    Lightweight scanner that builds a compact tree and summaries of key files
    (Package.swift, package.json, Cargo.toml, README.md) without bloating token context.
    """
    if not target_dir.exists():
        return f"Directory {target_dir} does not exist."

    tree_lines = []
    file_count = 0
    key_file_excerpts = []

    for root, dirs, files in os.walk(target_dir):
        # Ignore bulky build / dependency dirs
        dirs[:] = [d for d in dirs if d not in [".build", ".git", "node_modules", "DerivedData", "dist", "__pycache__", ".venv"]]
        rel_root = os.path.relpath(root, target_dir)
        depth = rel_root.count(os.sep)
        if depth >= max_depth:
            continue

        indent = "  " * depth
        folder_name = os.path.basename(root)
        if rel_root != ".":
            tree_lines.append(f"{indent}📁 {folder_name}/")

        for file in sorted(files):
            if file.startswith("."):
                continue
            tree_lines.append(f"{indent}  📄 {file}")
            file_count += 1
            if file_count >= max_files:
                tree_lines.append(f"{indent}  ... (truncated for token efficiency)")
                break

            # Capture key package definitions
            if file in ["Package.swift", "package.json", "pyproject.toml", "Cargo.toml"]:
                full_path = os.path.join(root, file)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read(1500)
                        key_file_excerpts.append(f"--- {file} ({rel_root}) ---\n{content}")
                except Exception:
                    pass

        if file_count >= max_files:
            break

    context = "### Codebase Structure:\n" + "\n".join(tree_lines)
    if key_file_excerpts:
        context += "\n\n### Project Manifest Excerpts:\n" + "\n\n".join(key_file_excerpts)

    return context

def generate_plan_prompt(user_goal: str, codebase_context: str) -> str:
    return f"""You are the Master Software Architect (Codex).
Your mission is to decompose the user's high-level goal into an ordered sequence of atomic, bite-sized tasks.
These tasks will be delegated one by one to an Antigravity worker agent (agy CLI).

Each task MUST be:
1. Self-contained and focused on specific files.
2. Accompanied by concrete instructions on what to change and why.
3. Accompanied by a verification command (e.g. swift test, pytest, npm test, or python script) when possible.

### User Goal:
{user_goal}

### Codebase Context:
{codebase_context}

Please formulate an ExecutionPlan with the goal, architectural summary, and a list of atomic subtasks.
"""

def create_plan(user_goal: str, target_dir: Path, config: Config) -> ExecutionPlan:
    codebase_context = scan_codebase_context(target_dir)

    if not config.openai_api_key:
        raise ValueError(
            "OPENAI_API_KEY is not set. Please set it in your environment or in CodexOrchestrator/.env"
        )

    client = OpenAI(api_key=config.openai_api_key)
    prompt = generate_plan_prompt(user_goal, codebase_context)

    # Use structured outputs via beta parse
    completion = client.beta.chat.completions.parse(
        model=config.codex_model,
        messages=[
            {
                "role": "system",
                "content": "You are a senior software architect designing precise execution plans for automated AI coding workers. Keep plans DRY, focused, and test-driven."
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        response_format=ExecutionPlan,
    )

    plan = completion.choices[0].message.parsed
    return plan
