using Dates

"""Calculates the discount factor given a rate,
year fraction and type of convention for the discount factor"""
function discountFactor(rate, yf, tipo)
    if tipo == "Linear"
        1/(1+rate*yf)
    elseif tipo == "Compound"
        1/(1+rate)^(yf)
    elseif tipo == "Continuous"
        exp(-rate*yf)
    end
end

"""Gets the rate of a dataframe data"""
function getIndexRate(df::DataFrame,tenor::String)::Float64
    a = df[in.(df.tenor,Ref([tenor])) ,:mid]
    return length(a) == 0 ? 0 : a[1]
end

"""linear interpolation of rates"""
function lininterpol(curve, plazo)

    npl = length(curve.df)

    if plazo >= curve.days[npl]
        return curve.df[npl]
    elseif plazo <= curve.days[1]
        return curve.df[1]
    elseif plazo < curve.days[npl] && plazo > curve.days[1]

        for i = 1:npl
            if curve.days[i] == plazo
                #println("es igual")
                return curve.df[i]
                #println(tasa)
                break
           elseif plazo <= curve.days[i]
               #println("interpolar")
               return (plazo - curve.days[i-1]) / (curve.days[i] - curve.days[i-1]) * curve.df[i] + (curve.days[i]-plazo)  / (curve.days[i] - curve.days[i-1]) *curve.df[i-1]
               #println(tasa)
               break
           end
        end

    end

end

"""log linear interpolation of rates"""
function loglininterpol(curve, plazo)

    npl = length(curve.df)

    if plazo >= curve.days[npl]
        return curve.df[npl]
    elseif plazo <= curve.days[1]
        return curve.df[1]
    elseif plazo < curve.days[npl] && plazo > curve.days[1]

        for i = 1:npl
            if curve.days[i] == plazo
                #println("es igual")
                return curve.df[i]
                #println(tasa)
                break
           elseif plazo <= curve.days[i]
               #println("interpolar")
               return exp((log(curve.df[i])-log(curve.df[i-1]))/(curve.days[i]-curve.days[i-1]) *(plazo-curve.days[i-1]) + log(curve.df[i-1]))
               #println(tasa)
               break
           end
        end

    end
end






function fEvaluation(curve,tenorSwap,flow,variable,payments)
    curve[(curve[:tenor] .== tenorSwap),:df]=variable
    for i = 1:payments
        flow[i,4] = loglininterpol(curve,flow[i,1])
    end
    #function: (eval)
    transpose(flow[:,4])*flow[:,5]-1
end

"Secant method (false position) given initial values a and b"
function falsePosition(curve, tenorSwap, flow, payments)

global a = 0.01
global b = 1
    while true
        global a
        global b
        f_a = fEvaluation(curve, tenorSwap, flow, a, payments)
        f_b = fEvaluation(curve, tenorSwap, flow, b, payments)
        c = (b * f_a - a * f_b) / (f_a - f_b)
        f_c = fEvaluation(curve, tenorSwap, flow, c, payments)
        f_c = round(f_c,digits=15)
        if f_c == 0

            return c
            break

        end
        if f_a*f_c < 0
            b = c
        else
            a = c
        end
    end

end
"""Calculates the fixed flow, using the swap rate determined by the mkt"""
function fixFlow(curve,paysInYear,fechaTN,periodicidadMensual,tenorSwap, rates)

    fixRate = getIndexRate(rates, tenorSwap)
    payments = convert(Int, ceil(tenorMonths(tenorSwap) / 12) * paysInYear)
    fechasFlow = Array{Date,2}(undef, payments, 2)
    flow = Array{Float64,2}(undef, payments, 5)

    #volver a aca cuando actualizce

    for i = 1:payments
        fechasFlow[i, 1] = i == 1 ? fechaTN : fechasFlow[i-1, 2]
        meses = periodicidadMensual * i
        if i == payments && convert(Int,tenorMonths(tenorSwap)) < meses
            meses = convert(Int,tenorMonths(tenorSwap))
        end
        fechasFlow[i, 2] = shiftDate((fechaTN + Dates.Month(meses)))
        yfc = (fechasFlow[i, 2] - fechasFlow[i, 1]).value / 360
        yf = (fechasFlow[i, 2] - fechaTN).value / 360
        dtm = (fechasFlow[i, 2] - fechaTN).value
        flujo = i == payments ? notional + fixRate * yfc * notional :
                fixRate * yfc * notional
        df = loglininterpol(curve, dtm)
        flow[i, 1] = dtm
        flow[i, 2] = yfc
        flow[i, 3] = yf
        flow[i, 4] = df
        flow[i, 5] = flujo

    end
