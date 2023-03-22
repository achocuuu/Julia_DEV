include("timeFunctions.jl")
include("timeFunc.jl")
using Dates
abstract type Instrument end

struct OverNight <: Instrument end
struct Cash <: Instrument end
struct Bond <: Instrument end
struct Swap <: Instrument end
struct Future <: Instrument end

function dfInstrument(::OverNight,dCountConv::DayCountConv,dfConvention::discountFactor2,fechaIni::Date,fechaFin::Date,Rate::Float64)
    yf = dayCountFactor(dCountConv,fechaIni,fechaFin)
    return df(dfConvention,yf,Rate)

end
function dfInstrument(::Cash,dCountConv::DayCountConv,dfConvention::discountFactor2,fechaIni::Date,fechaFin::Date,Rate::Float64)
    yf = dayCountFactor(dCountConv,fechaIni,fechaFin)
    return df(dfConvention,yf,Rate)
end
function dfInstrument(::Future,dCountConv::DayCountConv,dfConvention::discountFactor2,fechaIni::Date,fechaFin::Date,Rate::Float64)
    yf = dayCountFactor(dCountConv,fechaIni,fechaFin)
    return df(dfConvention,yf,Rate)
end
function InstrumentFlow(::Bond,dCountConv::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,payments::Int64,paymentFreq::yieldConvention,notional::Float64)
    fechasIni = Array{Date,2}(undef,payments,1)
    fechasFin = Array{Date,2}(undef,payments,1)
    flujo = Array{Float64,2}(undef,payments,1)
    fechasIni[1] = fechaProyeccion
    for i = 1:payments-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,paymentFreq,i))
        fechasIni[i+1] = fechasFin[i]
        flujo[i] = notional * Rate * dayCountFactor(dCountConv,fechasIni[i],fechasFin[i])
    end
    fechasFin[payments] = shiftDate(fechaFin)
    flujo[payments] = notional + notional * Rate * dayCountFactor(dCountConv,fechasIni[payments],fechasFin[payments])
    plazoVector = Dates.value.(fechasFin[:] - fechaResta)

    return plazoVector, flujo
end
#con calendario mexicano
function InstrumentFlow(::Bond,dCountConv::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,payments::Int64,paymentFreq::yieldConvention,notional::Float64,calendario::calendar)
    fechasIni = Array{Date,2}(undef,payments,1)
    fechasFin = Array{Date,2}(undef,payments,1)
    flujo = Array{Float64,2}(undef,payments,1)
    fechasIni[1] = fechaProyeccion
    for i = 1:payments-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,paymentFreq,i,calendario))
        fechasIni[i+1] = fechasFin[i]
        flujo[i] = notional * Rate * dayCountFactor(dCountConv,fechasIni[i],fechasFin[i])
    end
    fechasFin[payments] = shiftDate(fechaFin)
    flujo[payments] = notional + notional * Rate * dayCountFactor(dCountConv,fechasIni[payments],fechasFin[payments])
    plazoVector = Dates.value.(fechasFin[:] - fechaResta)

    return plazoVector, flujo
end

function InstrumentFlow(::Bond,dCountConv::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,payments::Int64,paymentFreq::yieldConvention,notional::Float64,dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2})
    fechasIni = Array{Date,2}(undef,payments,1)
    fechasFin = Array{Date,2}(undef,payments,1)
    flujo = Array{Float64,2}(undef,payments,1)
    fechasIni[1] = fechaProyeccion
    for i = 1:payments-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,paymentFreq,i))
        fechasIni[i+1] = fechasFin[i]
        plazo = Dates.value(fechasFin[i] - fechaResta)
        flujo[i] = notional * Rate * dayCountFactor(dCountConv,fechasIni[i],fechasFin[i]) * loglininterpol(plazoDsct,dfDsct,plazo)
    end
    fechasFin[payments] = shiftDate(fechaFin)
    plazoVector = Dates.value.(fechasFin[:] - fechaResta)
    flujo[payments] = (notional + notional * Rate * dayCountFactor(dCountConv,fechasIni[payments],fechasFin[payments])) * loglininterpol(plazoDsct,dfDsct,plazoVector[payments])
    return sum(flujo)
end
#con calendario mexicano
function InstrumentFlow(::Bond,dCountConv::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,payments::Int64,paymentFreq::yieldConvention,notional::Float64,dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2},calendario::calendar)
    fechasIni = Array{Date,2}(undef,payments,1)
    fechasFin = Array{Date,2}(undef,payments,1)
    flujo = Array{Float64,2}(undef,payments,1)
    fechasIni[1] = fechaProyeccion
    for i = 1:payments-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,paymentFreq,i,calendario))
        fechasIni[i+1] = fechasFin[i]
        plazo = Dates.value(fechasFin[i] - fechaResta)
        flujo[i] = notional * Rate * dayCountFactor(dCountConv,fechasIni[i],fechasFin[i]) * loglininterpol(plazoDsct,dfDsct,plazo)
    end
    fechasFin[payments] = shiftDate(fechaFin)
    plazoVector = Dates.value.(fechasFin[:] - fechaResta)
    flujo[payments] = (notional + notional * Rate * dayCountFactor(dCountConv,fechasIni[payments],fechasFin[payments])) * loglininterpol(plazoDsct,dfDsct,plazoVector[payments])
    return sum(flujo)
