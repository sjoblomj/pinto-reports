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
