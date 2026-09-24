#!/usr/bin/env python3
import sys
import argparse
from pathlib import Path
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

from .config import load_config
from .models import ExecutionPlan
from .planner import create_plan
from .worker import AntigravityWorker
from .token_tracker import TokenTracker

console = Console()

def print_banner():
    banner = """[bold cyan]╔═══════════════════════════════════════════════════════════════╗
║   🧠 CODEX ⟷ ANTIGRAVITY ORCHESTRATOR (Token Saver Pro)    ║
║   Architect: OpenAI Codex | Worker: Google Antigravity (agy) ║
╚═══════════════════════════════════════════════════════════════╝[/bold cyan]"""
    console.print(banner)

def main():
    parser = argparse.ArgumentParser(
        description="Codex ⟷ Antigravity Orchestrator: High-level planning via Codex, execution via Antigravity."
    )
    parser.add_argument("goal", nargs="?", help="High-level goal or task to execute")
    parser.add_argument("--target-dir", default=".", help="Target project directory (default: current directory)")
    parser.add_argument("--dry-run", action="store_true", help="Generate the plan from Codex but do not execute with Antigravity")
    parser.add_argument("--auto", action="store_true", help="Automatically proceed without prompting between tasks")
    args = parser.parse_args()

    print_banner()

    config = load_config()
    target_path = Path(args.target_dir).resolve()

    if not args.goal:
        console.print("[bold yellow]Enter your high-level coding goal:[/bold yellow]")
        user_goal = console.input("[cyan]> [/cyan]").strip()
        if not user_goal:
            console.print("[red]Goal cannot be empty. Exiting.[/red]")
            sys.exit(1)
    else:
        user_goal = args.goal

    console.print(f"\n[bold green]🎯 Target Project:[/bold green] [underline]{target_path}[/underline]")
    console.print(f"[bold green]🧠 Master Architect:[/bold green] {config.codex_model}")
    console.print(f"[bold green]⚡ Worker Agent:[/bold green] {config.agy_path}\n")

    # Step 1: Codex Planning Phase
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold cyan]Codex is analyzing codebase and formulating execution plan...[/bold cyan]"),
        transient=True
    ) as progress:
        progress.add_task("plan", total=None)
        try:
            plan: ExecutionPlan = create_plan(user_goal=user_goal, target_dir=target_path, config=config)
        except Exception as e:
            console.print(f"[bold red]❌ Planning Error:[/bold red] {e}")
            sys.exit(1)

    # Display Plan
    console.print(Panel(
        f"[bold white]{plan.architectural_summary}[/bold white]",
        title="[bold green]🏛️ Codex Architectural Blueprint[/bold green]",
        border_style="green"
    ))

    table = Table(title="📋 Delegated Subtasks", show_header=True, header_style="bold magenta")
    table.add_column("#", style="dim", width=4)
    table.add_column("Title", style="cyan", width=28)
    table.add_column("Target Files", style="yellow")
    table.add_column("Verification", style="green")

    for task in plan.tasks:
        files = ", ".join([Path(f).name for f in task.target_files]) if task.target_files else "-"
        verif = task.verification_command or "None"
        table.add_row(str(task.task_id), task.title, files, verif)

    console.print(table)

    if args.dry_run:
        console.print("\n[bold yellow]✨ Dry-run mode completed. No files were modified.[/bold yellow]")
        sys.exit(0)

    if not args.auto:
        console.print("\n[bold yellow]Proceed with executing this plan with Antigravity? (y/n):[/bold yellow] ", end="")
        choice = input().strip().lower()
        if choice != "y":
            console.print("[dim]Aborted by user.[/dim]")
            sys.exit(0)

    # Step 2: Antigravity Execution Phase
    worker = AntigravityWorker(config=config, target_dir=target_path)
    tracker = TokenTracker()

    console.print("\n[bold cyan]🚀 Starting Antigravity Worker Execution...[/bold cyan]\n")

    for task in plan.tasks:
        console.print(f"[bold blue]━━━ Executing Task #{task.task_id}: {task.title} ━━━[/bold blue]")

        with Progress(
            SpinnerColumn(),
            TextColumn(f"[bold yellow]Antigravity working on Task #{task.task_id}...[/bold yellow]"),
            transient=True
        ) as progress:
            progress.add_task("work", total=None)
            result = worker.execute_task(task)
            tracker.log_task_result(result)

        if result.status == "SUCCESS":
            console.print(f"[bold green]✅ Task #{task.task_id} Completed ({result.duration_seconds:.1f}s)[/bold green]")
            if result.summary:
                console.print(f"[dim]{result.summary.strip()}[/dim]\n")
        else:
            console.print(f"[bold red]❌ Task #{task.task_id} Failed:[/bold red]\n{result.output}")
            console.print("\n[bold red]Pipeline halted due to task failure.[/bold red]")
            break

    # Step 3: Summary and Token Savings Report
    savings = tracker.compute_savings_estimate()
    summary_panel = f"""
[bold green]Tasks Executed:[/bold green] {tracker.antigravity_tasks_count} / {len(plan.tasks)}
[bold green]Estimated Tokens Used:[/bold green] ~{savings['orchestrated_tokens']:,} tokens
[bold yellow]Monolithic Chat Tokens Avoided:[/bold yellow] ~{savings['estimated_monolithic_tokens']:,} tokens
[bold cyan]⚡ Estimated Token Savings:[/bold cyan] [bold green]~{savings['saved_tokens']:,} tokens ({savings['savings_percentage']}%) 🚀[/bold green]
"""
    console.print(Panel(summary_panel.strip(), title="[bold cyan]📊 Execution & Token Economy Report[/bold cyan]", border_style="cyan"))

if __name__ == "__main__":
    main()
