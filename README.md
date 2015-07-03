# ISO8601Formatter

A small Swift NSFormatter subclass.

# USAGE

To convert ISO 8601 string to NSDate you can use ISO8601Formatter() without any configuration
``` swift
let date = ISO8601Formatter().dateFromString("2013-09-12T07:24:56+04:00")!
```

or you can use ISO8601Formatter the same way as you do with NSDateFormatter.
``` swift
let formatter = ISO8601Formatter()
formatter.timeStyle = .LongStyle
formatter.dateStyle = .LongStyle
let date = formatter.dateFromString("2013-09-12T07:24:56+04:00")!
```

To convert NSDate to ISO 8601 formatted string.
``` swift
let string = ISO8601Formatter().stringFromDate(date)
```

Also you can customize output.
``` swift
let formatter = ISO8601Formatter()
formatter.dateStyle = .CalendarLongStyle
formatter.timeStyle = .LongStyle
formatter.timeZoneStyle = .LongStyle
let string = formatter.stringFromDate(date)
```

