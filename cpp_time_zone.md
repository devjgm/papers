# C++ Standard Proposal &mdash; A Time Zone Library

Authors: Greg Miller (jgm@google.com), Bradley White (bww@google.com)

## Motivation

Programming with time on a human scale is notoriously difficult and error prone:
time zones are complicated, daylight-saving time (DST) is complicated, calendars
are complicated, and leap seconds are complicated. These complexities quickly
surface in code because programmers do not have a simple conceptual model with
which to reason about the time-programming challenges they are facing. This lack
of a simple conceptual model begets the lack of a simple time-programming
library, leaving only complicated libraries that programmers struggle to
understand and use correctly.

A few years ago we set out to fix these problems within Google by doing the
following:

* Defining a simple conceptual model that will help programmers reason about
  arbitrarily complex situations involving time, time zones, DST, etc.
* Producing a simple library (or two) that implements the conceptual model.

This paper describes the Time Zone Library that has been widely used within
Google for a couple years. Our goal with this paper is to inform the C++
Standards Committee about the design and trade-offs we considered and the
results of our real-world usage.

NOTE: This paper depends on the related paper proposing a standard Civil Time
Library (XXX: jgm add a link here).

## Conceptual Model

The conceptual model for time-programming that we teach within Google consists
of three simple concepts that we will define here (Note: this model and these
definitions are not specific to C++).

*Absolute time* uniquely and universally represents a specific instant in time.
It has no notion of calendars, or dates, or times of day. Instead, it is a
measure of the passage of real time, typically as a simple count of ticks since
some epoch. Absolute times are independent of all time zones and do not suffer
from human-imposed complexities such as daylight-saving time (DST). Many C++
types exist to represent absolute times, classically `time_t` and more recently
`std::chrono::time_point`.

