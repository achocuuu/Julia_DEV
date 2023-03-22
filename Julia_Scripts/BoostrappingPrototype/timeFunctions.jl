using Dates
using BenchmarkTools
abstract type DayCountConv end

struct ACT360 <: DayCountConv end
struct ACT365F <: DayCountConv end
struct dc30360 <: DayCountConv end
struct dc30E360 <: DayCountConv end
#dayCountFactor
function dayCountFactor(::ACT360, dt1::Date, dt2::Date)::Float64
    return Dates.value(dt2 - dt1)/360
end

function dayCountFactor(::ACT365F, dt1::Date, dt2::Date)::Float64
    return Dates.value(dt2 - dt1)/365
end
function dayCountFactor(::dc30360, dt1::Date, dt2::Date)::Float64
    D1 = Dates.Day(dt1).value
    M1 = Dates.Month(dt1).value
    Y1 = Dates.Year(dt1).value
    D2 = Dates.Day(dt2).value
    M2 = Dates.Month(dt2).value
    Y2 = Dates.Year(dt2).value
    if (D1 == 31)
        D1 = 30
    end
    if (D2 == 31 && (D1 == 30 || D1 == 31))
        D2 = 30
    end
    return (360 * (Y2 - Y1) + 30 * (M2 - M1) + (D2 - D1)) / 360.00

end

function dayCountFactor(::dc30E360, dt1::Date, dt2::Date)::Float64
    D1 = Dates.Day(dt1).value
    M1 = Dates.Month(dt1).value
    Y1 = Dates.Year(dt1).value
    D2 = Dates.Day(dt2).value
    M2 = Dates.Month(dt2).value
    Y2 = Dates.Year(dt2).value
    if (D1 == 31)
        D1 = 30
    end
    if (D2 == 31)
        D2 = 30
    end
    return (360 * (Y2 - Y1) + 30 * (M2 - M1) + (D2 - D1)) / 360.00
end

struct Tenor
    tenorNumber::Float64
    tenorTime::String
end

function tenorDef(tenor::String)::Tenor
    numTen = length(tenor)
    typeofTenor = string(tenor[end])
    return Tenor(parse(Float64,tenor[1:numTen-1]),typeofTenor)
end

abstract type calendar end
struct cMXN <: calendar end
struct cUSD <: calendar end

abstract type shiftTimeTenor end
struct D <: shiftTimeTenor end
struct W <: shiftTimeTenor end
struct M <: shiftTimeTenor end
struct S <: shiftTimeTenor end
struct Y <: shiftTimeTenor end
struct Q <: shiftTimeTenor end

function kk(struct_name::AbstractString)
    invoke(eval(Symbol(struct_name)),Tuple{})
end

function addTenor(::D,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Day(a)
end
#Week
function addTenor(::W,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Week(a)
end
#Month
function addTenor(::M,::cUSD,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Month(a)
end
function addTenor(::M,::cMXN,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber * 28
    return fecha + Dates.Day(a)
end
#Quarter
function addTenor(::Q,::cUSD,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Month(3*a)
end
function addTenor(::Q,::cMXN,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber * 92
    return fecha + Dates.Day(a)
end
#SemiAnnual
function addTenor(::S,::cUSD,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Month(6*a)
end
function addTenor(::S,::cMXN,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber * 182
    return fecha + Dates.Day(a)
end
#Year
function addTenor(::Y,::cUSD,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber
    return fecha + Dates.Year(a)
end
function addTenor(::Y,::cMXN,fecha::Date,tenor::Tenor)::Date
    a = tenor.tenorNumber * 364
    return fecha + Dates.Day(a)
end

function addDays(dt1::Date,tenorTest::String,Calendar::String)::Date
    a = tenorDef(tenorTest)
    structTest = kk(a.tenorTime)
    if a.tenorTime == "D" || a.tenorTime == "W"
        return addTenor(structTest,dt1,a)
    else
        return addTenor(structTest,kk(Calendar),dt1,a)
    end
end


abstract type yieldConvention end

struct None <: yieldConvention end
struct Daily <: yieldConvention end
struct Weekly <: yieldConvention end
struct Monthly <: yieldConvention end
struct Quarterly <: yieldConvention end
struct SemiAnnual <: yieldConvention end
struct Annual <: yieldConvention end


function yieldConv(::None)::Float64
    return 1.0
end
function yieldConv(::Daily)::Float64
    return 1.0 / 360.0
end
function yieldConv(::Monthly)::Float64
    return 1.0 / 12.0
end
function yieldConv(::Quarterly)::Float64
    return 1.0 / 4.0
end
function yieldConv(::SemiAnnual)::Float64
    return 1.0 / 2.0
end
function yieldConv(::Annual)::Float64
    return 1.0 / 1.0
end
function yieldConv(::Monthly,::cMXN)::Float64
    return 28.0 / 360.0
end
function yieldConv(::Quarterly,::cMXN)::Float64
    return 91.0 / 360.0
end
function yieldConv(::SemiAnnual,::cMXN)::Float64
    return 182.0 / 360.0
end
function yieldConv(::Annual,::cMXN)::Float64
    return 364.0 / 360.0
end


function shiftDay(fecha::Date,::Daily,qty::Int64)::Date
    return fecha + Dates.Day(qty)
end
#Week
function shiftDay(fecha::Date,::Weekly,qty::Int64)::Date
    return fecha + Dates.Week(qty)
end
#Month
function shiftDay(fecha::Date,::Monthly,qty::Int64)::Date
    return fecha + Dates.Month(qty)
end
function shiftDay(fecha::Date,::Monthly,qty::Int64,::cMXN)::Date
    a = qty * 28
    return fecha + Dates.Day(a)
end
#quarter
function shiftDay(fecha::Date,::Quarterly,qty::Int64)::Date
    return fecha + Dates.Month(qty*3)

end
function shiftDay(fecha::Date,::Quarterly,qty::Int64,::cMXN)::Date
    a = qty * 28 * 3
    return fecha + Dates.Day(a)
end
#semiannual
function shiftDay(fecha::Date,::SemiAnnual,qty::Int64)::Date
    return fecha + Dates.Month(qty*6)

end
function shiftDay(fecha::Date,::SemiAnnual,qty::Int64,::cMXN)::Date
    a = qty * 182
    return fecha + Dates.Day(a)
end
#year
function shiftDay(fecha::Date,::Annual,qty::Int64)::Date
    return fecha + Dates.Year(qty)
end
function shiftDay(fecha::Date,::Annual,qty::Int64,::cMXN)::Date
    a = qty * 364
    return fecha + Dates.Day(a)
end
