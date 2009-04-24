# TODO - was having trouble deploying to heroku becuase of these?  Now it works fine.
CalendarDateSelect.format = :iso_date
CalendarDateSelect.default_options[:year_range] = 10.years.ago.to_date..Date.today
