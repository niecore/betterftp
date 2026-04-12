# betterftp.cc

**FTP.TEST — Power Lab.** A cross-platform Flutter app for performing FTP ramp tests with FTMS-compatible indoor cycling trainers. Your power doesn't need a subscription.

## Contents

- `betterftp/` — Flutter app (iOS + Android)
- `website/` — Static landing page, deployed to Cloudflare Pages at [betterftp.cc](https://betterftp.cc)
- `design/` — Design system, color schema, click dummy prototype

## Stack

Flutter · Riverpod · go_router · Hive · fl_chart · flutter_blue_plus · FTMS

## Deployment

The website auto-deploys to Cloudflare Pages on push to `main` via `.github/workflows/deploy-website.yml`. Required repo secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
