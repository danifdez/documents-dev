from typing import Any, Dict
import time
from bson import ObjectId
from typing import Tuple, Optional
from utils.mongo_utils import get_mongo_client

def send_job(job_type: str, priority: str, payload: Dict[str, Any]) -> str:
    """
    Insert a new job document into the 'jobs' collection.
    Args:
        job_type: Type of the job (string)
        priority: Job priority ('normal', 'high', 'low')
        payload: Job payload (dict)
    Returns:
        The inserted job's ID as a string, or raises Exception if connection fails.
    """
    db = get_mongo_client()
    if db is None:
        raise RuntimeError("Failed to connect to MongoDB.")
    job_doc = {
        "type": job_type,
        "priority": priority,
        "payload": payload,
        "status": "pending",  # Initial status
        "expiresAt": time.time() + 3600  # Optional: job expiration time
    }
    result = db.jobs.insert_one(job_doc)
    return str(result.inserted_id)

def send_and_await_job(job_type: str, priority: str, payload: Dict[str, Any], poll_interval: float = 1.0, timeout: float = 60.0) -> Tuple[str, Optional[dict]]:
    """
    Create a new job using send_job and wait until it is processed (status is 'completed' or 'failed').
    Args:
        job_type: Type of the job (string)
        priority: Job priority ('normal', 'high', 'low')
        payload: Job payload (dict)
        poll_interval: How often to poll for job status (seconds)
        timeout: Max time to wait (seconds)
    Returns:
        Tuple of (status, result) where status is 'completed', 'failed', or 'timeout', and result is the job's result or None.
    """
    job_id_str = send_job(job_type, priority, payload)
    db = get_mongo_client()
    if db is None:
        raise RuntimeError("Failed to connect to MongoDB.")
    job_id = ObjectId(job_id_str)

    start_time = time.time()
    while True:
        job = db.jobs.find_one({"_id": job_id})
        if job is None:
            return ("not_found", None)
        status = job.get("status", "pending")
        if status in ("completed", "failed"):
            return (status, job.get("result"))
        if time.time() - start_time > timeout:
            return ("timeout", None)
        time.sleep(poll_interval)
