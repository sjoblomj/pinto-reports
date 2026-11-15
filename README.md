# pinto-reports
Scripts to turn [beancount files](https://beancount.github.io/) into PDF reports using [Typst](https://typst.app/).

## What is included?

- Sample Beancount file for a made up association.
- Scripts to turn the beancount data into PDF reports using Typst.
- Scripts to turn the beancount data into JSON format for importing elsewhere.

## Usage

Modify config.yaml and then run `./generate-reports`.

The look of the reports (currency, number formatting, fonts, organisation number, logo) is configured at the top of `report-scripts/report.typ`.

Notes in config.yaml are written in Typst markup. In addition, `$123.45$` is formatted as an amount, and `@1920@` is replaced by the name of that account.

### Verification numbers

The verification number of a transaction is taken from its `id` metadata: it is the first part of the id that is a number, when the id is split on underscores (`nordea_16_2025-01-31_1038` is verification 16). Transactions without an id get number 0 (e.g. the opening balance and the opening of the year), unless they come after the last transaction with an id (e.g. the transaction closing the year), in which case they continue the numbering.

### Closing the year

The year is closed in the beancount file, by booking the result between accounts 2069 and 8999 (see the end of `example.beancount`). Before any reports are made, it is checked that the amount booked on 8999 is the same as the result in the result report, and that the balance report balances. If not, no reports are generated. If nothing is booked on 8999 yet, there is only a warning, so that reports can be made during the year.

## Limitations

The scripts are made with the assumption that [BAS](https://en.wikipedia.org/wiki/BAS_(accounting)) will be used. It should be fairly trivial to change this assumption to work with any account naming strategies though.

## Required software

- beancount
- jq
- yq
- typst
- bash

## Acknowledgements
The layout of the Typst template (`report-scripts/report.typ`) is based on the [Minimal Invoice Template](https://www.latextemplates.com/template/minimal-invoice) from latextemplates.com
