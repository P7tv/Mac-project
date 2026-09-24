import os
from pathlib import Path
from dataclasses import dataclass

@dataclass
class Config:
    openai_api_key: str
    codex_model: str
    agy_path: str
    max_retries: int
    worker_timeout_seconds: int

def load_config() -> Config:
    # Look for .env file in the current directory or parent directories
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, val = line.split("=", 1)
                    key = key.strip()
                    val = val.strip().strip("'\"")
                    if key and key not in os.environ:
                        os.environ[key] = val

    # Default agy path on macOS
    default_agy = str(Path.home() / ".local" / "bin" / "agy")
    if not Path(default_agy).exists():
        default_agy = "agy"

    return Config(
        openai_api_key=os.environ.get("OPENAI_API_KEY", ""),
        codex_model=os.environ.get("CODEX_MODEL", "gpt-4o"),
        agy_path=os.environ.get("AGY_PATH", default_agy),
        max_retries=int(os.environ.get("MAX_RETRIES", "2")),
        worker_timeout_seconds=int(os.environ.get("WORKER_TIMEOUT_SECONDS", "300"))
    )
