//
//  main.swift
//  ISO8601
//
//  Created by Miroslav Perovic on 6/23/15.
//  Copyright © 2015 Miroslav Perovic. All rights reserved.
//

import Foundation

final class ISO8601Formatter: NSFormatter {
	enum ISO8601DateStyle: Int {
		case CalendarLongStyle			// Default (YYYY-MM-DD)
		case CalendarShortStyle			//         (YYYYMMDD)
		case OrdinalLongStyle			//         (YYYY-DDD)
		case OrdinalShortStyle			//         (YYYYDDD)
		case WeekLongStyle				//         (YYYY-Www-D)
		case WeekShortStyle				//         (YYYYWwwD)
	}
	
	enum ISO8601TimeStyle: Int {
		case None
		case LongStyle					// Default (hh:mm:ss)
		case ShortStyle					//         (hhmmss)
	}
	
	enum ISO8601TimeZoneStyle: Int {
		case None
		case UTC						// Default (Z)
		case LongStyle					//         (±hh:mm)
		case ShortStyle					//         (±hhmm)
	}
	
	enum ISO8601FractionSeparator: Int {
		case Comma						// Default (,)
		case Dot						//         (.)
	}
	
	var dateStyle: ISO8601DateStyle
	var timeStyle: ISO8601TimeStyle
	var fractionSeparator: ISO8601FractionSeparator
	var timeZoneStyle: ISO8601TimeZoneStyle
	var fractionDigits: Int
	
	let days365 = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	let days366 = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
	
	convenience override init() {
		self.init(
			dateStyle: .CalendarLongStyle,
			timeStyle: .LongStyle,
			fractionSeparator: .Comma,
			fractionDigits: 6,
			timeZoneStyle: .UTC
		)
	}
	
	init(dateStyle: ISO8601DateStyle, timeStyle: ISO8601TimeStyle, fractionSeparator: ISO8601FractionSeparator, fractionDigits: Int, timeZoneStyle: ISO8601TimeZoneStyle) {
		self.dateStyle = dateStyle
		self.timeStyle = timeStyle
		self.fractionSeparator = fractionSeparator
		self.fractionDigits = fractionDigits
		self.timeZoneStyle = timeZoneStyle
		
		super.init()
	}
	
	required convenience init?(coder aDecoder: NSCoder) {
		self.init(
			dateStyle: .CalendarLongStyle,
			timeStyle: .LongStyle,
			fractionSeparator: .Comma,
			fractionDigits: 6,
			timeZoneStyle: .UTC
		)
	}
	
	func stringFromDate(date: NSDate) -> String? {
		let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let dateComponents = gregorian.components(
			[.Year, .Month, .Day, .WeekOfYear, .Hour, .Minute, .Second, .Weekday, .WeekdayOrdinal, .WeekOfYear, .YearForWeekOfYear, .TimeZone],
			fromDate: date
		)
		var string: String
		
		if dateComponents.year < 0 || dateComponents.year > 9999 {
			return nil
		}
		
		string = String(format: "%04li", dateComponents.year)
		if dateStyle == .WeekLongStyle || dateStyle == .WeekShortStyle {
			// For weekOfYear calculation see more at: https://en.wikipedia.org/wiki/ISO_8601#Week_dates
			if date.weekOfYear() == 53 {
				string = String(format: "%04li", dateComponents.year - 1)
			}
		}
		
		switch dateStyle {
		case .CalendarLongStyle:
			string = string + String(format: "-%02i-%02i", dateComponents.month, dateComponents.day)
		case .CalendarShortStyle:
			string = string + String(format: "%02i%02i", dateComponents.month, dateComponents.day)
		case .OrdinalLongStyle:
			string = string + String(format: "-%03i", date.dayOfYear())
		case .OrdinalShortStyle:
			string = string + String(format: "%03i", date.dayOfYear())
		case .WeekLongStyle:
			if dateComponents.weekday > 1 {
				string = string + String(format: "-W%02i-%01i", date.weekOfYear(), dateComponents.weekday - 1)
			} else {
				string = string + String(format: "-W%02i-%01i", date.weekOfYear(), 7)
			}
		case .WeekShortStyle:
			if dateComponents.weekday > 1 {
				string = string + String(format: "W%02i%01i", dateComponents.weekOfYear, dateComponents.weekday - 1)
			} else {
				string = string + String(format: "W%02i%01i", dateComponents.weekOfYear, 7)
			}
		}
		
		let timeString: String
		switch timeStyle {
		case .LongStyle:
			timeString = String(format: "T%02i:%02i:%02i", dateComponents.hour, dateComponents.minute, dateComponents.second)
		case .ShortStyle:
			timeString = String(format: "T%02i:%02i:%02i", dateComponents.hour, dateComponents.minute, dateComponents.second)
		case .None:
			return string
		}
		string = string + timeString
		
		if let timeZone = dateComponents.timeZone {
			let timeZoneString: String
			switch timeZoneStyle {
			case .UTC:
				timeZoneString = "Z"
				
			case .LongStyle, .ShortStyle:
				let hoursOffset = timeZone.secondsFromGMT / 3600
				let secondsOffset = 0
				let sign = hoursOffset >= 0 ? "+" : "-"
				if timeZoneStyle == .LongStyle {
					timeZoneString = String(format: "%@%02i:%02i", sign, hoursOffset, secondsOffset)
				} else {
					timeZoneString = String(format: "%@%02i%02i", sign, hoursOffset, secondsOffset)
				}
				
			case .None:
				return string
			}
			string = string + timeZoneString
		}
		
		return string
	}
	
