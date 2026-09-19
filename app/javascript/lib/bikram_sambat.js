// BS↔AD conversion — CLAUDE.md invariant #8: a lookup table, never a
// formula. Mirrors app/lib/bikram_sambat.rb exactly (same data, same
// fiscal-year rule) so an offline device computes the identical BS
// fiscal year the server would, without a network round-trip. Data
// source and verification notes: config/data/bikram_sambat.yml — keep
// YEARS in sync with that file when it's extended.
const SHRAWAN_MONTH = 4 // 1-indexed BS month: Baisakh=1, Jestha=2, Ashad=3, Shrawan=4

const YEARS = {
  2075: { baisakh1: "2018-04-14", monthDays: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30] },
  2076: { baisakh1: "2019-04-14", monthDays: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30] },
  2077: { baisakh1: "2020-04-13", monthDays: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31] },
  2078: { baisakh1: "2021-04-14", monthDays: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30] },
  2079: { baisakh1: "2022-04-14", monthDays: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30] },
  2080: { baisakh1: "2023-04-14", monthDays: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30] },
  2081: { baisakh1: "2024-04-13", monthDays: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31] },
  2082: { baisakh1: "2025-04-14", monthDays: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30] },
  2083: { baisakh1: "2026-04-14", monthDays: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30] },
  2084: { baisakh1: "2027-04-14", monthDays: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30] },
  2085: { baisakh1: "2028-04-13", monthDays: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30] },
  2086: { baisakh1: "2029-04-14", monthDays: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30] },
  2087: { baisakh1: "2030-04-14", monthDays: [31, 31, 32, 31, 31, 31, 30, 29, 30, 30, 30, 30] },
  2088: { baisakh1: "2031-04-15", monthDays: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30] },
  2089: { baisakh1: "2032-04-14", monthDays: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30] },
  2090: { baisakh1: "2033-04-14", monthDays: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30] }
}

export class UnknownYear extends Error {}

function daysBetween(a, b) {
  return Math.round((b - a) / 86400000)
}

function atMidnight(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

function yearContaining(date) {
  const years = Object.keys(YEARS).map(Number).sort((a, b) => a - b)
  let candidate = null
  for (const year of years) {
    if (atMidnight(new Date(YEARS[year].baisakh1)) <= date) candidate = year
    else break
  }
  if (candidate === null) throw new UnknownYear(`${date.toISOString()} is before the earliest supported BS year`)

  const entry = YEARS[candidate]
  const yearEnd = new Date(atMidnight(new Date(entry.baisakh1)).getTime() + entry.monthDays.reduce((a, b) => a + b, 0) * 86400000)
  if (date >= yearEnd && candidate === years[years.length - 1]) {
    throw new UnknownYear(`${date.toISOString()} is beyond the last supported BS year — extend bikram_sambat.js`)
  }
  return candidate
}

// Converts a Gregorian Date to its BS calendar equivalent: { year, month, day }.
export function fromGregorian(date) {
  const d = atMidnight(date)
  const year = yearContaining(d)
  const entry = YEARS[year]
  let remaining = daysBetween(atMidnight(new Date(entry.baisakh1)), d)

  let month = 0
  for (let i = 0; i < entry.monthDays.length; i++) {
    if (remaining < entry.monthDays[i]) { month = i + 1; break }
    remaining -= entry.monthDays[i]
  }

  return { year, month, day: remaining + 1 }
}

// Converts a BS date back to a Gregorian Date.
export function toGregorian(year, month, day) {
  const entry = YEARS[year]
  if (!entry) throw new UnknownYear(`no BS calendar data for year ${year}`)
  if (month < 1 || month > 12) throw new RangeError(`month must be 1..12, got ${month}`)

  const daysBeforeMonth = entry.monthDays.slice(0, month - 1).reduce((a, b) => a + b, 0)
  const base = atMidnight(new Date(entry.baisakh1))
  return new Date(base.getTime() + (daysBeforeMonth + day - 1) * 86400000)
}

// "2082/83" — the fiscal year the given Gregorian date falls in. Shrawan 1
// of BS year Y through Ashad-end of BS year Y+1.
export function fiscalYearFor(date) {
  const bs = fromGregorian(date)
  const fiscalStartYear = bs.month >= SHRAWAN_MONTH ? bs.year : bs.year - 1
  return `${fiscalStartYear}/${String((fiscalStartYear + 1) % 100).padStart(2, "0")}`
}
