# C++ Standard Proposal&mdash;A Civil Time Library

## Motivation

Programming with time on a humane-scale is notoriously difficult and error
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
three simple concepts that we will define here.

*Absolute time* uniquely and universally represents a specific instant in time.
They have no notion of calendars, or dates, or times of day. Instead, they
measure the passage of real time, typically as a simple count of ticks since
some epoch. Absolute times are independent of all time zones and do not suffer
from human-imposed complexities such as daylight-saving time (DST). Many C++
types exist to represent absolute times, classically `time_t` and more recently
`std::chrono::time_point`.

*Civil time* is the legally recognized representation of time for ordinary
affairs (cf. http://www.merriam-webster.com/dictionary/civil). It is a
humane-scale representation of time that consists of the six fields &mdash;
year, month, day, hour, minute, and second (sometimes shortened to "YMDHMS")
&mdash; and it follows the rules of the [Proleptic Gregorian Calendar], with
24-hour days divided into hours and minutes. Civil times are also independent of
all time zones and their related complexities (e.g., DST). While `std::tm`
contains the six YMDHMS civil-time fields (plus a few more), it does not have
behavior that enforces the rules of civil times just described.

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
  complexities of daylight-saving, UTC offset transitions, and even leap
  seconds, while working in the civil time domain. Programmers can instead
  reason using the simple rules of the calendar and write code that is agnostic
  of time zone. (XXX: Should I say more about leap seconds? Foot note).
* Civil times are always valid. There is no invalid civil time or error state
  that needs to be checked. This is enforced by normalizing input fields using
  the same rules that `mktime(3)` uses (for example, January 32 will normalize
  to February 1). Note: If normalization is undesired, callers can compare the
  resulting normalized fields to the input fields to generate an error.

The core of the civil time library is based on the following six individual
classes:

* `civil_second`
* `civil_minute`
* `civil_hour`
* `civil_day`
* `civil_month`
* `civil_year`

Each class is a simple value type with the same interface for construction and
the same six attributes (a getter for each of the YMDHMS fields). These
classes differ only in their alignment and their semantics regarding addition,
subtraction, and difference.

Alignment is performed by setting all the inferior fields to their minimum valid
value. Hours, minutes, and seconds will be set to 0, and month and day will be
set to 1. The following are examples of how each of the six types would align
the civil time representing February 2, 2016 at 04:05:06 in the morning (Note:
the format used here is not important).

 Class          | Example alignment   
----------------|---------------------
 `civil_second` | `2016-02-03 04:05:06` 
 `civil_minute` | `2016-02-03 04:05:00` 
 `civil_hour`   | `2016-02-03 04:00:00` 
 `civil_day`    | `2016-02-03 00:00:00` 
 `civil_month`  | `2016-02-01 00:00:00` 
 `civil_year`   | `2016-01-01 00:00:00` 

In addition to alignment, each civil time type performs arithmetic on the field
to which it is aligned. This means that adding 1 to a `civil_day` increments the
day field (normalizing as necessary), and subtracting 7 from a `civil_month`
operates the month field (which may underflow into the year field when
normalizing). All arithmetic produces a new civil time value that is valid.
Difference requires two similarly aligned civil time types and returns the
scaler answer in units of the given alignment. For example, the difference
between two `civil_hour` objects will give an answer in hours.

(XXX: jgm The misc. section below talks about how the reason that alignment is
so useful.)

Finally, in addition to the six civil time types just described, there are a
handful of helper functions and algorithms for performing common calculations.
These will be described in the API section below.

## API

The following code snippet illustrates the public API for each of the civil time
types described above. As an implementation choice, Google chose to write one
class template that is parameterized on the alignment field as a tag struct.

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
enum class Weekday {
  Sunday,
  Monday,
  Tuesday,
  Wednesday,
  Thursday,
  Friday,
  Saturday
};

// Returns the civil_day that strictly follows or precedes the argument,
// and that falls on the given weekday.
civil_day NextWeekday(const civil_day&, Weekday);
civil_day PrevWeekday(const civil_day&, Weekday);

Weekday Weekday(const civil_day&);
int Yearday(const civil_day&);

```

## Examples


## Misc.

One of the classic questions that arises when talking about a civil time library
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

The civil time library described here avoids this question by making it
impossible to ask such a question. This is done by aligning all civil time
objects to one of the six civil time unit boundaries. For example:


[Proleptic Gregorian Calendar]: https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar
