# C++ Standard Proposal &mdash; A Civil Time Library

## Motivation

Programming with time on a human scale is notoriously difficult and error
prone: time zones are complicated, daylight-saving time (DST) is complicated,
calendars are complicated, and leap seconds are complicated. These complexities
quickly surface in code because programmers do not have a simple mental model
with which to reason about the time-programming challenges that they are facing.
This lack of a simple mental model begets the lack of a simple time-programming
library, leaving only complicated libraries that programmers struggle to
understand and use correctly.

A few years ago we set out to fix these problems within Google by:

* Defining a simple mental model that will help programmers reason about
  arbitrarily complex situations involving time, time zones, DST, etc.
* Producing a simple library (or two) that implements the mental model.

This paper describes the Civil Time Library that has been widely used within
Google for a couple years. Our goal with this paper is to inform the C++
Standards Committee about the design and trade-offs we considered and the
results of our real-world usage.

NOTE: This paper is not dependent on, but is closely related to, the paper about
time zones (XXX: jgm add a link here).

## Definitions

The mental model for time-programming that we teach within Google consists of
three simple concepts that we will define here (Note: this model and these
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
human-scale representation of time that consists of the six fields &mdash; year,
month, day, hour, minute, and second (sometimes shortened to "YMDHMS") &mdash;
and it follows the rules of the [Proleptic Gregorian Calendar], with 24-hour
days divided into hours and minutes. Like absolute times, civil times are also
independent of all time zones and their related complexities (e.g., DST). While
`std::tm` contains the six YMDHMS civil-time fields (plus a few more), it does
not have behavior that enforces the rules of civil times as just described.

*Time zones* are geo-political regions within which human-defined rules are
shared to convert between the previously described absolute time and civil time
domains. A time-zone's rules include things like the region's offset from the
UTC time standard, daylight-saving adjustments, and short abbreviation strings.
Time zones often have a history of disparate rules that apply only for certain
periods because the rules may change at the whim of a region's local government.
For this reason, time zone rules are often compiled into data snapshots that are
used at runtime to perform conversions between absolute and civil times. A
proposal for a standard time zone library is presented in another paper (XXX:
jgm add a link here).

## Overview

To build a Civil Time Library that is easy to understand and use, we made the
following simplifying assumptions:

* Civil times use the [Proleptic Gregorian Calendar] only. Other calendars do
  exist in the real world, but their rarity of use does not warrant complicating
  the common case. Additionally, international standards such as
  [UTC](https://en.wikipedia.org/wiki/Coordinated_Universal_Time) rely on the
  Gregorian calendar, so this seems like a reasonable simplification.
* Civil times are time zone independent. This frees programmers from the
  complexities of daylight-saving time, UTC offset transitions, and even leap
  seconds, while working in the civil time domain. Programmers can instead
  reason using the simple rules of the calendar and write code that is agnostic
  of time zone. (Note: leap seconds, like DST, are YMDHMS constraints that are
  time-zone specific, while leap days are calendar specific and are therefore
  applied by the civil-time types.)
* Civil times are always valid. There is no invalid civil time or error state
  that needs to be checked. This is enforced by normalizing input fields
  (similar to `mktime(3)`), for example, Jan 32 will normalize to Feb 1. Note:
  If normalization is undesired, callers can compare the resulting normalized
  fields to the input fields to signal an error.

The core of the Civil Time Library is based on the following six individual
classes:

* `civil_second`
* `civil_minute`
* `civil_hour`
* `civil_day`
* `civil_month`
* `civil_year`

Each class is a simple value type with the same interface for construction and
the same six accessors for each of the YMDHMS fields. These classes differ only
in their *alignment* and their semantics regarding addition, subtraction, and
difference.

A civil time class is aligned to the civil-time field indicated in the class's
name. Alignment is performed by setting all the inferior fields to their minimum
valid value. Hours, minutes, and seconds will be set to 0, and month and day
will be set to 1. The following are examples of how each of the six types would
align the civil time representing February 3, 2015 at 04:05:06 in the morning
(Note: the string format used here is not important).

 Class          | Example alignment
----------------|---------------------
 `civil_second` | `2015-02-03 04:05:06`
 `civil_minute` | `2015-02-03 04:05:00`
 `civil_hour`   | `2015-02-03 04:00:00`
 `civil_day`    | `2015-02-03 00:00:00`
 `civil_month`  | `2015-02-01 00:00:00`
 `civil_year`   | `2015-01-01 00:00:00`

Each civil time type performs arithmetic on the field to which it is aligned.
This means that adding 1 to a `civil_day` increments the day field (normalizing
as necessary), and subtracting 7 from a `civil_month` operates on the month
field (normalizing as necessary). All arithmetic produces a new value that
represents a valid civil time. Difference requires two similarly aligned civil
time types and returns the scaler answer in units of the given alignment. For
example, the difference between two `civil_hour` objects will give an answer in
hours.

XXX: Put this foot not somewhere.
[
One of the classic questions that arises when talking about a Civil Time Library
(aka a date library or a date/time library) is this: "What happens when you add
a month to Jan 31?" This is an interesting question because there could be a
number of possible answers, such as:

* Error. The caller gets some error, maybe an exception, maybe an invalid date
  object, or maybe `false` is returned. This may make sense because there's no
  single unambiguously correct answer.
* Maybe Feb 28 (or 29 if a leap year). This may make sense because the operation
  goes from the last day of January to the last day of February.
* Maybe March 3 (or 2 if a leap year). This may make sense because the operation
  goes to the equivalent of Feb 31.

Any answer that is not what the programmer expected is the wrong answer.

The Civil Time Library described here avoids this question by making it
impossible to ask such a question because of alignment requirements. To solve
the problem, callers will have to be more explicit in their code about how they
want to handle that situation. In practice, we have found few places where
programmers wanted to do unaligned arithmetic.
]

Finally, in addition to the six civil time types just described, there are a
handful of helper functions and algorithms for performing common calculations.
These will be described in the API section below.

## API

The following code snippet illustrates the public API for each of the civil time
types described above. As an implementation choice, Google chose to write one
class template that is parameterized on the alignment field as a tag struct.

XXX: jgm, update this code with proper constexpr usage.

```cpp
namespace detail {
template <typename Alignment>
class civil_time {
 public:
  explicit civil_time(int y, int m = 1, int d = 1, int hh = 0, int mm = 0, int ss = 0);
  civil_time() : civil_time(1970) {}
  civil_time(const civil_time&) = default;
  civil_time& operator=(const civil_time&) = default;

  // Explicit conversion between civil times of different alignment.
  template <typename U>
  explicit civil_time(civil_time<U>);

  // Field Accessors
  int year() const;
  int month() const;
  int day() const;
  int hour() const;
  int minute() const;
  int second() const;

  // Arithmetic
  civil_time& operator+=(int);
  civil_time& operator-=(int);
  civil_time& operator++();
  civil_time operator++(int);
  civil_time& operator--();
  civil_time operator--(int);

  // Binary arithmetic operators.
  inline friend civil_time operator+(civil_time, int) { ... }
  inline friend civil_time operator+(int, civil_time) { ... }
  inline friend civil_time operator-(civil_time, int) { ... }
  inline friend int operator-(civil_time, civil_time) { ... }

 private:
  ...
};

// Relational operators that work with differently aligned objects.
// Always compares all six YMDHMS fields.
template <typename Alignment1, typename Alignment2>
bool operator<(civil_time<Alignment1>, civil_time<Alignment2>);
template <typename Alignment1, typename Alignment2>
bool operator<=(civil_time<Alignment1>, civil_time<Alignment2>);
template <typename Alignment1, typename Alignment2>
bool operator>=(civil_time<Alignment1>, civil_time<Alignment2>);
template <typename Alignment1, typename Alignment2>
bool operator>(civil_time<Alignment1>, civil_time<Alignment2>);
template <typename Alignment1, typename Alignment2>
bool operator==(civil_time<Alignment1>, civil_time<Alignment2>);
template <typename Alignment1, typename Alignment2>
bool operator!=(civil_time<Alignment1>, civil_time<Alignment2>);

struct year_tag {};
struct month_tag {};
struct day_tag {};
struct hour_tag {};
struct minute_tag {};
struct second_tag {};

}  // namespace detail

// The six public civil time types.
using civil_year = detail::civil_time<detail::year_tag>;
using civil_month = detail::civil_time<detail::month_tag>;
using civil_day = detail::civil_time<detail::day_tag>;
using civil_hour = detail::civil_time<detail::hour_tag>;
using civil_minute = detail::civil_time<detail::minute_tag>;
using civil_second = detail::civil_time<detail::second_tag>;

```

In addition to the six civil time types defined above, the following helper
functions are also defined to help with common computations.

```cpp
enum class weekday {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday
};

// Returns the civil_day that strictly follows or precedes the argument,
// and that falls on the given weekday.
civil_day next_weekday(const civil_day&, weekday);
civil_day prev_weekday(const civil_day&, weekday);

weekday get_weekday(const civil_day&);
int get_yearday(const civil_day&);

```

## Examples

The following examples show how to use the proposed Civil Time Library, as well
as illustrate interesting semantics of various API points.

As a shorthand in the examples below, the YMDHMS fields of a civil time type may
be shown as a string of the form `YYYY-MM-DD HH:MM:SS`. Fields omitted from the
string format still exist and are assumed to have their minimum value. For
example:

```cpp
civil_day d(2015, 2, 3);
// d.year() == 2015
// d.month() == 2
// d.day() == 3
// d.hour() == 0
// d.minute() == 0
// d.second() == 0
// Shorthand: d == 2015-02-03
// ...same as d == 2015-02-03 00:00:00
```

### Construction

Civil time types can be constructed in two ways: by directly passing 1-6
integers for the YMDHMS fields (all but the year are optional) to the
constructor, or by copying the fields from a differently aligned civil time
type.

```cpp
civil_day a(2015, 2, 3);           // 2015-02-03 00:00:00
civil_day b(2015, 2, 3, 4, 5, 6);  // 2015-02-03 00:00:00
civil_day c(2015);                 // 2015-01-01 00:00:00

civil_second ss(2015, 2, 3, 4, 5, 6);  // 2015-02-03 04:05:06
civil_minute mm(ss);                   // 2015-02-03 04:05:00
civil_hour hh(mm);                     // 2015-02-03 04:00:00
civil_day d(hh);                       // 2015-02-03 00:00:00
civil_month m(d);                      // 2015-02-01 00:00:00
civil_year y(m);                       // 2015-01-01 00:00:00

m = civil_month(y);                    // 2015-01-01 00:00:00
d = civil_day(m);                      // 2015-01-01 00:00:00
hh = civil_hour(d);                    // 2015-01-01 00:00:00
mm = civil_minute(hh);                 // 2015-01-01 00:00:00
ss = civil_second(mm);                 // 2015-01-01 00:00:00
```

### Comparison

Comparison always considers all six YMDHMS fields, regardless of the type's
alignment. Comparison between differently aligned civil time types is allowed.

Note: Comparison between differently aligned types is not a critical part of
this API. It exists as a convenience, but it could be removed at the cost of
requiring more explicit casts between civil time types.

```cpp
civil_day feb_3(2015, 2, 3);  // 2015-02-03 00:00:00
civil_day mar_4(2015, 3, 4);  // 2015-03-04 00:00:00
// feb_3 < mar_4
// civil_year(feb_3) == civil_year(mar_4)

civil_second feb_3_noon(2015, 2, 3, 12);  // 2015-02-03 12:00:00
// feb_3 < feb_3_noon
// feb_3 == civil_day(feb_3_noon)

// Iterates all the days of February 2015.
for (civil_day d(2015, 2, 1); d < civil_month(2015, 3); ++d) {
  // ...
}
```

### Arithmetic

Civil time types support natural arithmetic operators such as addition,
subtraction, and difference. Arithmetic operates on the civil field indicated in
the type's name. Difference requires arguments with the same alignment and
returns the answer in units of the alignment.

```cpp
civil_day a(2015, 2, 3);
++a;                  // 2015-02-04 00:00:00
--a;                  // 2015-02-03 00:00:00
civil_day b = a + 1;  // 2015-02-04 00:00:00
civil_day c = 1 + b;  // 2015-02-05 00:00:00
int n = c - a;        // n = 2 (days)
int m = c - civil_month(c);  // Won't compile: different types.
```

### Weekdays

The Civil Time Library provides the `prev_weekday()` and `next_weekday()`
functions for navigating a calendar by the day of the week. Both functions
accept a `civil_day` argument as well as the desired `weekday`. They both return
a strictly different `civil_day` that falls on the given `weekday`, even if the
argument was already on the requested weekday.

```cpp
//     August 2015
// Su Mo Tu We Th Fr Sa
//                    1
//  2  3  4  5  6  7  8
//  9 10 11 12 13 14 15
// 16 17 18 19 20 21 22
// 23 24 25 26 27 28 29
// 30 31

civil_day a(2015, 8, 13);  // get_weekday(a) == weekday::thursday
civil_day b = next_weekday(a, weekday::thursday);  // 2015-08-20
civil_day c = prev_weekday(a, weekday::thursday);  // 2015-08-06

civil_day d = ...
// Gets the following Thursday if d is not already Thursday
civil_day ceil_thursday = prev_weekday(d, weekday::thursday) + 7;
// Gets the previous Thursday if d is not already Thursday
civil_day floor_thursday = next_weekday(d, weekday::thursday) - 7;
```

[Proleptic Gregorian Calendar]: https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar
