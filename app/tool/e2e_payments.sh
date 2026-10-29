#!/usr/bin/env bash
# InstaPay payments, end to end, on the local Firebase emulators only (demo project, never production).
# Boots the emulators, turns config/payments.enabled on INSIDE the emulator, runs
# functions/tools/e2e_payments.py (request, pay, receipt, confirm, fee bill, reminders, hold, release,
# refund, staff reject) and prints PASS/FAIL per step. Same environment as e2e_coaching.sh.
exec "$(dirname "$0")/e2e_coaching.sh" payments
