#!/bin/bash

# ============================================================
# Task 2: Replace "give" with "learning" 
#         From line 5 till end, only in lines with "welcome"
# ============================================================

# ---------- Configuration ----------
INPUT_FILE="${1:-input.txt}"       # Accept filename as argument, default: input.txt
OUTPUT_FILE="output.txt"
START_LINE=5
FIND_WORD="give"
REPLACE_WORD="learning"
MATCH_WORD="welcome"
# -----------------------------------

echo "============================================"
echo "   Word Replacement Script"
echo "============================================"
echo "Input File   : $INPUT_FILE"
echo "Output File  : $OUTPUT_FILE"
echo "Replacing    : \"$FIND_WORD\" → \"$REPLACE_WORD\""
echo "From Line    : $START_LINE till end"
echo "Only in lines: containing \"$MATCH_WORD\""
echo ""

# Validate input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ ERROR: File '$INPUT_FILE' not found!"
    exit 1
fi

TOTAL_LINES=$(wc -l < "$INPUT_FILE")
echo "Total lines in file: $TOTAL_LINES"
echo ""

# -------------------------------------------------------
# Core Logic using sed:
#   5,$          → from line 5 to end of file
#   /welcome/    → only process lines containing "welcome"
#   s/give/learning/g → replace ALL occurrences of "give"
# -------------------------------------------------------
sed "5,\${ /\b${MATCH_WORD}\b/Is/\b${FIND_WORD}\b/${REPLACE_WORD}/gI; }" "$INPUT_FILE" > "$OUTPUT_FILE"

echo "--------------------------------------------"
echo " BEFORE (original file):"
echo "--------------------------------------------"
cat -n "$INPUT_FILE"

echo ""
echo "--------------------------------------------"
echo " AFTER (processed output):"
echo "--------------------------------------------"
cat -n "$OUTPUT_FILE"

echo ""
echo "--------------------------------------------"
echo " CHANGES SUMMARY (lines modified):"
echo "--------------------------------------------"

CHANGED=0
while IFS= read -r line_info; do
    LINE_NUM=$(echo "$line_info" | cut -d: -f1)
    ORIG=$(sed -n "${LINE_NUM}p" "$INPUT_FILE")
    NEW=$(sed -n "${LINE_NUM}p" "$OUTPUT_FILE")
    if [ "$ORIG" != "$NEW" ]; then
        echo "  Line $LINE_NUM changed:"
        echo "    BEFORE: $ORIG"
        echo "    AFTER : $NEW"
        CHANGED=$((CHANGED + 1))
    fi
done < <(grep -in "$MATCH_WORD" "$INPUT_FILE" | awk -F: -v start="$START_LINE" '$1 >= start')

if [ "$CHANGED" -eq 0 ]; then
    echo "  No lines were modified."
else
    echo ""
    echo "✅ SUCCESS: $CHANGED line(s) updated in '$OUTPUT_FILE'"
fi

echo ""
echo "============================================"
echo "   Replacement Complete"
echo "============================================"
