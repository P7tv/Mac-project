import time
import subprocess
from pathlib import Path
from typing import Tuple
from .models import SubTask, TaskResult
from .config import Config

class AntigravityWorker:
    def __init__(self, config: Config, target_dir: Path):
        self.config = config
        self.target_dir = target_dir

    def format_task_prompt(self, task: SubTask, retry_feedback: str = "") -> str:
        prompt_lines = [
            f"You are a focused Antigravity coding worker assigned to execute Task #{task.task_id}: {task.title}.",
            "",
            "### Instructions:",
            task.description,
            ""
        ]

        if task.target_files:
            prompt_lines.append("### Target Files:")
            for f in task.target_files:
                prompt_lines.append(f"- {f}")
            prompt_lines.append("")

        if task.verification_command:
            prompt_lines.append("### Verification Command:")
            prompt_lines.append(f"Execute: `{task.verification_command}` to verify your edits pass.")
            prompt_lines.append("")

        if retry_feedback:
            prompt_lines.append("### Feedback from previous failed attempt:")
            prompt_lines.append(retry_feedback)
            prompt_lines.append("Please diagnose the issue and fix it.")
            prompt_lines.append("")

        prompt_lines.append("### Requirements:")
        prompt_lines.append("1. Modify or create the required files directly.")
        prompt_lines.append("2. Run the verification command and confirm it passes.")
        prompt_lines.append("3. Provide a concise summary of changes and test results.")

        return "\n".join(prompt_lines)

    def execute_task(self, task: SubTask) -> TaskResult:
        start_time = time.time()
        retries = 0
        last_error = ""

        while retries <= self.config.max_retries:
            prompt = self.format_task_prompt(task, retry_feedback=last_error)
            
            cmd = [
                self.config.agy_path,
                "-p", prompt,
                "--dangerously-skip-permissions",
                "--output-format", "text"
            ]

            try:
                proc = subprocess.run(
                    cmd,
                    cwd=str(self.target_dir),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=self.config.worker_timeout_seconds
                )

                output = proc.stdout.strip()
                stderr = proc.stderr.strip()
                duration = time.time() - start_time

                if proc.returncode == 0:
                    summary = output[-500:] if len(output) > 500 else output
                    return TaskResult(
                        task_id=task.task_id,
                        title=task.title,
                        status="SUCCESS",
                        summary=summary,
                        output=output,
                        duration_seconds=duration,
                        retries_used=retries
                    )
                else:
                    last_error = f"agy exited with code {proc.returncode}.\nStderr: {stderr}\nStdout: {output[-300:]}"
                    retries += 1

            except subprocess.TimeoutExpired:
                last_error = f"Task timed out after {self.config.worker_timeout_seconds} seconds."
                retries += 1
            except Exception as e:
                last_error = f"Subprocess error: {str(e)}"
                retries += 1

        duration = time.time() - start_time
        return TaskResult(
            task_id=task.task_id,
            title=task.title,
            status="FAILED",
            summary=last_error[:500],
            output=last_error,
            duration_seconds=duration,
            retries_used=retries - 1
        )
