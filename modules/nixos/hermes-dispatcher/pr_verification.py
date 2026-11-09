"""Read CI/review evidence through T3's forge adapters, never trust an agent's green claim."""

from urllib.parse import urlsplit


def verify(rpc, project_id, links):
    links = [link for link in links if link.get("source") != "stack-dismissed"]
    if not links:
        return {"state": "missing", "reason": "Kein PR mit dem T3-Auftrag verknüpft."}
    checked = []
    for link in links:
        host = link.get("host") or urlsplit(link["url"]).hostname
        if host not in {"github.com", "git.hugo-berendi.de"}:
            return {"state": "unverified", "reason": "PR-Host ist nicht freigegeben."}
        ref = {
            "projectId": project_id,
            "host": host,
            "repository": link["repository"],
            "number": link["number"],
            "allowStale": False,
        }
        before = rpc("pullRequests.detail", ref)
        activity = rpc("pullRequests.activity", ref)
        review = rpc("pullRequests.summary", ref)
        after = rpc("pullRequests.detail", ref)
        sha = before.get("headSha")
        if not sha or sha != after.get("headSha"):
            return {
                "state": "pending",
                "reason": "PR-Head wechselte während der Prüfung oder SHA fehlt.",
            }
        if after["state"] == "merged":
            checked.append({"url": after["url"], "head": sha, "merged": True})
            continue
        if after["state"] != "open":
            return {"state": "unverified", "reason": "PR wurde ohne Merge geschlossen."}
        checks = after.get("checks", [])
        if not checks:
            return {
                "state": "unverified",
                "reason": "Der PR hat keine CI-Checks; er wird nicht als grün bezeichnet.",
            }
        if any(
            c["status"] in {"failure", "cancelled", "action-required"} for c in checks
        ):
            return {
                "state": "failed",
                "reason": "CI meldet einen fehlgeschlagenen oder blockierten Check.",
                "head": sha,
            }
        if after.get("isDraft") or after.get("mergeability") == "conflicting":
            return {
                "state": "failed",
                "reason": "PR ist noch Entwurf oder hat Merge-Konflikte.",
            }
        if after.get("mergeability") != "mergeable":
            return {
                "state": "pending",
                "reason": "PR ist Entwurf, hat Konflikte oder Merge-Status ist unbekannt.",
            }
        if any(
            c["status"] != "success" and c.get("required") is not False for c in checks
        ):
            return {
                "state": "pending",
                "reason": "Erforderliche oder nicht klassifizierte Checks sind noch nicht erfolgreich.",
            }
        if activity.get("reviewThreadsTruncated"):
            return {
                "state": "unverified",
                "reason": "Review-Threads wurden nicht vollständig abgerufen.",
            }
        if any(not t["isResolved"] for t in activity.get("reviewThreads", [])):
            return {
                "state": "failed",
                "reason": "Review-Threads sind offen oder nicht vollständig abgerufen.",
            }
        if review.get("reviewDecision") == "changes-requested":
            return {
                "state": "failed",
                "reason": "Eine Review fordert noch Änderungen.",
            }
        checked.append({"url": after["url"], "head": sha, "merged": False})
    return {
        "state": "merged" if all(p["merged"] for p in checked) else "ready",
        "checked": checked,
    }
