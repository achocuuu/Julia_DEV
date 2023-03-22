using Dates
include("InstrumentDiscountFactor.jl")
include("timeFunctions.jl")


"""Gets the rate of a dataframe data"""
function getIndexRate(df::DataFrame,tenor::String)::Float64
    a = df[in.(df.tenor,Ref([tenor])) ,:mid]
    return length(a) == 0 ? 0 : a[1]
end

"""linear interpolation of rates"""
function lininterpol(days::Array{Int64},df::Array{Float64},plazo::Int64)::Float64

    npl = length(df)
    err = length(df) != length(days) ? error("Vectores no son del mismo tamaño") : 0


    if plazo >= days[npl]
        return df[npl]
    elseif plazo <= days[1]
        return df[1]
    elseif plazo < days[npl] && plazo > days[1]

        for i = 1:npl
            if days[i] == plazo
                #println("es igual")
                return df[i]
                #println(tasa)
                break
           elseif plazo <= days[i]
               #println("interpolar")
               return (plazo - days[i-1]) / (days[i] - days[i-1]) * df[i] + (days[i]-plazo)  / (days[i] - days[i-1]) *df[i-1]
               #println(tasa)
               break
           end
        end

    end

end



function loglininterpol(days::Array{Int64},df::Array{Float64},plazo::Int64)::Float64

        npl = length(df)
        err = length(df) != length(days) ? error("Vectores no son del mismo tamaño") : 0

        if plazo <= days[1]
            return df[1]
        elseif plazo < days[npl] && plazo > days[1]

            for i = 1:npl
                if days[i] == plazo
                    #println("es igual")
                    return df[i]
                    #println(tasa)
                    break
               elseif plazo <= days[i]
                   #println("interpolar")
                   return exp((log(df[i])-log(df[i-1]))/(days[i]-days[i-1]) *(plazo-days[i-1]) + log(df[i-1]))
                   #println(tasa)
                   break
               end
            end
        elseif plazo >= days[npl]
            return df[npl]
        end

end

# function fEvaluation(payments::Int64,flujo::Array{Float64},plazo::Array{Int64},dfactor::Array{Float64},plazoVector::Array{Int64},eval::Float64,indexDF::Int64)::Float64
#
#     dfFlow = Array{Float64,2}(undef,payments,1)
#     dfactor[indexDF] = eval
#     for i = 1:payments
#         dfFlow[i] = loglininterpol(plazo,dfactor,plazoVector[i])
#     end
#     return sum(transpose(flujo)*dfFlow)-1
#
# end
#
# function falsePosition(Bond::Instrument,payments::Int64,flujo::Array{Float64},plazo::Array{Int64},dfactor::Array{Float64},plazoVector::Array{Int64},indexDF::Int64)::Float64
#
# global a = 0.01
# global b = 1.0
#
#     while true
#         global a
#         global b
#         f_a = fEvaluation(payments,flujo,plazo,dfactor,plazoVector,a,indexDF)
#         f_b = fEvaluation(payments,flujo,plazo,dfactor,plazoVector,b,indexDF)
#         c = (b * f_a - a * f_b) / (f_a - f_b)
#         f_c = fEvaluation(payments,flujo,plazo,dfactor,plazoVector,c,indexDF)
#         f_c = round(f_c,digits=15)
#         if f_c == 0
#             return c
#             break
#         end
#         if f_a*f_c < 0
#             b = c
#         else
#             a = c
#         end
#     end
#
# end


function falsePosition(::Swap,dConvFL::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,paymentsFL::Int64,freqCountFL::yieldConvention,notional::Float64,dfactor::Array{Float64,2},plazo::Array{Int64,2},dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2},obj::Float64,indexDF::Int64)
    global a = 0.01
    global b = 1.0
    #for i =1:100000
    while true
        global a
        global b
        dfactor[indexDF] = a
        f_a = InstrumentFlow(Swap(),dConvFL,fechaProyeccion,fechaResta,fechaFin,paymentsFL,freqCountFL,notional,dfactor,plazo,dfDsct,plazoDsct)-obj
        dfactor[indexDF] = b
        f_b = InstrumentFlow(Swap(),dConvFL,fechaProyeccion,fechaResta,fechaFin,paymentsFL,freqCountFL,notional,dfactor,plazo,dfDsct,plazoDsct)-obj
        c = (b * f_a - a * f_b) / (f_a - f_b)
        dfactor[indexDF] = c
        f_c = InstrumentFlow(Swap(),dConvFL,fechaProyeccion,fechaResta,fechaFin,paymentsFL,freqCountFL,notional,dfactor,plazo,dfDsct,plazoDsct)-obj
        f_c = round(f_c,digits=14)
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

