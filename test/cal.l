; 'cal: civil-from-days and its inverse are exact by construction, and the round trip is
; what holds them -- a leap-year slip would only show on one day a year
(: civil (cite 'cal 'civil) epoch-days (cite 'cal 'epoch-days)
   wday (cite 'cal 'wday) mdays (cite 'cal 'mdays)
   mon3 (cite 'cal 'mon3) monl (cite 'cal 'monl) wd3 (cite 'cal 'wd3) wdl (cite 'cal 'wdl)
   (rt z) (civil z @ c (epoch-days <c <>c <>>c = z))
   (test
      (civil 0 = '(1970 1 1)) (civil 1 = '(1970 1 2)) (civil -1 = '(1969 12 31))
      (civil 19675 = '(2023 11 14)) (civil 20682 = '(2026 8 17))
      (civil 11016 = '(2000 2 29))                     ; a century divisible by 400 is leap
      (civil 11017 = '(2000 3 1))
      (civil -25508 = '(1900 3 1))                     ; ..and 1900 is not
      (epoch-days 1970 1 1 = 0) (epoch-days 2000 2 29 = 11016) (epoch-days 1900 3 1 = -25508)
      (rt 0) (rt 1) (rt -1) (rt 19675) (rt 11016) (rt 20682) (rt 40000) (rt -25508)
      (wday 0 = 4) (wday 3 = 0) (wday -1 = 3) (wday -4 = 0)   ; before 1970 too
      (mdays 2024 2 = 29) (mdays 2023 2 = 28) (mdays 1900 2 = 28) (mdays 2000 2 = 29)
      (mdays 2023 12 = 31) (mdays 2023 4 = 30)
      (mon3 0 = "Jan") (monl 11 = "December") (wd3 0 = "Sun") (wdl 6 = "Saturday")
      (12 = #mon3) (7 = #wdl)))
