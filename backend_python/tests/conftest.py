import pandas as pd


_original_date_range = pd.date_range


def _date_range_compat(*args, **kwargs):
    if kwargs.get("freq") == "M":
        kwargs["freq"] = "ME"
    return _original_date_range(*args, **kwargs)


pd.date_range = _date_range_compat