*Civil time* is the legally recognized representation of time for ordinary
affairs (cf. http://www.merriam-webster.com/dictionary/civil). It is a
human-scale representation of time that consists of the six fields &mdash;
year, month, day, hour, minute, and second (sometimes shortened to "YMDHMS")
&mdash; and it follows the rules of the [Proleptic Gregorian Calendar], with
24-hour days divided into hours and minutes. Like absolute times, civil times
are also independent of all time zones and their related complexities (e.g.,
DST). While `std::tm` contains the six YMDHMS civil-time fields (plus a few
more), it does not have behavior to enforce the rules of civil time as just
described.

*Time zones* are geo-political regions within which human-defined rules are
shared to convert between the previously described absolute time and civil time
domains. A time-zone's rules include things like the region's offset from the
[UTC] time standard, daylight-saving adjustments, and short abbreviation
strings. Time zones often have a history of disparate rules that apply only for
certain periods because the rules may change at the whim of a region's local
government. For this reason, time zone rules are often compiled into data
snapshots that are used at runtime to perform conversions between absolute and
civil times. A proposal for a standard time zone library is presented in
another paper (XXX: jgm add a link here).

The C++ standard library already has `<chrono>`, which is a good implementation
of *absolute time* (as well as the related duration concept). Another paper is
proposing a standard Civil Time Library that complements `<chrono>` (XXX: jgm
insert link to civil time paper). This paper is proposing a standard *time
zone* library that follows the complex rules defined by time zones and provides
a mapping between the absolute and civil time domains.

## Overview

Time zones are canonically identified by a string of the form
[Continent]/[City], such as "America/New_York", "Europe/London", and
"Australia/Sydney". The data encapsulated by a time zone describes the offset
from the [UTC] time standard, a short abbreviation string (e.g., "EST", "PDT"),
and information about daylight-saving time (DST). These rules are defined by
local governments and they may change over time. A time zone, therefore,
represents the complete history of time zone rules and when each rule applies
for a given region.

Ultimately, a time zone represents the rules necessary to convert any *absolute
time* to a *civil time* and vice versa.

In this model, [UTC] itself is naturally represented as a time zone having a
constant zero offset, no DST, and an abbreviation string of "UTC". Treating UTC
like any other time zone enables programmers to write correct,
time-zone-agnostic code without needing to special-case UTC.

The core of the Time Zone Library presented here is a single class named
`time_zone`, which has two member functions to convert between absolute time and
civil time. Absolute times are represented by `std::chrono::time_point` (on the
system_clock), and civil times are represented using `civil_second` as described
in the proposed Civil Time Library (XXX: jgm add link to that paper). The Time
Zone Library also defines a convenience syntax for doing conversions through a
time zone. There are also functions to format and parse absolute times as
strings.

## API

The interface for the core `time_zone` class is as follows.

```cpp
#include <chrono>
#include "civil.h"  // XXX: jgm reference the other paper

// Convenience aliases.
template <typename D>
using time_point = std::chrono::time_point<std::chrono::system_clock, D>;
using sys_seconds = std::chrono::duration<std::chrono::system_clock::rep,
                                          std::chrono::seconds::period>;

class time_zone {
 public:
  // A value type.
  time_zone() = default;  // Equivalent to UTC
  time_zone(const time_zone&) = default;
  time_zone& operator=(const time_zone&) = default;

  struct time_conversion {
    civil_second cs;
    int offset;        // seconds east of UTC
    bool is_dst;       // is offset non-standard?
    std::string abbr;  // time-zone abbreviation (e.g., "PST")
  };
  template <typename D>
  time_conversion convert(const time_point<D>& tp) const;

  struct civil_conversion {
    enum class kind {
      UNIQUE,    // the civil time was singular (pre == trans == post)
      SKIPPED,   // the civil time did not exist
      REPEATED,  // the civil time was ambiguous
    } kind;
    time_point<sys_seconds> pre;   // Uses the pre-transition offset
    time_point<sys_seconds> trans;
    time_point<sys_seconds> post;  // Uses the post-transition offset
  };
  civil_conversion convert(const civil_second& cs) const;

 private:
  ...
};

// Loads the named time zone. Returns false on error.
bool load_time_zone(const std::string& name, time_zone* tz);

// Returns a time_zone representing UTC.
time_zone utc_time_zone();

// Returns a time zone representing the local time zone.
time_zone local_time_zone();
```

Converting from an absolute time to a civil time (e.g.,
`std::chrono::time_point` to `civil_second`) is an exact calculation with no
possible time zone ambiguities. However, conversion from civil time to absolute
time may not be exact. Conversions around UTC offset transitions may be given
ambiguous civil times (e.g., the 1:00 am hour is repeated during the Autumn DST
transition in the United States), and some civil times may not exist in a
particular time zone (e.g., the 2:00 am hour is skipped during the Spring DST
transition in the United States). The `time_zone::civil_conversion` struct gives
callers all relevant information about the conversion operation.

However, the full information provided by the `time_zone::time_conversion` and
`time_zone::civil_conversion` structs is frequently not needed by callers. To
simplify the common case of converting between `std::chrono::time_point` and
`civil_second`, the Time Zone Library provides two overloads of `operator|` to
allow "piping" either type to a `time_zone` in order to convert to the other
type.

The implementation of these convenience functions must select an appropriate
"default" time point to return in cases of ambiguous/skipped civil time
conversions. The value chosen is such that the relative ordering of civil times
is preserved when they are converted to absolute times.

Note: This convenience syntax exists to shorten common code samples, and to
select a generally good default for programmers when necessary. It is not an
essential part of the Time Zone Library proposed in this paper.

```cpp
template <typename D>
inline CivilSecond operator|(const time_point<D>& tp, const time_zone& tz) {
  return tz.convert(tp).cs;
}

inline time_point<sys_seconds> operator|(const civil_second& cs, const time_zone& tz) {
  const auto conv = tz.convert(cs);
  if (conv.kind == time_zone::civil_conversion::kind::SKIPPED)
    return conv.trans;
  return conv.pre;
}
```

Finally, functions are provided for formatting and parsing absolute times with
respect to a given time zone. These functions use `strftime()`-like format
specifiers, with the following extensions:

Specifier | Description
----------|------------
`%Ez`     | RFC3339-compatible numeric time zone (+hh:mm or -hh:mm)
`%E#S`    | Seconds with # digits of fractional precision
`%E*S`    | Seconds with full fractional precision (a literal '*')
`%E4Y`    | Four-character years (-999 ... -001, 0000, 0001 ... 9999)

```cpp
template <typename D>
std::string format(const std::string& format, const time_point<D>& tp,
                   const time_zone& tz);
// Uses a format string of "%Y-%m-%dT%H:%M:%E*S%Ez"
template <typename D>
std::string format(const time_point<D>& tp, const time_zone& tz);

template <typename D>
bool parse(const std::string& format, const std::string& input,
           const time_zone& tz, time_point<D>* tpp);
```

## Examples

### Creating a `time_zone`

Time zones are created by passing the time zone's name to the `load_time_zone()`
function along with a pointer to a `time_zone`. Since the named zone may not
exist or may be specified incorrectly by the caller, the function may return
`false` on error.

Additionally, callers may get time zones representing UTC or the process's local
time zone through convenience functions that cannot fail and return the time
zone by value.

```cpp
time_zone nyc;
if (load_time_zone("America/New_York", &nyc)) {
  ...
}

const time_zone utc = utc_time_zone();
```

### Creating an `time_point` from a `civil_second`

```cpp
const civil_second cs(2015, 2, 3, 4, 5, 6);  // 2015-02-03 04:05:06
const time_zone utc = utc_time_zone();

const auto tp1 = cs | nyc;  // Civil -> Absolute

time_zone nyc;
if (load_time_zone("America/New_York", &nyc)) {
  const auto tp2 = cs | nyc;  // Civil -> Absolute
  // Note: tp1 != tp2
}
```

### Creating a `civil_second` from a `time_point`

```cpp
const time_t tt = 1234567890;
const auto tp = std::chrono::system_clock::from_time_t(tt);

const time_zone utc = utc_time_zone();
civil_second cs1 = tp | utc;  // Absolute -> Civil

time_zone nyc;
if (load_time_zone("America/New_York", &nyc)) {
  civil_second cs2 = tp | nyc;  // Absolute -> Civil
  // Note: cs1 != cs2
}
```

### Flight example

This example is borrowed from Howard Hinnant at
http://howardhinnant.github.io/tz.html.

> There's nothing like a real-world example to help demonstrate things. Imagine
> a plane flying from New York, New York, USA to Tehran, Iran. To make it more
> realistic, lets say this flight occurred before the hostage crisis, right at the
> end of 1978. Flight time for a non-stop one way trip is 14 hours and 44
> minutes.
>
> Given that the departure is one minute past noon on Dec. 30, 1978, local time,
> what is the local arrival time?

```cpp
time_zone nyc;
if (!load_time_zone("America/New_York", &nyc)) {
  // error.
}
const auto departure = civil_second(1978, 12, 30, 12, 1, 0) | nyc;
const auto flight_length = std::chrono::hours(14) + std::chrono::minutes(44);
const auto arrival = departure + flight_length;
time_zone teh;
if (!load_time_zone("Asia/Tehran", &teh)) {
  // error.
}
std::cout << "departure NYC time: " << format(departure, nyc);
std::cout << "arrival Tehran time: " << format(arrival, teh);
```

[Proleptic Gregorian Calendar]: https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar
[UTC]: https://en.wikipedia.org/wiki/Coordinated_Universal_Time
