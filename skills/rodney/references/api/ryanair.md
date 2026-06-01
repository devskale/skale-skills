# Ryanair Public API

Undocumented internal API used by the Ryanair website. Free, no auth required.

**Base URL:** `https://www.ryanair.com/api/`

**Status:** Reverse-engineered from the website. Could change anytime.

---

## Endpoints

### 1. One-Way Fares

Search cheapest one-way fares from an airport.

```
GET /api/farfnd/v4/oneWayFares
```

**Parameters (required):**

| Param | Example | Description |
|-------|---------|-------------|
| `departureAirportIataCode` | `VIE` | Departure airport IATA code |
| `outboundDepartureDateFrom` | `2026-07-01` | Search start date |
| `outboundDepartureDateTo` | `2026-07-31` | Search end date |
| `currency` | `EUR` | Currency code |

**Parameters (optional):**

| Param | Example | Description |
|-------|---------|-------------|
| `arrivalAirportIataCode` | `BCN` | Filter by destination. Omit for all routes. |
| `language` | `de` | Language for airport names |
| `market` | `de-AT` | Market code |

**Example — all destinations from Vienna, July 2026:**

```bash
curl -s 'https://www.ryanair.com/api/farfnd/v4/oneWayFares?departureAirportIataCode=VIE&currency=EUR&outboundDepartureDateFrom=2026-07-01&outboundDepartureDateTo=2026-07-31' | python3 -c "
import sys,json
data=json.load(sys.stdin)
fares=sorted(data.get('fares',[]), key=lambda f: f['outbound']['price']['value'])
for f in fares[:10]:
    out=f['outbound']
    p=out['price']
    arr=out['arrivalAirport']
    print(f\"  {p['value']:>6} {p['currencyCode']}  {out['departureDate'][:10]}  {out['departureAirport']['iataCode']} → {arr['iataCode']}  ({arr['name']})\")
"
```

**Example — specific route VIE→BCN:**

```bash
curl -s 'https://www.ryanair.com/api/farfnd/v4/oneWayFares?departureAirportIataCode=VIE&arrivalAirportIataCode=BCN&currency=EUR&outboundDepartureDateFrom=2026-07-01&outboundDepartureDateTo=2026-07-07'
```

**Response structure:**

```json
{
  "fares": [
    {
      "outbound": {
        "departureAirport": {
          "countryName": "Österreich",
          "iataCode": "VIE",
          "name": "Wien",
          "seoName": "wien",
          "city": { "code": "VIENNA", "countryCode": "at", "name": "Wien" }
        },
        "arrivalAirport": {
          "countryName": "Spanien",
          "iataCode": "BCN",
          "name": "Barcelona El Prat",
          "seoName": "barcelona-el-prat",
          "city": { "code": "BARCELONA", "countryCode": "es", "name": "Barcelona", "macCode": "BAR" }
        },
        "departureDate": "2026-07-07T05:45:00",
        "arrivalDate": "2026-07-07T08:10:00",
        "price": {
          "value": 76.10,
          "valueMainUnit": "76",
          "valueFractionalUnit": "10",
          "currencyCode": "EUR",
          "currencySymbol": "€"
        },
        "flightKey": "FR~  13~ ~~VIE~07/07/2026 05:45~BCN~07/07/2026 08:10~~",
        "flightNumber": "FR13",
        "previousPrice": null,
        "priceUpdated": 1780317030000
      },
      "summary": {
        "price": { "value": 76.10, "currencyCode": "EUR", "currencySymbol": "€" },
        "previousPrice": null,
        "newRoute": false
      }
    }
  ],
  "nextPage": null,
  "size": 1
}
```

---

### 2. Round-Trip Fares

Search cheapest round-trip fares.

```
GET /api/farfnd/v4/roundTripFares
```

**Parameters (required):**

| Param | Example | Description |
|-------|---------|-------------|
| `departureAirportIataCode` | `VIE` | Departure airport |
| `arrivalAirportIataCode` | `BCN` | Destination airport (required for round-trip) |
| `outboundDepartureDateFrom` | `2026-07-01` | Outbound search start |
| `outboundDepartureDateTo` | `2026-07-07` | Outbound search end |
| `inboundDepartureDateFrom` | `2026-07-07` | Return search start |
| `inboundDepartureDateTo` | `2026-07-14` | Return search end |
| `currency` | `EUR` | Currency code |

**Parameters (optional):**

| Param | Example | Description |
|-------|---------|-------------|
| `language` | `de` | Language |
| `market` | `de-AT` | Market |

**Example:**

```bash
curl -s 'https://www.ryanair.com/api/farfnd/v4/roundTripFares?departureAirportIataCode=VIE&arrivalAirportIataCode=BCN&currency=EUR&outboundDepartureDateFrom=2026-07-01&outboundDepartureDateTo=2026-07-07&inboundDepartureDateFrom=2026-07-07&inboundDepartureDateTo=2026-07-14'
```

**Response:** Same as one-way but each fare has `outbound`, `inbound`, and `summary` with `tripDurationDays`:

```json
{
  "outbound": { ... },
  "inbound": {
    "departureAirport": { ... },
    "arrivalAirport": { ... },
    "departureDate": "2026-07-08T09:15:00",
    "arrivalDate": "2026-07-08T11:40:00",
    "price": { "value": 37.59, ... },
    "flightNumber": "FR...",
    ...
  },
  "summary": {
    "price": { "value": 113.69, ... },
    "tripDurationDays": 1,
    "newRoute": false
  }
}
```

---

## Common IATA Codes

| Code | Airport |
|------|---------|
| `VIE` | Wien Schwechat |
| `BCN` | Barcelona El Prat |
| `BGY` | Milano Bergamo |
| `BLQ` | Bologna |
| `BRU` | Brüssel |
| `CRL` | Brüssel Charleroi |
| `DBV` | Dubrovnik |
| `DUB` | Dublin |
| `EDI` | Edinburgh |
| `FCO` | Roma Fiumicino |
| `KRK` | Krakau |
| `LTN` | London Luton |
| `MXP` | Milano Malpensa |
| `NAP` | Neapel |
| `PMI` | Palma de Mallorca |
| `PRG` | Prag |
| `PUY` | Pula |
| `SOF` | Sofia |
| `STN` | London Stansted |
| `VCE` | Venedig Marco Polo |
| `ZAD` | Zadar |

Full list: search one-way from any airport without `arrivalAirportIataCode` and check the results.

---

## Tips

- **No auth needed** — just `curl`, no API key, no tokens
- **Date format** — `YYYY-MM-DD` (e.g. `2026-07-01`)
- **All routes from airport** — omit `arrivalAirportIataCode` to get all destinations
- **Date ranges** — use wide ranges (e.g. full month) for best prices
- **Currency** — supports `EUR`, `GBP`, `CHF`, `USD`, etc.
- **Rate limiting** — not observed but be reasonable (don't poll every second)
- **Booking** — not possible via this API (only fare search)

## Disclaimer

This is an undocumented internal API. Not affiliated with Ryanair. Could change or break anytime.
