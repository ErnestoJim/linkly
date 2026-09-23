from prometheus_client import Counter

clicks_processed_total = Counter(
    "linkly_clicks_processed_total", "Total number of click events persisted"
)
worker_errors_total = Counter(
    "linkly_worker_errors_total", "Total number of errors while processing a batch"
)
