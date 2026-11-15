#!/bin/bash

# Prints a Typst document, which renders the given JSON file using the
# given table function from report.typ. The document is expected to be
# placed in the same directory as report.typ and the JSON file.
function print_typst_report() {
  local report_type="$1"
  local table_function="$2"
  local json_file="$3"

  # JSON strings are valid Typst strings
  jq -rn --arg type "$report_type" --arg func "$table_function" --arg data "$(basename "$json_file")" '
    "#import \"report.typ\": *",
    "#show: report.with(report-type: " + ($type | tojson) + ")",
    "",
    "#" + $func + "(json(" + ($data | tojson) + "))"
  '
}
