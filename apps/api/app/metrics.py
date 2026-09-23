from prometheus_client import Counter, Histogram

redirects_total = Counter("linkly_redirects_total", "Total number of redirects served")
cache_hits_total = Counter("linkly_cache_hits_total", "Redis cache hits for code lookups")
cache_misses_total = Counter("linkly_cache_misses_total", "Redis cache misses for code lookups")
redirect_latency_seconds = Histogram(
    "linkly_redirect_latency_seconds", "Latency of the redirect lookup path"
)
