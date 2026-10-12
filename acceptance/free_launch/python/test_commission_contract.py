"""Future production arithmetic, independent of any gateway or real payment.

All rates below are synthetic test data, not the owner's commercial terms.
"""
import importlib
import pytest

@pytest.fixture
def breakdown():
    try:
        return importlib.import_module('coaching.commerce').commission_breakdown
    except (ModuleNotFoundError, AttributeError):
        pytest.fail('C0 not implemented: functions/coaching/commerce.py must export commission_breakdown', pytrace=False)

@pytest.mark.parametrize('gross,refund,bps,base,platform,coach', [
    (10000,0,1500,10000,1500,8500),
    (10000,2500,1500,7500,1125,6375),
    (10000,10000,1500,0,0,0),
    (1,0,5000,1,1,0),  # integer half-up, not Python bankers' rounding
    (3,1,5000,2,1,1),
    (12345,0,0,12345,0,12345),
    (12345,0,10000,12345,12345,0),
    (9007199254740993,0,5000,9007199254740993,4503599627370497,4503599627370496),
])
def test_exact_minor_units_and_refund_recomputation(breakdown,gross,refund,bps,base,platform,coach):
    result = breakdown(gross_minor=gross, refunded_minor=refund, commission_bps=bps)
    assert result == {'base_minor': base, 'platform_minor': platform, 'coach_minor': coach}
    assert all(type(value) is int for value in result.values())
    assert result['platform_minor'] + result['coach_minor'] == result['base_minor']

@pytest.mark.parametrize('gross,refund,bps', [(-1,0,1500),(10,-1,1500),(10,11,1500),
    (10,0,-1),(10,0,10001),(1.5,0,1500),(10,0,True),(True,0,1500),(10,'0',1500)])
def test_reject_invalid_accounting_inputs(breakdown,gross,refund,bps):
    with pytest.raises(ValueError):
        breakdown(gross_minor=gross, refunded_minor=refund, commission_bps=bps)

def test_cumulative_refunds_recompute_before_rounding(breakdown):
    amounts = [breakdown(gross_minor=10, refunded_minor=refund, commission_bps=5000)['platform_minor']
               for refund in [0, 1, 2]]
    assert amounts == [5, 5, 4]
    assert [amounts[0] - amounts[1], amounts[1] - amounts[2]] == [0, 1]
