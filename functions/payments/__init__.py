"""InstaPay payments between a client and her coach (docs/plan/INSTAPAY-PAYMENTS-SPEC.md).

Own Hub never holds, receives or moves the money. This package records the
payment, decides who may do what next, and keeps a trail. Every state change is
made here by a callable in main.py; the phones only read (firebase/firestore.rules).

All amounts in this package are integer piasters (500.37 EGP is 50037).
"""
