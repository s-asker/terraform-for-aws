"""Validation for the version 1 numeric report message contract."""
import math


def validate_numbers(value):
    if not isinstance(value, list) or not 1 <= len(value) <= 1000:
        raise ValueError("numbers must be an array of 1 to 1000 numbers")
    if any(type(n) not in (int, float) or not math.isfinite(n) or abs(n) > 1e12 for n in value):
        raise ValueError("numbers must be finite numbers between -1e12 and 1e12")
    return value

