"""Explicit model/effort choices: allowlisted, offered by T3, read back before a run.

A wish in the task description is not a configuration. Ciel passes provider,
model and effort as tool arguments; the broker checks them against the
configured allowlist and T3's live catalog, and the backend reads the stored
thread configuration back before any run starts. Nothing here substitutes a
different model or raises the effort on its own.
"""

EFFORT_OPTION = {"codex": "reasoningEffort", "claudeAgent": "effort"}


class ModelNotEnforced(ValueError):
    """T3 stored a different configuration than requested; no run was started."""

    def __init__(self, thread, link, stored):
        super().__init__(
            "T3 hat die angeforderte Modell-/Effort-Konfiguration nicht übernommen"
        )
        self.thread, self.link, self.stored = thread, link, stored


def selection(provider, model, effort):
    option = EFFORT_OPTION[provider]
    options = [{"id": option, "value": effort}]
    if provider == "codex":
        options.append({"id": "serviceTier", "value": "default"})
    return {"instanceId": provider, "model": model, "options": options}


def effort_of(chosen):
    option = EFFORT_OPTION.get((chosen or {}).get("instanceId"))
    return next(
        (
            o.get("value")
            for o in (chosen or {}).get("options") or []
            if o.get("id") == option
        ),
        None,
    )


def matches(expected, actual):
    """True only when T3 stored the same provider, model and every requested option."""
    if not isinstance(actual, dict) or not isinstance(expected, dict):
        return False
    if (actual.get("instanceId"), actual.get("model")) != (
        expected.get("instanceId"),
        expected.get("model"),
    ):
        return False
    stored = {
        o.get("id"): o.get("value")
        for o in actual.get("options") or []
        if isinstance(o, dict)
    }
    return all(stored.get(o["id"]) == o["value"] for o in expected.get("options") or [])


def requested(config, args):
    """The explicit selection in tool arguments, or None when Ciel asked for none."""
    fields = [args.get(k) for k in ("provider", "model", "effort")]
    if not any(fields):
        return None
    if not all(isinstance(v, str) and v for v in fields):
        raise ValueError("provider, model und effort nur gemeinsam angeben")
    provider, model, effort = fields
    allowed = (config.get("selectableModels") or {}).get(provider, {})
    if provider not in EFFORT_OPTION or model not in allowed:
        raise ValueError(
            f"Modell {provider}/{model} ist für Ciel nicht freigegeben; erlaubt: "
            + ", ".join(
                f"{p}/{m}"
                for p, models in sorted((config.get("selectableModels") or {}).items())
                for m in sorted(models)
            )
        )
    if effort not in allowed[model]:
        raise ValueError(
            f"Effort {effort} ist für {model} nicht freigegeben; erlaubt: "
            + ", ".join(allowed[model])
        )
    return selection(provider, model, effort)


def offered(catalog, chosen):
    """Reason the live T3 catalog cannot run `chosen`, or None."""
    provider = next(
        (
            p
            for p in catalog.get("providers", [])
            if p.get("providerInstanceId") == chosen["instanceId"]
        ),
        None,
    )
    if provider is None:
        return "T3 kennt den Provider nicht"
    if provider.get("constraints"):
        return "T3 meldet den Provider als nicht nutzbar: " + "; ".join(
            map(str, provider["constraints"])
        )
    models = provider.get("models") or []
    if not models:
        # Codex lists no catalog here; the stored configuration is still read back.
        return None
    model = next((m for m in models if m.get("id") == chosen["model"]), None)
    if model is None:
        return "T3 bietet dieses Modell nicht an"
    option = EFFORT_OPTION[chosen["instanceId"]]
    values = next(
        (o.get("values") for o in model.get("options", []) if o.get("id") == option),
        None,
    )
    if values is not None and effort_of(chosen) not in values:
        return "T3 bietet diesen Effort für das Modell nicht an"
    return None
