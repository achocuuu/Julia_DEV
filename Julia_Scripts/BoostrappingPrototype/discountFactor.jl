
abstract type discountFactor2 end
struct Linear <: discountFactor2 end
struct Compound <: discountFactor2 end
struct Continuous <: discountFactor2 end

function df(::Linear, yf::Float64, rate::Float64)::Float64
        return 1/(1+rate*yf)
end
function df(::Compound, yf::Float64, rate::Float64)::Float64
        return 1/(1+rate)^(yf)
end
function df(::Continuous, yf::Float64, rate::Float64)::Float64
        return exp(-rate*yf)
end
