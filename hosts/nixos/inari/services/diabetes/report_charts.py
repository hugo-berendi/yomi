"""Small, email-ready charts for the weekly diabetes report."""

import io
import math
from datetime import date, timedelta

from matplotlib.figure import Figure
from matplotlib.colors import LinearSegmentedColormap

PAPER = "#f7f5ee"
INK = "#183b3a"
MUTED = "#60716f"
RANGE = "#287d75"
HIGH = "#bd7a26"
LOW = "#c45353"
GAP = "#dedfd9"


def _save(figure):
    output = io.BytesIO()
    figure.savefig(output, format="png", dpi=160, facecolor=PAPER)
    return output.getvalue()


def _figure(height=2.15):
    figure = Figure(figsize=(6, height), dpi=160, facecolor=PAPER, layout="constrained")
    return figure


def _axes_style(axis):
    axis.set_facecolor(PAPER)
    axis.tick_params(colors=MUTED, labelsize=9, length=0)
    for spine in axis.spines.values():
        spine.set_visible(False)


def _comparison(report):
    figure = _figure()
    axis = figure.subplots()
    _axes_style(axis)
    weeks = report.get("weeks", [])[:2]
    weeks = list(reversed(weeks))
    for row, week in enumerate(weeks):
        vals = [
            week.get("below_percent"),
            week.get("in_percent"),
            week.get("above_percent"),
        ]
        if not any(value is not None for value in vals):
            axis.text(
                50,
                row,
                "No observations",
                ha="center",
                va="center",
                color=MUTED,
                fontsize=11,
            )
            continue
        left = 0
        for value, color, label in zip(
            vals, (LOW, RANGE, HIGH), ("Below", "In range", "Above")
        ):
            amount = max(0, value or 0)
            axis.barh(
                row,
                amount,
                left=left,
                height=0.38,
                color=color,
                edgecolor=PAPER,
                linewidth=1,
            )
            left += amount
        axis.text(
            0,
            row - 0.29,
            "Below {0} · In {1} · Above {2}".format(
                *("—" if value is None else f"{value:.1f}%" for value in vals)
            ),
            ha="left",
            va="top",
            color=INK,
            fontsize=10,
        )
    axis.set_xlim(0, 100)
    axis.set_ylim(-0.7, 1.5)
    axis.set_xticks([0, 25, 50, 75, 100], ["0", "25", "50", "75", "100%"])
    axis.set_yticks(range(len(weeks)), ["Prior week", "This week"][: len(weeks)])
    axis.set_title(
        "Observed time by glucose range",
        loc="left",
        color=INK,
        fontsize=11,
        fontweight="bold",
    )
    axis.grid(axis="x", color=GAP, linewidth=0.7)
    axis.set_axisbelow(True)
    return _save(figure)


def _daily(report):
    figure = _figure()
    axis = figure.subplots()
    _axes_style(axis)
    week = (report.get("weeks") or [{}])[0]
    by_date = {item.get("date"): item for item in week.get("daily", [])}
    try:
        monday = date.fromisoformat(week.get("label", ""))
    except (ValueError, TypeError):
        monday = date.today() - timedelta(days=date.today().weekday())
    for i in range(7):
        day = monday + timedelta(days=i)
        item = by_date.get(day.isoformat())
        if item is None or item.get("in_percent") is None:
            axis.bar(i, 100, color=GAP, hatch="///", edgecolor=PAPER, width=0.68)
            axis.text(
                i, 50, "No\ndata", ha="center", va="center", color=MUTED, fontsize=8
            )
        else:
            value = max(0, min(100, float(item["in_percent"])))
            axis.bar(i, value, color=RANGE, width=0.68)
            axis.text(
                i,
                min(96, value + 4),
                f"{value:.0f}%",
                ha="center",
                va="bottom",
                color=INK,
                fontsize=8,
                fontweight="bold",
            )
    axis.set_ylim(0, 108)
    axis.set_yticks([0, 50, 100], ["0", "50", "100%"])
    axis.set_xticks(
        range(7), [(monday + timedelta(days=i)).strftime("%a") for i in range(7)]
    )
    axis.set_title(
        "Time in range by day", loc="left", color=INK, fontsize=11, fontweight="bold"
    )
    axis.grid(axis="y", color=GAP, linewidth=0.7)
    axis.set_axisbelow(True)
    return _save(figure)


def hour_values(hours, category):
    """Two-hour cells use observed minutes, never an unweighted hour average."""
    values = []
    for start in range(0, 24, 2):
        block = [item for item in hours if start <= item["hour"] < start + 2]
        observed = sum(item.get("observed_minutes", 0) or 0 for item in block)
        minutes = sum(item.get(f"{category}_minutes", 0) or 0 for item in block)
        values.append(minutes / observed * 100 if observed else math.nan)
    return values


def _hourly(report):
    figure = _figure()
    axes = figure.subplots(2, 1, sharex=True)
    week = (report.get("weeks") or [{}])[0]
    import numpy as np

    for axis, category, label, color in zip(
        axes, ("above", "below"), ("Above", "Below"), (HIGH, LOW), strict=True
    ):
        _axes_style(axis)
        values = hour_values(week.get("hourly", []), category)
        cmap = LinearSegmentedColormap.from_list(f"{category}_ramp", [PAPER, color])
        cmap.set_bad(GAP)
        image = axis.imshow(
            np.array([values]),
            aspect="auto",
            interpolation="nearest",
            cmap=cmap,
            vmin=0,
            vmax=100,
        )
        axis.set_yticks([0], [label])
        for col, value in enumerate(values):
            if math.isnan(value):
                axis.text(
                    col, 0, "—", ha="center", va="center", color=MUTED, fontsize=8
                )
            else:
                rgb = cmap(value / 100)[:3]
                linear = [
                    v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                    for v in rgb
                ]
                luminance = sum(
                    v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722), strict=True)
                )
                axis.text(
                    col,
                    0,
                    f"{value:.0f}",
                    ha="center",
                    va="center",
                    color="white" if luminance < 0.179 else "black",
                    fontsize=10,
                    fontweight="bold",
                )
        axis.set_ylim(-0.55, 0.55)
        cbar = figure.colorbar(image, ax=axis, ticks=[0, 100], pad=0.02)
        cbar.ax.set_yticklabels(["0", "100%"])
        cbar.ax.tick_params(labelsize=8, colors=MUTED, length=0)
    axes[0].set_title(
        f"Hourly patterns · {week.get('label', 'current week')}",
        loc="left",
        color=INK,
        fontsize=11,
        fontweight="bold",
    )
    axes[1].set_xticks(range(0, 12, 2), [f"{hour:02d}:00" for hour in range(0, 24, 4)])
    axes[1].set_xlabel(
        "Two-hour Berlin windows; gray = no observations", color=MUTED, fontsize=9
    )
    return _save(figure)


def charts(report):
    """Return the three PNG attachments keyed by stable report asset names."""
    return {
        "range-comparison": _comparison(report),
        "daily-range": _daily(report),
        "hourly-patterns": _hourly(report),
    }
