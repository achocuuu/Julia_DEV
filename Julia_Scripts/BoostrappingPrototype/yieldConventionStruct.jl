abstract type yieldConvention end

struct None <: yieldConvention end
struct Daily <: yieldConvention end
struct Monthly <: yieldConvention end
struct Quarterly <: yieldConvention end
struct SemiAnnual <: yieldConvention end
struct Annual <: yieldConvention end
struct DailyMXN <: yieldConvention end
struct MonthlyMXN <: yieldConvention end
struct QuarterlyMXN <: yieldConvention end
struct SemiAnnualMXN <: yieldConvention end
struct AnnualMXN <: yieldConvention end

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
function yieldConv(::MonthlyMXN)::Float64
    return 28.0 / 360.0
end
function yieldConv(::QuarterlyMXN)::Float64
    return 91.0 / 360.0
end
function yieldConv(::SemiAnnualMXN)::Float64
    return 182.0 / 360.0
end
function yieldConv(::AnnualMXN)::Float64
    return 364.0 / 360.0
end
