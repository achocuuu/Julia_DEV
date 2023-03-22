include("InstrumentDiscountFactor.jl")
include("timeFunctions.jl")
abstract type Curve end

struct spotCurve <: Curve end
struct zeroCurve <: Curve end

function shortCurve(::spotCurve,rates::DataFrame,fechaHoy::Date,fechaON::Date,fechaTN::Date,fechas::Array{Date,2},plazo::Array{Int64,2},dfactor::Array{Float64,2},dConv::DayCountConv,dfComp::discountFactor2)
    stIdx = minimum(findall(x->x=="OverNight", rates.typeRate)[:])
    endIdx = maximum(findall(x->x=="OverNight", rates.typeRate)[:])
    fechas[1,1] = fechaHoy
    fechas[1,2] = fechaON
    fechas[2,1] = fechaON
    fechas[2,2] = fechaTN #Starting date
    plazo[1] = Dates.value(fechaON-fechaHoy)
    plazo[2] = Dates.value(fechaTN-fechaHoy)
    dfactor[1] = dfInstrument(kk(rates.typeRate[1]),dConv,dfComp,fechas[1,1],fechas[1,2],rates.mid[1])
    dfactor[2] = dfInstrument(kk(rates.typeRate[2]),dConv,dfComp,fechas[2,1],fechas[2,2],rates.mid[2]) * dfactor[1]
    return fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx]
end

function shortCurve(::zeroCurve,rates::DataFrame,fechaHoy::Date,fechaON::Date,fechas::Array{Date,2},plazo::Array{Int64,2},dfactor::Array{Float64,2},dConv::DayCountConv,dfComp::discountFactor2)
    stIdx = minimum(findall(x->x=="OverNight", rates.typeRate)[:])
    endIdx = maximum(findall(x->x=="OverNight", rates.typeRate)[:])
    fechas[1,1] = fechaHoy
    fechas[1,2] = fechaON
    plazo[1] = Dates.value(fechaON-fechaHoy)
    dfactor[1] = dfInstrument(kk(rates.typeRate[1]),dConv,dfComp,fechas[1,1],fechas[1,2],rates.mid[1])
    return fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx]
end

function midCurve(::Cash,rates::DataFrame,fechaProyeccion::Date,fechaResta::Date,fechas::Array{Date,2},plazo::Array{Int64,2},dfactor::Array{Float64,2},calendario::String,dConv::Array{Any,2},dfComp::Array{Any,2})
    stIdx = minimum(findall(x->x=="Cash", rates.typeRate)[:])
    endIdx = maximum(findall(x->x=="Cash", rates.typeRate)[:])
    fechas[stIdx:endIdx,1] .= fechaProyeccion
    fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaProyeccion,rates.tenor[stIdx:endIdx],calendario))
    plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaResta)
    dfactor[stIdx:endIdx] = dfInstrument.(kk.(rates.typeRate[stIdx:endIdx]),dConv,dfComp,fechas[stIdx:endIdx,1],fechas[stIdx:endIdx,2],rates.mid[stIdx:endIdx])
    return fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx]
end

function midCurve(::Future,rates::DataFrame,fechaHoy::Date,fechaResta::Date,fechas::Array{Date,2},plazo::Array{Int64,2},dfactor::Array{Float64,2},calendario::String,dConv::Array{Any,2},dfComp::Array{Any,2})
    stIdx = minimum(findall(x->x=="Future", rates.typeRate)[:])
    endIdx = maximum(findall(x->x=="Future", rates.typeRate)[:])
    fechas[stIdx:endIdx,:] = futureDates(fechaHoy,qtyFuturesIdx)
    plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaResta)
    dfactor[stIdx:endIdx] = dfInstrument.(kk.(rates.typeRate[stIdx:endIdx]),dConv,dfComp,fechas[stIdx:endIdx,1],fechas[stIdx:endIdx,2],rates.mid[stIdx:endIdx])
    return fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx]
end



function longCurve(::spotCurve,::Bond,rates::DataFrame,fechaProyeccion::Date,fechaResta::Date,fechas::Array{Date,2},plazo::Array{Int64,2},dfactor::Array{Float64,2},calendario::String,dayCountConvention::DayCountConv,freqConvention::yieldConvention)
    stIdx = minimum(findall(x->x=="Bond", rates.typeRate)[:])
    endIdx = maximum(findall(x->x=="Bond", rates.typeRate)[:])
    fechas[stIdx:endIdx,1] .= fechaProyeccion
    fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaProyeccion,rates.tenor[stIdx:endIdx],calendario))
    plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaResta)
    tenorsBoots = rates[in.(rates.typeRate, Ref(["Bond"])), :tenor] |> Array
    for i=1:length(tenorsBoots) #tratamiento swap como bono
    # i = 5
        tenorString = tenorsBoots[i]
        tenorData = tenorDef(tenorString)
        fechaFin = shiftDate(addDays(fechaProyeccion,tenorString,calendario))
        tasa = getIndexRate(rates,tenorString)
        payments = convert(Int,ceil(Dates.value(shiftDate(addDays(fechaProyeccion,tenorString,calendario))-fechaResta)/Dates.value(shiftDate(addDays(fechaProyeccion,paymentFreq,calendario))-fechaResta)))
        plazoVector, flujo = InstrumentFlow(Bond(),dayCountConvention,fechaProyeccion,fechaFin,tasa,payments,freqConvention,notional)
        indexDF = findall(x->x==plazoVector[payments], plazo)[1][1]
        dfactor[indexDF] = falsePosition(payments,flujo,plazo,dfactor,plazoVector,indexDF)
    end
    return fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx]
end
