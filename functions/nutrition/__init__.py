"""Meal photo estimates: one photo in, foods with grams and macros out.

The model only names the foods and estimates their grams. Every number about
energy and macros comes from this package: the Egyptian dish table
(egyptian_dishes.json, built by build_dishes.py from USDA ingredients) or the
USDA FoodData Central foods in usda_foods.json. The photo is re-encoded in
memory, sent once, and never written anywhere.
"""
