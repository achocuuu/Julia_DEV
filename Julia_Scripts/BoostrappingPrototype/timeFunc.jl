using Dates

"""Outputs the months given a string tenor (e.g. "3Y" would be 3*12 months)"""
function tenorMonths(tenor)
    typeofTenor = string(tenor[end])
    numTen = length(tenor)
    if typeofTenor == "Y"
        parse(Float64,tenor[1:numTen-1])*12
    elseif typeofTenor == "M"
        parse(Float64,tenor[1:numTen-1])*1
    elseif typeofTenor == "W"
        parse(Float64,tenor[1:numTen-1])
    else
        typeofTenor = 0
    end
end

"""It shift the date to de next business day if the date is sat or sun"""
function shiftDate(fecha)
    if Dates.dayofweek(fecha) == 6
        fecha + Dates.Day(2)
    elseif Dates.dayofweek(fecha) == 7
        fecha + Dates.Day(1)
    else
        fecha
    end
end
