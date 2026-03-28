---
name: dutch-energy-comparison
description: >
  Compare Dutch energy providers and find the cheapest option. Use when the user asks
  about energy providers in the Netherlands, switching energy contracts, comparing gas/electricity
  rates, or wants their annual energy comparison updated.
argument-hint: [electricity-kwh-per-month] [gas-m3-per-month]
disable-model-invocation: true
---

# Dutch Energy Provider Comparison

Compare all Dutch energy providers for a specific consumption profile, accounting for
per-unit rates, sign-up channel bonuses, and contract types. Produce a report the user
can act on immediately.

## User profile

- Location: Netherlands, corner house (hoekwoning), no solar panels
- Default consumption: 176 kWh/month electricity, 100 m3/month gas
- Override with arguments: `$0` = electricity kWh/month, `$1` = gas m3/month
- Strategy: switch provider every year to maximize welkomstbonus/loyaliteitsbonus

## Previous report

The last report (March 2026) is at `/home/claude/vibes/energy-report/`.
Read it first to understand the baseline and see what changed since last time.

## Research procedure

Follow these steps in order. Do not skip any — the pitfalls section explains why.

### Step 1: Gather current fixed 1-year rates

For each provider, collect the **all-in** €/kWh and €/m3 (energy tax + ODE + 21% VAT included).
Use these sources (fetch with WebFetch or WebSearch):

| Source | What it has | URL pattern |
|--------|------------|-------------|
| energievergelijk.nl | All-in rates, cheapest ranking | energievergelijk.nl/energieprijzen |
| easyswitch.nl | Per-provider electricity rates | easyswitch.nl/energieprijzen/stroomprijs/ |
| easyswitch.nl | Per-provider gas rates | easyswitch.nl/energieprijzen/gasprijs/ |
| gaslicht.com | Rate comparison | gaslicht.com |

Cross-reference at least 2 sources. If rates differ by more than €0.01/kWh or €0.05/m3,
investigate which is more recent.

### Step 2: Gather fixed 3-year rates

Source: `easyswitch.nl/energiecontract/vast/3-jaar/` and `energievergelijk.nl`.
Not all providers offer 3-year contracts.

### Step 3: Gather variable rates (for reference only)

Same sources. Variable rates change monthly, so note the date prominently.

### Step 4: Gather per-channel bonus amounts

This is the most critical and time-consuming step. The same provider can offer
€0 bonus (direct sign-up) vs €590 (via keuze.nl). You MUST check each channel.

**Channels to check** (in order of typical bonus size):

1. keuze.nl
2. energieaanbiedingen.nu
3. energie-aanbiedingen.com
4. easyswitch.nl
5. gaslicht.com
6. energiecashback.nl
7. energiehunter.nl
8. Direct (provider website)

**How to get bonus amounts:**
- Visit each comparison site and look for the welkomstbonus/cashback column
- Enter the user's postal code and consumption if the site requires it
- Note whether the bonus is cash, gift card, or credit — only count cash/credit
- Note if the bonus is "up to" (tot) — these are consumption-dependent (staffels)

**Providers to check** (major Dutch providers):
Greenchoice, Vattenfall, Budget Energie, Innova Energie, Eneco, Vandebron,
Essent, Energiedirect, Engie, Oxxio, Delta Energie, Clean Energy,
United Consumers, Mega, Coolblue Energie

### Step 5: Calculate gross annual cost

For each provider:
```
Gross Annual = (annual_kWh × €/kWh) + (annual_m3 × €/m3) + €72 standing charge
```

Standing charge (vaste leveringskosten) is ~€72/year (~€6/month). Check actual
amounts per provider if available, but the difference is small (€60-85 range).

Network costs (netbeheerkosten) are ~€700/year and identical across providers.
Exclude from comparison but mention in the bill breakdown.

### Step 6: Calculate net year-1 cost

```
Net Year 1 = Gross Annual - Best Bonus (from best channel)
```

### Step 7: Build the report

Output to `/home/claude/vibes/energy-report/energy-comparison-<month>-<year>.md`.
Also create/update `bonus-per-channel.csv` with the full matrix.