return flow
end

"""Calculates the float flow using diferent curves for discount or for fwd rates (it could be the same, depending on the market conventions of the curve)"""
function floatFlow(curveDsct,curveFwd,paysInYear,fechaTN,periodicidadMensual,tenorSwap, rates)

    payments = convert(Int, tenorMonths(tenorSwap) / 12 * paysInYear)
    fechasFlow = Array{Date,2}(undef, payments, 2)
    flow = Array{Float64,2}(undef, payments, 5)
    #volver a aca cuando actualizce
    for i = 1:payments
        fechasFlow[i, 1] = i == 1 ? fechaTN : fechasFlow[i-1, 2]
        meses = periodicidadMensual * i
        if i == payments && convert(Int,tenorMonths(tenorSwap)) < meses
            meses = convert(Int,tenorMonths(tenorSwap))
        end
        fechasFlow[i, 2] = shiftDate((fechaTN + Dates.Month(meses)))
        yfc = (fechasFlow[i, 2] - fechasFlow[i, 1]).value / 360
        yf = (fechasFlow[i, 2] - fechaTN).value / 360
        dtm = (fechasFlow[i, 2] - fechaTN).value
        df_ini = i == 1 ? 1 : loglininterpol(curveFwd, flow[i-1,1])
        df = loglininterpol(curveDsct, dtm)
        df_fin = loglininterpol(curveFwd, dtm)#df #Si hay otra curva, generar otra curva
        floatRate = (df_ini / df_fin - 1) * 1 / yfc
        flujo = i == payments ? notional + floatRate * yfc * notional : floatRate * yfc * notional
        flow[i, 1] = dtm
        flow[i, 2] = yfc
        flow[i, 3] = yf
        flow[i, 4] = df
        flow[i, 5] = flujo

    end
return flow
end

"""Initial curve construction"""
function curveInit(dataCurve, fechaHoy, fechaON, fechaTN)

    n = length(dataCurve[:, 1])
    #Inicialicacion de curva
    curva = DataFrame()
    curva.tenor = dataCurve.tenor[:]
    curva.tipo = dataCurve.mktDesc[:]
    curva.startdate = fechaHoy
    curva.endDate = fechaHoy
    curva.days = 0
    curva.yf = 0.0
    curva.df = 0.0
    #ON
    curva.startdate[1] = fechaHoy
    curva.endDate[1] = fechaON
    curva.days[1] = (fechaON - fechaHoy).value
    curva.yf[1] = curva.days[1] / 360
    curva.df[1] = 1 / (1 + getIndexRate(rates, "ON") * curva.yf[1])

    if fechaTN > fechaHoy
        #settlement
        curva.startdate[2] = fechaON
        curva.endDate[2] = fechaTN
        curva.days[2] = (fechaTN - fechaHoy).value
        curva.yf[2] = curva.days[2] / 360
        curva.df[2] = 1 / (1 + getIndexRate(rates, "ON") * curva.yf[2])
        #resto de la curva
        curva.startdate[3:end] .= fechaTN
        #i = 3
        for i = 3:n
            tn = curva.tenor[i]
            meses = convert(Int32, tenorMonths(tn))
            dias = string(tn[end]) == "W" ? (shiftDate((fechaTN + Dates.Week(meses))) - fechaTN).value : (shiftDate((fechaTN + Dates.Month(meses))) - fechaTN).value
            tasa = getIndexRate(rates, tn)
            curva.endDate[i] = shiftDate((fechaTN + Dates.Month(meses)))
            curva.days[i] = dias
            curva.yf[i] = curva.days[i] / 360
            curva.df[i] = curva.tipo[i] == "Cash Rate" ? 1 / (1 + tasa * curva.yf[i]) : 1.00
        end
    else
        curva.startdate[2:end] .= fechaHoy
        #i = 3
        for i = 2:n
            tn = curva.tenor[i]
            meses = convert(Int32, tenorMonths(tn))
            dias = string(tn[end]) == "W" ? (shiftDate((fechaTN + Dates.Week(meses))) - fechaTN).value : (shiftDate((fechaTN + Dates.Month(meses))) - fechaTN).value
            tasa = getIndexRate(rates, tn)
            curva.endDate[i] = shiftDate((fechaTN + Dates.Month(meses)))
            curva.days[i] = dias
            curva.yf[i] = curva.days[i] / 360
            curva.df[i] = curva.tipo[i] == "Cash Rate" ? 1 / (1 + tasa * curva.yf[i]) : 1.00
        end
    end
    return curva
