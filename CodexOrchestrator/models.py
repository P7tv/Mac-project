from typing import List, Optional
from pydantic import BaseModel, Field

class SubTask(BaseModel):
    task_id: int = Field(description="Sequential task identifier (1, 2, 3...)")
    title: str = Field(description="Short concise title of the task")
    description: str = Field(description="Detailed instructions of what Antigravity should do")
    target_files: List[str] = Field(default_factory=list, description="List of file paths to create or modify")
    verification_command: Optional[str] = Field(default=None, description="Command to verify changes (e.g. swift test, pytest, npm test)")

class ExecutionPlan(BaseModel):
    goal: str = Field(description="High-level goal of the user request")
    architectural_summary: str = Field(description="Codex's high-level strategy and design decisions")
    tasks: List[SubTask] = Field(description="Ordered list of atomic subtasks to dispatch to Antigravity")

class TaskResult(BaseModel):
    task_id: int
    title: str
    status: str  # "SUCCESS", "FAILED", "SKIPPED"
    summary: str
    output: str
    duration_seconds: float
    retries_used: int = 0