function falsePosition(::Bond,dConvFL::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,paymentsFL::Int64,freqCountFL::yieldConvention,notional::Float64,dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2},obj::Float64,indexDF::Int64)
    global a = 0.01
    global b = 1.0
    #for i =1:100000
    while true
        global a
        global b
        dfDsct[indexDF] = a
        f_a = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct)-obj
        dfDsct[indexDF] = b
        f_b = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct)-obj
        c = (b * f_a - a * f_b) / (f_a - f_b)
        dfDsct[indexDF] = c
        f_c = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct)-obj
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
#para calendario mexicano
function falsePosition(::Bond,dConvFL::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,paymentsFL::Int64,freqCountFL::yieldConvention,notional::Float64,dfDsct::Array{Float64,2},plazoDsct::Array{Int64,2},obj::Float64,indexDF::Int64,calendario::calendar)
    global a = 0.01
    global b = 1.0
    #for i =1:100000
    while true
        global a
        global b
        dfDsct[indexDF] = a
        f_a = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct,calendario)-obj
        dfDsct[indexDF] = b
        f_b = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct,calendario)-obj
        c = (b * f_a - a * f_b) / (f_a - f_b)
        dfDsct[indexDF] = c
        f_c = InstrumentFlow(Bond(),dConvFL,fechaProyeccion,fechaResta,fechaFin,Rate,paymentsFL,freqCountFL,notional,dfDsct,plazoDsct,calendario)-obj
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


function getFutureDate(ano::Int64,mes::Int64)
    t = Date(ano,mes,01)
    a =Dates.firstdayofweek.(t+Dates.Week.(collect(1:4)))+Dates.Day(2)
    b = Dates.dayofweekofmonth.(Dates.firstdayofweek.(t+Dates.Week.(collect(1:4)))+Dates.Day(2))
    index = minimum(findall(x->x==3, b)[:])
    return a[index]
end

function futureDates(t::Date,qty::Int64)
    fechasFuture = Array{Date,2}(undef,qty,2)
    ano, mes = Dates.yearmonth(Dates.lastdayofquarter(t))
    fechasFuture[1,1] = getFutureDate(ano,mes)
    for i = 1:qty
        ano =Dates.yearmonth(firstdayofmonth(Dates.lastdayofquarter(t))+Dates.Month(3*i))[1]
        mes = Dates.yearmonth(firstdayofmonth(Dates.lastdayofquarter(t))+Dates.Month(3*i))[2]
        fechasFuture[i,2] = getFutureDate(ano,mes)
    end
    fechasFuture[2:end,1] = fechasFuture[1:end-1,2]
    return fechasFuture
end

function payments(::SemiAnnual,fechaIni::Date,fechaFin::Date)
    paymentComposition = SemiAnnual()
    yearDiff =  Dates.value(Dates.Year(fechaFin)-Dates.Year(fechaIni))
    monthDiff = Dates.value(Dates.Month(fechaFin)-Dates.Month(fechaIni))
    dayDiff = Dates.value(Dates.Day(fechaFin)-Dates.Day(fechaIni))
    paymentsInYear = convert(Int64,round(1 / yieldConv(paymentComposition), digits=0))
    return paymentsInYear * yearDiff + convert(Int64,ceil(monthDiff / 6.00, digits=0))

end

function payments(::Monthly,fechaIni::Date,fechaFin::Date)
    paymentComposition = Monthly()
    yearDiff =  Dates.value(Dates.Year(fechaFin)-Dates.Year(fechaIni))
    monthDiff = Dates.value(Dates.Month(fechaFin)-Dates.Month(fechaIni))
    dayDiff = Dates.value(Dates.Day(fechaFin)-Dates.Day(fechaIni))
    paymentsInYear = convert(Int64,round(1 / yieldConv(paymentComposition), digits=0))
    return paymentsInYear * yearDiff + monthDiff

end

function payments(::Quarterly,fechaIni::Date,fechaFin::Date)
    paymentComposition = Quarterly()
    yearDiff =  Dates.value(Dates.Year(fechaFin)-Dates.Year(fechaIni))
    monthDiff = Dates.value(Dates.Month(fechaFin)-Dates.Month(fechaIni))
    dayDiff = Dates.value(Dates.Day(fechaFin)-Dates.Day(fechaIni))
    paymentsInYear = convert(Int64,round(1 / yieldConv(paymentComposition), digits=0))
    return paymentsInYear * yearDiff + convert(Int64,round(monthDiff / 4.00, digits=0))
end

function payments(::Annual,fechaIni::Date,fechaFin::Date)
    paymentComposition = Annual()
    yearDiff =  Dates.value(Dates.Year(fechaFin)-Dates.Year(fechaIni))
    monthDiff = Dates.value(Dates.Month(fechaFin)-Dates.Month(fechaIni))
    dayDiff = Dates.value(Dates.Day(fechaFin)-Dates.Day(fechaIni))
    paymentsInYear = convert(Int64,round(1 / yieldConv(paymentComposition), digits=0))
    extraMonths = monthDiff * yieldConv(Monthly())
    return paymentsInYear * yearDiff + convert(Int64,ceil(extraMonths))
end
