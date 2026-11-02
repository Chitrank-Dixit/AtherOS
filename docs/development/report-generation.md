# Sprint 0 report generation

`scripts/generate-report.py` currently prints the manually maintained Sprint 0 Markdown report. It is a display helper, not a report generator.

If evidence records become numerous enough to justify automation, the script may generate a deterministic evidence summary from JSON records that have already passed the schema validator. Keep interpretation, recommendations, risk analysis, and other editorial conclusions manually authored. Missing evidence must appear as `NOT TESTED`, and weighted scores must remain absent when their evidence is incomplete. This is deferred; no report-generation framework or dependency is needed for the current record set.
