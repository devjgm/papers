# C++ Standard Proposal &mdash; A Civil Time Library

Metadata        | Value
:---------------|:------
Document number | Nnnnn=yy-nnnn
Date            | yyyy-mm-dd
Project         | Programming Language C++, Library Working Group
Reply-to        | Greg Miller (jgm at google dot com), Bradley White (bww at google dot com)

## Introduction

This document proposes a standard C++ library for computing with time that is
represented by years, months, and days that follow the rules of the [Proleptic
Gregorian Calendar], as well as 24-hour days that are divided into hours,
minutes, and seconds. These six fields are how humans commonly experience time.
This time-zone-independent representation is called *civil time*.

## Motivation and Scope

Programming with time on a human scale is notoriously difficult and error prone:
time zones are complicated, daylight-saving time (DST) is complicated, calendars
are complicated, and leap seconds are complicated. These complexities quickly
surface in code because programmers do not have a simple conceptual model with
which to reason about the time-programming challenges they are facing.
Furthermore, this lack of a simple conceptual model begets the lack of a simple
library, leaving only complicated libraries (or none at all) that programmers
struggle to understand and use correctly.

A survey of application-level code within Google that computes with civil-time
fields shows that programmer confusion is a fundamental cause of overly
complicated and buggy code. This is a result of the previously mentioned
complexities that are inherent in this problem space, and the fact that there
has been little progress toward hiding these complexities behind a library that
exposes a simpler conceptual model to programmers.

The Civil Time Library proposed here addresses the above problems by presenting
civil time as a *regular*, time-zone-independent concept that allows programmers
to ignore the above complexities when it is safe to do so. This library has been
implemented and widely used within Google for the past few years. It is actively
used in real-world code by programmers from novice to expert.

## The Conceptual Model and Terminology

Civil time, as described in this proposal, is one of the three concepts that
together form a complete conceptual model for reasoning about even the most
complex time-programming challenges. This conceptual model is easy to understand
and is even programming language neutral. This model is made up of the following
three concepts: *absolute time*, *civil time*, and *time zone*.

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
days divided into hours, minutes, and seconds. Like absolute times, civil times
are also independent of all time zones and their related complexities (e.g.,
DST). While `std::tm` contains the six YMDHMS civil-time fields (plus a few
more), it does not have behavior to enforce the rules of civil time as just
described.

*Time zones* are geo-political regions within which human-defined rules are
shared to convert between the previously described absolute time and civil time
domains. A time-zone's rules include things like the region's offset from the
[UTC] time standard, daylight-saving adjustments, and short abbreviation
strings. Time zones often have a history of disparate rules that apply only for
certain periods, because the rules may change at the whim of a region's local
government. For this reason, time zone rules are often compiled into data
snapshots that are used at runtime to perform conversions between absolute and
civil times. There is currently no standard library supporting arbitrary time
zones.

The C++ standard already has the `<chrono>` library, which is a good
implementation of an *Absolute Time* Library. This paper proposes a standard
*Civil Time* Library that complements `<chrono>`. A separate paper (XXX: jgm
insert the paper number) proposes a standard *Time Zone* Library that bridges
`<chrono>` and this Civil Time Library, and will complete the three pillars of
the conceptual model just described.

## Impact on the Standard

The Civil Time Library proposed here is not directly dependent on any other
standard C++ library. It is implementable using C++98, with optimizations such
as `constexpr` available when compiled as C++11.

A current sister proposal that describes a standard Time Zone Library (XXX: jgm
add a doc reference) depends on the existence of this Civil Time Library.

## Design Decisions

### The Proleptic Gregorian Calendar is used

Many different calendaring systems exist in the world, but the most commonly
used calendar is the [Proleptic Gregorian Calendar]. Supporting rarely used
calendars would add complexity to the library with little value. Additionally,
international standards such as [UTC] rely on the Gregorian Calendar. Therefore,
we've chosen not to support other calendars.

### Leap seconds are disregarded

Unlike leap days, which are part of the [Proleptic Gregorian Calendar], leap
seconds are unpredictable and would require time zone knowledge to properly
support in the civil time domain. Time zone awareness in the civil time domain
would add non-trivial conceptual complexity for a rare use case. The simplicity
of this Civil Time Library stems from presenting a regularized human-scale time
representation that is devoid of complexities and discontinuities, such as those
caused by DST and leap seconds. We believe it would be a mistake to expose leap
second complexities in the civil time domain. If knowledge of leap seconds were
necessary, that support should exist in a separate time zone library rather than
a civil time library.

