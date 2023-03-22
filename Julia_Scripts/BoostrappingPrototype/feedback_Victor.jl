using Dates
using BenchmarkTools
abstract type DayCountConv end

struct ACT360 <: DayCountConv end
struct ACT365F <: DayCountConv end

function dayCountFactor(::ACT360, dt1::Date, dt2::Date)::Float64
    return Dates.value(dt2 - dt1)/360
end

function dayCountFactor(::ACT365F, dt1::Date, dt2::Date)::Float64
    return Dates.value(dt2 - dt1)/365
end

dcc = ACT360()
dt1 = Date(2020, 4, 22)
dt2 = Date(2020, 12, 31)

dayCountFactor(ACT360(), dt1, dt2)
dayCountFactor(ACT365F(), dt1, dt2)

function kk()

    D = [ACT365F(), ACT360(), ACT365F()]
    DT1 = [Date(2020, 4, 18), Date(2020, 4, 22), Date(2020, 4, 23)]
    DT2 = [Date(2020, 7, 27), Date(2020, 8, 10), Date(2020, 12, 31)]

    x = dayCountFactor.(D, DT1, DT2)
end

@btime kk()


struct Curve
    offset::Vector{Int64}
    DF::Vector{Float64}
end

c = Curve([0, 7, 30], [1.0, 0.99, 0.97])
c.offset
c.DF

abstract type Instrument end

struct Cash <:Instrument
    startDate::Date
    spotDays::Int64
    tenor::String
    rate::Float64
    dcc::dayCountConv
end


function addTenor(dt::Date, tenor::String)::Date

end

addTenor(Date(2020, 4, 22), "182cd")