Report structure:
1. Consumption summary
2. How bonuses work (copy the explanation — users need this context)
3. Fixed 1-year contracts: ranked by net year-1, with per-channel bonus table
4. Fixed 3-year contracts: ranked by gross annual
5. Annual switching strategy: 3-year rotation plan using different providers
6. Variable contracts: for reference only
7. Overall recommendation
8. Bill breakdown: monthly payment vs year-end bonus settlement
9. Important notes and caveats
10. Sources with dates

## Pitfalls — lessons learned the hard way

### 1. Comparison sites inflate bonuses

The bonus shown on gaslicht.com or keuze.nl is NOT just the provider's loyaliteitsbonus.
It often includes:
- The comparison site's own referral commission
- "Actiekorting" that may be temporary
- Rounded-up "up to" amounts for the highest consumption tier

The ANWB called this "een sigaar uit eigen doos" (a cigar from your own box) — the
provider raises rates to fund the bonus. Still worth taking, but don't optimize
purely on bonus size.

### 2. Bonuses vary enormously by sign-up channel

In March 2026, Budget Energie offered:
- €0 via their own website
- €320 via gaslicht.com
- €590 via keuze.nl

That's a €590 difference for the exact same contract. ALWAYS check all channels.

### 3. Bonuses are consumption-dependent (staffels)

"Up to €590" is for high-consumption households. At 2,112 kWh + 1,200 m3, expect
the actual bonus to be 10-15% less than the headline "up to" figure. The exact
amount is only confirmed when you enter your details on the sign-up page.

### 4. No renewal required for bonus

ACM regulations (since June 2023) ensure the loyaliteitsbonus is paid on the
jaarafrekening after completing the full contract term. You do NOT need to renew.
Cancel early = lose the bonus AND pay a termination fee (€50-100 for 1yr).

### 5. High bonuses hide high rates

A provider offering €590 bonus but charging €0.278/kWh + €1.525/m3 may be cheaper
net than one charging €0.266/kWh + €1.459/m3 with only €350 bonus — BUT the high-rate
provider is a worse deal if you forget to switch or if bonuses change next year.

Always present BOTH the gross ranking (rate-based) and net ranking (after bonus).

### 6. "New customer" restriction

You typically can't return to the same provider within 12 months and still qualify
for the welkomstbonus. Plan a 3-provider rotation cycle.

### 7. Variable rates are deceptive

Variable rates often look cheaper per-unit than fixed, but:
- No price protection against gas price spikes
- No bonus available
- The user's 1,200 m3/year gas consumption creates heavy exposure to volatility

### 8. Don't forget the monthly payment reality

The "net year 1" figure divides the bonus across 12 months. But your actual monthly
bill is based on the gross rate. The bonus comes back as a lump sum on the
jaarafrekening. Make this clear so the user budgets correctly.

### 9. Gift card bonuses

Some channels offer gift cards instead of cash. Only count cash/bank transfer bonuses
unless the user explicitly wants gift cards. Flag gift-card-only bonuses separately.

## CSV format for bonus-per-channel.csv

```
Provider,€/kWh (1yr),€/m3 (1yr),Gross Annual,Direct Site,easyswitch.nl,gaslicht.com,energieaanbiedingen.nu,keuze.nl,energie-aanbiedingen.com,energiehunter.nl,energiecashback.nl,Best Bonus,Best Channel,Net Year 1 (best bonus)
```

## Useful Dutch energy terminology

| Dutch | English | Notes |
|-------|---------|-------|
| Loyaliteitsbonus | Loyalty bonus | Paid at end of contract |
| Welkomstkorting | Welcome discount | Sometimes applied monthly |
| Cashback | Cashback | Via comparison site, not provider |
| Jaarafrekening | Annual statement | When bonus is settled |
| Vaste leveringskosten | Standing charge | ~€6/month |
| Netbeheerkosten | Network costs | ~€700/yr, same for all providers |
| Energiebelasting (EB) | Energy tax | Included in all-in rates |
| ODE | Sustainable energy surcharge | Included in all-in rates |
| Staffel | Tier/bracket | Consumption-based bonus tiers |
| Hoekwoning | Corner house | Higher gas usage expected |
| Opzegvergoeding | Early termination fee | €50-150 depending on contract |

## After completing the report

1. Compare with the previous report to highlight what changed (new providers,
   rate movements, channel bonus shifts)
2. If a provider from last year's rotation is no longer competitive, flag it
3. Remind the user to set a calendar reminder for month 11 of their contract
