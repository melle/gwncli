# gwncli - control Grandstream WiFi access points

## Abstract

It's work in progress. I want to throttle the bandwidth of specific wifi devices using my home automation
system. Therefore I need a cli tool to change bandwidth rules programmatically. Grandstream supports
schedules, but I need to (un)throttle things on demand.  

Why would anyone do that? Well, think of an the Apple TV. It still works, but cannot stream movies at
96kb/s. Also iPads, smartphones ect. It works somehow, but YouTube, TikTok ect. become unusable at low bandwidths.
Did you say 'bad parenting'? Well, I call it a challenge for my kids to lern some things about networking 😬

## Building

Swift 5.7 is required to build (at the time of writing this means Xcode 14 or newer).

```
swift build
```

## Usage

List all rules:

```
./.build/arm64-apple-macosx/debug/gwncli list --url "https://gwn_c074ad7b2950.local" --username admin --password dcGcYSXs
```

Delete rule4:

```
./.build/arm64-apple-macosx/debug/gwncli delete --url "https://gwn_c074ad7b2950.local" --username admin --password dcGcYSXs --rule-name rule4

```

Add or modify a rule:

(TBD)

## Goals

 * [✅] perform login and acquire session token
 * [✅] command line structure and help
 * [✅] list current bandwidth rules
 * [🔨] delete bandwidth rules
 * [ ] add / update bandwidth rules
 