### Civil times are always valid

It is not possible to create an invalid civil time instance. Similarly, there
are no errors when constructing a civil time with field values that are out of
range. This is enforced by normalizing input fields (similar to `mktime(3)`),
for example, Jan 32 will normalize to Feb 1. This decision reduces the amount of
boilerplate error checking, and it allows callers to do arithmetic on input field
arguments without worrying about range. If normalization is undesired, callers
may compare the resulting normalized fields to the input fields to signal an error.

### Civil times do not have subseconds

Civil times are represented by the six fields of year, month, day, hour, minute,
and second. These are the six fields that are typically considered for
human-scale time. Additionally, seconds are the level of precision within time
zone data files; i.e., there are no subsecond time zone transitions. It would be
possible to add subseconds to this Civil Time Library, but it would add some
complexity for which we have found no demand.

### Civil times are aligned to a civil-field boundary

One of the classic questions that arises when talking about a civil time library
(aka a date library or a date/time library) is this: "What happens when you add
a month to Jan 31?" This is an interesting question because there could be a
number of possible answers:

* Maybe March 3 (or 2 if a leap year). This may make sense because the operation
  goes to the equivalent of Feb 31.
* Maybe Feb 28 (or 29 if a leap year). This may make sense because the operation
  goes from the last day of January to the last day of February.
* Maybe Error. The caller gets some error, maybe an exception, maybe an invalid
  date object, or maybe `false` is returned. This may make sense because there
  is no single unambiguously correct answer to the question.

Practically speaking, any answer that is not what the programmer intended is the
wrong answer.

The Civil Time Library proposed here avoids this problem by making it impossible
to ask such an ambiguous question. All civil time objects are aligned to a
particular civil-field boundary (such as aligned to a year, month, day, hour,
minute, or second), and arithmetic operates on the field to which the object is
aligned. This means that in order to "add a month" the object must first be
aligned to a month boundary, which is equivalent to the first day of that month.
See the Technical Specification section below for more about alignment.

There are indeed ways to accomplish the task of adding a month to Jan 31 with
this Civil Time Library, but they require the programmer to be more explicit
about their intent so the answer is unsurprising. There is an example showing
this later in this paper. In practice, we have found few places in Google code
where programmers wanted unaligned arithmetic, but in those few cases the
explicit code helped ensure the programmer's intent matched the answer they got.

## Technical Specification

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
in their *alignment*, which is indicated by the type name and specifies the
field on which arithmetic operates.

Each class can be constructed by passing from 0-6 optional integer arguments
representing the YMDHMS fields (in that order) to the constructor. Omitted
fields are assigned their minimum valid value. Hours, minutes, and seconds will
be set to 0, month and day will be set to 1, and year will be set to 1970.
A default-constructed civil time object will have YMDHMS fields representing
"1970-01-01 00:00:00".

Each civil time class is aligned to the civil-time field indicated in the
class's name. Alignment is performed by setting all the inferior fields to their
minimum valid value (see above for the minimum valid values). The following are
examples of how each of the six types would align the fields representing
November 22, 2015 at 12:34:56 in the afternoon (Note: the string format used
here is not important; it's just a shorthand way of showing the six YMDHMS
fields).

 Class          | Example alignment
----------------|---------------------
 `civil_second` | `2015-11-22 12:34:56`
 `civil_minute` | `2015-11-22 12:34:00`
 `civil_hour`   | `2015-11-22 12:00:00`
 `civil_day`    | `2015-11-22 00:00:00`
 `civil_month`  | `2015-11-01 00:00:00`
 `civil_year`   | `2015-01-01 00:00:00`

Each civil time type performs arithmetic on the field to which it is aligned.
This means that adding 1 to a `civil_day` increments the day field (normalizing
as necessary), and subtracting 7 from a `civil_month` operates on the month
field (normalizing as necessary). All arithmetic produces a new value that
represents a valid civil time. Difference requires two similarly aligned civil
time types and returns the scaler answer in units of the given alignment. For
example, the difference between two `civil_hour` objects will give an answer in
hours.

Finally, in addition to the six civil time types just described, there are a
handful of helper functions and algorithms for performing common calculations.
These will be described in the Synopsis below.

## Synopsis