end



function InstrumentFlow(::Swap,dConvFL::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,paymentsFL::Int64,freqCountFL::yieldConvention,notional::Float64,dfactor::Array{Float64,2},plazo::Array{Int64,2})
    fechasIni = Array{Date,2}(undef,paymentsFL,1)
    fechasFin = Array{Date,2}(undef,paymentsFL,1)
    flujo = Array{Float64,2}(undef,paymentsFL,1)
    plazoVectorIni = Array{Int64,2}(undef,paymentsFL,1)
    plazoVectorFin = Array{Int64,2}(undef,paymentsFL,1)
    fechasIni[1] = fechaProyeccion
    plazoVectorIni[1] = Dates.value(fechaProyeccion-fechaResta)
    for i = 1:paymentsFL-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,freqCountFL,i))
        fechasIni[i+1] = fechasFin[i]
        plazoVectorFin[i] = Dates.value(fechasFin[i]-fechaResta)
        plazoVectorIni[i+1] = plazoVectorFin[i]
        df1 = loglininterpol(plazo,dfactor,plazoVectorIni[i])
        df2 = loglininterpol(plazo,dfactor,plazoVectorFin[i])
        Rate = (df1/df2 -1 ) * 1 / dayCountFactor(dConvFL,fechasIni[i],fechasFin[i])
        flujo[i] = notional * Rate * dayCountFactor(dConvFL,fechasIni[i],fechasFin[i])
    end
    fechasFin[paymentsFL] = shiftDate(fechaFin)
    plazoVectorFin[paymentsFL] = Dates.value(fechasFin[paymentsFL]-fechaResta)
    df1 = loglininterpol(plazo,dfactor,plazoVectorIni[paymentsFL])
    df2 = loglininterpol(plazo,dfactor,plazoVectorFin[paymentsFL])
    Rate = (df1/df2 -1 ) * 1 / dayCountFactor(dConvFL,fechasIni[paymentsFL],fechasFin[paymentsFL])
    flujo[paymentsFL] = notional + notional * Rate * dayCountFactor(dConvFL,fechasIni[paymentsFL],fechasFin[paymentsFL])
    return plazoVectorFin, flujo
end

function InstrumentFlow(::Swap,dConvFL::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,paymentsFL::Int64,freqCountFL::yieldConvention,notional::Float64,dfactor::Array{Float64,2},plazo::Array{Int64,2},dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2})
    fechasIni = Array{Date,2}(undef,paymentsFL,1)
    fechasFin = Array{Date,2}(undef,paymentsFL,1)
    flujo = Array{Float64,2}(undef,paymentsFL,1)
    plazoVectorIni = Array{Int64,2}(undef,paymentsFL,1)
    plazoVectorFin = Array{Int64,2}(undef,paymentsFL,1)
    fechasIni[1] = fechaProyeccion
    plazoVectorIni[1] = Dates.value(fechaProyeccion-fechaResta)
    for i = 1:paymentsFL-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,freqCountFL,i))
        fechasIni[i+1] = fechasFin[i]
        plazoVectorFin[i] = Dates.value(fechasFin[i]-fechaResta)
        plazoVectorIni[i+1] = plazoVectorFin[i]
        df1 = loglininterpol(plazo,dfactor,plazoVectorIni[i])
        df2 = loglininterpol(plazo,dfactor,plazoVectorFin[i])
        Rate = (df1/df2 -1 ) * 1 / dayCountFactor(dConvFL,fechasIni[i],fechasFin[i])
        flujo[i] = notional * Rate * dayCountFactor(dConvFL,fechasIni[i],fechasFin[i]) * loglininterpol(plazoDsct,dfDsct,plazoVectorFin[i])
    end
    fechasFin[paymentsFL] = shiftDate(fechaFin)
    plazoVectorFin[paymentsFL] = Dates.value(fechasFin[paymentsFL]-fechaResta)
    df1 = loglininterpol(plazo,dfactor,plazoVectorIni[paymentsFL])
    df2 = loglininterpol(plazo,dfactor,plazoVectorFin[paymentsFL])
    Rate = (df1/df2 -1 ) * 1 / dayCountFactor(dConvFL,fechasIni[paymentsFL],fechasFin[paymentsFL])
    flujo[paymentsFL] = (notional + notional * Rate * dayCountFactor(dConvFL,fechasIni[paymentsFL],fechasFin[paymentsFL]))* loglininterpol(plazoDsct,dfDsct,plazoVectorFin[paymentsFL])
    return sum(flujo)
end
#Para instrumentos en mexico, hacer flujos de manera recursiva
