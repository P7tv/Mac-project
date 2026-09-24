from dataclasses import dataclass, field
from typing import List
from .models import TaskResult

@dataclass
class TokenTracker:
    codex_input_tokens: int = 0
    codex_output_tokens: int = 0
    antigravity_tasks_count: int = 0
    task_results: List[TaskResult] = field(default_factory=list)

    def log_codex_usage(self, prompt_tokens: int, completion_tokens: int):
        self.codex_input_tokens += prompt_tokens
        self.codex_output_tokens += completion_tokens

    def log_task_result(self, result: TaskResult):
        self.antigravity_tasks_count += 1
        self.task_results.append(result)

    def compute_savings_estimate(self) -> dict:
        """
        Estimates the tokens that WOULD have been spent if done in a single monolithic
        chat session where each turn resends the entire cumulative chat history + codebase files.
        """
        # In a monolithic chat session, every subsequent turn re-sends the cumulative history.
        # N turns of 15,000 tokens context = ~15,000 * N * (N+1)/2 tokens!
        # With the Orchestrator, Codex only spends 1 planning turn (~2,000 tokens),
        # and Antigravity runs isolated stateless sessions per task (~3,000 tokens each).
        n_tasks = max(1, self.antigravity_tasks_count)
        estimated_monolithic_tokens = (5000 + 4000 * n_tasks) * n_tasks
        orchestrated_tokens = self.codex_input_tokens + self.codex_output_tokens + (3000 * n_tasks)
        
        saved_tokens = max(0, estimated_monolithic_tokens - orchestrated_tokens)
        savings_percentage = round((saved_tokens / max(1, estimated_monolithic_tokens)) * 100)

        return {
            "orchestrated_tokens": orchestrated_tokens,
            "estimated_monolithic_tokens": estimated_monolithic_tokens,
            "saved_tokens": saved_tokens,
            "savings_percentage": savings_percentage
        }