	func dateFromString(string: String) -> NSDate? {
		let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		gregorian.firstWeekday = 2	// Monday
		let str = self.convertBasicToExtended(string)
		
		let scanner = NSScanner(string: str)
		scanner.charactersToBeSkipped = nil
		
		let dateComponents = NSDateComponents()
		
		// Year
		var year = 0
		guard scanner.scanInteger(&year) else {
			return nil
		}
		
		guard year >= 0 && year <= 9999 else {
			return nil
		}
		dateComponents.year = year
		
		// Month or Week
		guard scanner.scanString("-", intoString: nil) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		
		var month = 0
		var ordinalDay = 0
		switch dateStyle {
		case .CalendarLongStyle, .CalendarShortStyle:
			guard scanner.scanInteger(&month) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			dateComponents.month = month
			
		case .OrdinalLongStyle, .OrdinalShortStyle:
			guard scanner.scanInteger(&ordinalDay) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			let daysArray: [Int]
			if ((year % 4) == 0 && (year % 100) != 0) || (year % 400) == 0 {
				daysArray = days366
			} else {
				daysArray = days365
			}
			var theMonth = 0
			for startDay in daysArray {
				theMonth++
				if startDay > ordinalDay {
					month = theMonth - 1
					break
				}
			}
			dateComponents.month = month
			
		case .WeekLongStyle, .WeekShortStyle:
			guard scanner.scanString("W", intoString: nil) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			
			var week = 0
			guard scanner.scanInteger(&week) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			if week < 0 || week > 53 {
				return gregorian.dateFromComponents(dateComponents)
			}
			dateComponents.weekOfYear = week
		}
		
		// Day or DayOfWeek
		var day = 0
		switch dateStyle {
		case .CalendarLongStyle, .CalendarShortStyle:
			guard scanner.scanString("-", intoString: nil) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			
			guard scanner.scanInteger(&day) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			dateComponents.day = day
			
		case .OrdinalLongStyle, .OrdinalShortStyle:
			let daysArray: [Int]
			if ((year % 4) == 0 && (year % 100) != 0) || (year % 400) == 0 {
				daysArray = days366
			} else {
				daysArray = days365
			}
			var theDay = 0
			var previousStartDay = 0
			for startDay in daysArray {
				if startDay > ordinalDay {
					theDay = ordinalDay - previousStartDay
					break
				}
				previousStartDay = startDay
			}
			dateComponents.day = theDay
			
		case .WeekLongStyle, .WeekShortStyle:
			guard scanner.scanString("-", intoString: nil) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			
			guard scanner.scanInteger(&day) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			if day < 0 || day > 7 {
				return gregorian.dateFromComponents(dateComponents)
			} else {
				dateComponents.weekday = day
			}
		}
		
		// Time
		guard scanner.scanCharactersFromSet(NSCharacterSet(charactersInString: "T"), intoString: nil) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		
		// Hour
		var hour = 0
		guard scanner.scanInteger(&hour) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		if timeStyle != .None {
			if hour < 0 || hour > 23 {
				return gregorian.dateFromComponents(dateComponents)
			} else {
				dateComponents.hour = hour
			}
		}
		
		// Minute
		guard scanner.scanString(":", intoString: nil) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		
		var minute = 0
		guard scanner.scanInteger(&minute) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		if timeStyle != .None {
			if minute < 0 || minute > 59 {
				return gregorian.dateFromComponents(dateComponents)
			} else {
				dateComponents.minute = minute
			}
		}
		
		// Second
		var scannerLocation = scanner.scanLocation
		if scanner.scanString(":", intoString: nil) {
			var second = 0
			guard scanner.scanInteger(&second) else {
				return gregorian.dateFromComponents(dateComponents)
			}
			if timeStyle != .None {
				if second < 0 || second > 59 {
					return gregorian.dateFromComponents(dateComponents)
				} else {
					dateComponents.second = second
				}
			}
		} else {
			scanner.scanLocation = scannerLocation
		}
		
		// Zulu
		scannerLocation = scanner.scanLocation
		scanner.scanUpToString("Z", intoString: nil)
		if scanner.scanString("Z", intoString: nil) {
			dateComponents.timeZone = NSTimeZone(forSecondsFromGMT: 0)
			
			return gregorian.dateFromComponents(dateComponents)
		}
		
		// Move back to the end of time
		scanner.scanLocation = scannerLocation
		
		// Look for offset
		let signs = NSCharacterSet(charactersInString: "+-")
		scanner.scanUpToCharactersFromSet(signs, intoString: nil)
		var sign: NSString?
		guard scanner.scanCharactersFromSet(signs, intoString: &sign) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		
		// Offset hour
		var timeZoneOffset = 0
		var timeZoneOffsetHour = 0
		var timeZoneOffsetMinute = 0
		guard scanner.scanInteger(&timeZoneOffsetHour) else {
			return gregorian.dateFromComponents(dateComponents)
		}
		
		// Check for colon
		let colonExists = scanner.scanString(":", intoString: nil)
		if !colonExists && timeZoneOffsetHour > 14 {
			timeZoneOffsetMinute = timeZoneOffsetHour % 100
			timeZoneOffsetHour = Int(floor(Double(timeZoneOffsetHour) / 100.0))
		} else {
			scanner.scanInteger(&timeZoneOffsetMinute)
		}
		
		timeZoneOffset = (timeZoneOffsetHour * 60 * 60) + (timeZoneOffsetMinute * 60)
		dateComponents.timeZone = NSTimeZone(forSecondsFromGMT: timeZoneOffset * (sign == "-" ? -1 : 1))
		
		return gregorian.dateFromComponents(dateComponents)
	}
	
	
	// Private methods
	private func checkAndUpdateTimeZone(string: NSMutableString, insertAtIndex index: Int) -> NSMutableString {
		if self.timeZoneStyle == .ShortStyle {
			string.insertString(":", atIndex: index)
		}
		
		return string
	}
	