The following code illustrates the public API for each of the six civil time
types described above. As an implementation choice, Google chose to write one
class template that is parameterized on the alignment field as a tag struct.
This class template is not a public API point, but it serves here to illustrate
the API of each of the public civil time types.

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
  inline friend civil_time operator+(const civil_time&, int) { ... }
  inline friend civil_time operator+(int, const civil_time&) { ... }
  inline friend civil_time operator-(const civil_time&, int) { ... }
  inline friend int operator-(const civil_time&, const civil_time&) { ... }

 private:
  ...
};

// Relational operators that work with differently aligned objects.
// Always compares all six YMDHMS fields.
template <typename Alignment1, typename Alignment2>
bool operator<(const civil_time<Alignment1>&, const civil_time<Alignment2>&);
template <typename Alignment1, typename Alignment2>
bool operator<=(const civil_time<Alignment1>&, const civil_time<Alignment2>&);
template <typename Alignment1, typename Alignment2>
bool operator>=(const civil_time<Alignment1>&, const civil_time<Alignment2>&);
template <typename Alignment1, typename Alignment2>
bool operator>(const civil_time<Alignment1>&, const civil_time<Alignment2>&);
template <typename Alignment1, typename Alignment2>
bool operator==(const civil_time<Alignment1>&, const civil_time<Alignment2>&);
template <typename Alignment1, typename Alignment2>
bool operator!=(const civil_time<Alignment1>&, const civil_time<Alignment2>&);

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

weekday get_weekday(const civil_day&);
int get_yearday(const civil_day&);

// Returns the civil_day that strictly follows or precedes the argument,
// and that falls on the given weekday.
civil_day next_weekday(const civil_day&, weekday);
civil_day prev_weekday(const civil_day&, weekday);
```

## Examples

The following examples show usage of the proposed Civil Time Library, as well as
illustrate interesting semantics of various API points.

As a shorthand in the examples below, the YMDHMS fields of a civil time type may
be shown as a string of the form `YYYY-MM-DD hh:mm:ss`. Fields omitted from the
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

Civil time types can be constructed in two ways: by directly passing 0-6
integers representing the YMDHMS fields to the constructor, or by copying the
fields from a differently aligned civil time type.

```cpp
civil_day default_value;           // 1970-01-01 00:00:00

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
requiring explicit casts between civil time types when comparing.

```cpp
civil_day feb_3(2015, 2, 3);  // 2015-02-03 00:00:00
civil_day mar_4(2015, 3, 4);  // 2015-03-04 00:00:00
// feb_3 < mar_4
// civil_year(feb_3) == civil_year(mar_4)

civil_second feb_3_noon(2015, 2, 3, 12, 0, 0);  // 2015-02-03 12:00:00
// feb_3 < feb_3_noon
// feb_3 == civil_day(feb_3_noon)

// Iterates all the days of February 2015.
for (civil_day d(2015, 2, 1); d < civil_month(2015, 3); ++d) {
  // ...
}
```

### Arithmetic

Civil time types support natural arithmetic operators such as addition,
subtraction, and difference. Arithmetic operates on the civil field indicated
in the type's name. Difference requires arguments with the same alignment and
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
accept a `civil_day` argument as well as the desired `weekday`. They both
return a strictly different `civil_day` that falls on the given `weekday`, even
if the argument was already on the requested weekday.

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

### Adding a month to Jan 31

See the Design Decisions section above for an explanation of why this is an
ambiguous question. As described above, this Civil Time Library makes it
impossible to directly ask this ambiguous question because of alignment
requirements. However, if a programmer really wants to ask this question, they
need to be more explicit about what the answer will be. For example:

```cpp
const civil_day d(2015, 1, 31);

// Answer 1:
// Adds 1 to the month field in the constructor, and let normalization happen.
const auto ans_normalized = civil_day(d.year(), d.month() + 1, d.day());
// ans_normalized == 2015-03-03 (aka Feb 31)

// Answer 2:
// Adds 1 to month field, capping at the end of next month
const auto last_day_of_next_month = civil_day(civil_month(d) + 2) - 1;
const auto ans_capped = std::min(ans_normalized, last_day_of_next_month);
// ans_capped == 2015-02-28

// Answer 3:
if (civil_month(ans_normalized) - civil_month(d) != 1) {
  ... error, month overflow...
}
```

## Acknowledgements

* https://en.wikipedia.org/wiki/Civil_time
* http://www.merriam-webster.com/dictionary/civil
* http://www.timeanddate.com/time/aboututc.html
* https://en.wikipedia.org/wiki/Coordinated_Universal_Time
* https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar

[Proleptic Gregorian Calendar]: https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar
[UTC]: https://en.wikipedia.org/wiki/Coordinated_Universal_Time