end

"""Generates the final curve, for those who got a settlement date"""
function curveFinal(dataCurve, fechaHoy, fechaON, fechaTN)

    n = length(dataCurve[:, 1])
    #Inicialicacion de curva
    curva = DataFrame()
    curva.tenor = dataCurve.tenor[:]
    curva.tipo = dataCurve.mktDesc[:]
    curva.startdate = fechaHoy
    curva.endDate = fechaHoy
    curva.days = 0
    curva.yf = 0.0
    curva.df = 0.0
    #ON
    curva.startdate[1] = fechaHoy
    curva.endDate[1] = fechaON
    curva.days[1] = (fechaON - fechaHoy).value
    curva.yf[1] = curva.days[1] / 360
    curva.df[1] = 1 / (1 + getIndexRate(rates, "ON") * curva.yf[1])

    if fechaTN > fechaHoy
        println("Hay fecha TN")
        #settlement
        curva.startdate[2] = fechaHoy
        curva.endDate[2] = fechaTN
        curva.days[2] = (fechaTN - fechaHoy).value
        curva.yf[2] = curva.days[2] / 360
        curva.df[2] = 1 / (1 + getIndexRate(rates, "ON") * curva.yf[2])
        #resto de la curva
        curva.startdate[3:end] .= fechaHoy
        #i = 3
        for i = 3:n
            tn = curva.tenor[i]
            meses = convert(Int32, tenorMonths(tn))
            dias = string(tn[end]) == "W" ? (shiftDate((fechaTN + Dates.Week(meses))) - fechaHoy).value : (shiftDate((fechaTN + Dates.Month(meses))) - fechaHoy).value
            tasa = getIndexRate(rates, tn)
            curva.endDate[i] = shiftDate((fechaTN + Dates.Month(meses)))
            curva.days[i] = dias
            curva.yf[i] = curva.days[i] / 360
            curva.df[i] = curva.tipo[i] == "Cash Rate" ? 1 / (1 + tasa * curva.yf[i]) : 1.00
        end
    else
        curva.startdate[2:end] .= fechaHoy
        #i = 3
        println("No hay fecha TN")
        for i = 2:n
            tn = curva.tenor[i]
            meses = convert(Int32, tenorMonths(tn))
            dias = string(tn[end]) == "W" ? (shiftDate((fechaTN + Dates.Week(meses))) - fechaHoy).value : (shiftDate((fechaTN + Dates.Month(meses))) - fechaHoy).value
            tasa = getIndexRate(rates, tn)
            curva.endDate[i] = shiftDate((fechaTN + Dates.Month(meses)))
            curva.days[i] = dias
            curva.yf[i] = curva.days[i] / 360
            curva.df[i] = curva.tipo[i] == "Cash Rate" ? 1 / (1 + tasa * curva.yf[i]) : 1.00
        end
    end
    return curva
end