	private func convertBasicToExtended(string: String) -> String {
		func checkAndUpdateTimeStyle(var string: NSMutableString, insertAtIndex index: Int) -> NSMutableString {
			if (self.timeStyle == .LongStyle) {
				string = self.checkAndUpdateTimeZone(string, insertAtIndex: index + 9)
			} else if (self.timeStyle == .ShortStyle) {
				string = self.checkAndUpdateTimeZone(string, insertAtIndex: index + 7)
				string.insertString(":", atIndex: index + 2)
				string.insertString(":", atIndex: index)
			}
			
			return string
		}
		
		var str: NSMutableString = NSMutableString(string: string)
		switch self.dateStyle {
		case .CalendarLongStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 13)
			
		case .CalendarShortStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 11)
			str.insertString("-", atIndex: 6)
			str.insertString("-", atIndex: 4)
			
		case .OrdinalLongStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 11)
			
		case .OrdinalShortStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 10)
			str.insertString("-", atIndex: 4)
			
		case  .WeekLongStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 13)
			
		case  .WeekShortStyle:
			str = checkAndUpdateTimeStyle(str, insertAtIndex: 11)
			str.insertString("-", atIndex: 7)
			str.insertString("-", atIndex: 4)
		}
		
		return String(str)
	}
}


extension NSDate {
	func isLeapYear() -> Bool {
		let dateComponents = NSCalendar.currentCalendar().components(
			[.Year, .Month, .Day, .WeekOfYear, .Hour, .Minute, .Second, .Weekday, .WeekdayOrdinal, .WeekOfYear, .TimeZone],
			fromDate: self
		)
		return ((dateComponents.year % 4) == 0 && (dateComponents.year % 100) != 0) || (dateComponents.year % 400) == 0 ? true : false
	}
	
	func dayOfYear() -> Int {
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "D"
		
		return Int(dateFormatter.stringFromDate(self))!
	}
	
	func weekOfYear() -> Int {
		let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		gregorian.firstWeekday = 2 // Monday
		gregorian.minimumDaysInFirstWeek = 4
		let components = gregorian.components([.WeekOfYear, .YearForWeekOfYear], fromDate: self)
		let week = components.weekOfYear
		
		return week
	}
}