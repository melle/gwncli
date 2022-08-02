# gwncli - a command line tool for Grandstream WiFi access points

It's work in progress. I want to throttle the bandwith of specific wifi devices using my home automation
system. Therefore I need a cli tool to change bandwith rules programmatically. Grandstream supports
schedules, but I need to (un)throttle things on demand.  

Why would anyone do that? Well, think of an the Apple TV. It still works, but cannot stream movies at
96kb/s. Also iPads, smartphones ect. Useable, but YouTube, TikTok ect. become unusable at low bandwiths.
Did you say 'bad parenting'? Well, I call it a challenge for my kids to lern some things about networking 😬

## Goals

 * [✅] perform login and acquire session token
 * [✅] command line structure and help
 * [🔨] list current bandwith rules
 * [ ] add / update bandwith rules
 * [ ] delete bandwith rules
 
