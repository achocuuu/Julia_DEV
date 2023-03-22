using CSV
using Dates
using DataFrames
using DataFramesMeta
using SQLite
using XLSX
include("timeFunc.jl")
include("timeFunctions.jl")
include("discountFactor.jl")
include("functionAux.jl")
include("curveFunctions.jl")
include("InstrumentDiscountFactor.jl")
include("curvas.jl")
##################################load Data#############################################
#Tasas:
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\Datos\\bidaskLibor3M_20200527.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor,:typeRate ,:mid]), names(dataMktRate))]
rates.mid = rates.mid /100
#tasas OIS
pathOIS = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\Datos\\bidaskOIS_20200527.csv"
dataMktRateOIS = CSV.read(pathOIS)
ratesOIS = dataMktRateOIS[:, filter(x -> (x in [:tenor,:typeRate ,:mid]), names(dataMktRateOIS))]
ratesOIS.mid = ratesOIS.mid / 100

# path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\OISCurve.csv"
# OISCurve = CSV.read(path)
# dsctCurve = OISCurve[:, filter(x -> (x in [:df]), names(OISCurve))] |> Array
# plazoDsct = OISCurve[:, filter(x -> (x in [:plazo]), names(OISCurve))] |> Array

print(futureDates(Dates.Date(2020,05,19),6))

#Definiciones/Datos
fechaStrHoy = "20200527"
notional = 1.0
n = length(rates[:, 1])
settlementDays = 2
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(1))
fechaTN = shiftDate(fechaON + Dates.Day(settlementDays - 1))
calendario = "cUSD"
paymentFreq = "1Y"

plazoDsct, dsctCurve = curvaOIS(fechaHoy,fechaON,fechaTN,ratesOIS,1.0)

#Inicializacion de arreglos el total se separa
fechas = Array{Date,2}(undef, n, 2)
plazo = Array{Int64,2}(undef, n, 1)
dfactor = Array{Float64,2}(undef, n, 1)
dfactor[1:end] .= 1.0
#Short Curve OverNight
stIdx = minimum(findall(x->x=="OverNight", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="OverNight", rates.typeRate)[:])
dConvention = ACT360()
dfCompounding = Linear()
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = shortCurve(spotCurve(),rates,fechaHoy,fechaON,fechaTN,fechas,plazo,dfactor,dConvention,dfCompounding)

#mid Curve cash
stIdx = minimum(findall(x->x=="Cash", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Cash", rates.typeRate)[:])
dConvention = Array{Any,2}(undef,endIdx-stIdx+1,1)
dConvention .= ACT360.()
dfCompounding = Array{Any,2}(undef,endIdx-stIdx+1,1)
dfCompounding .= Linear.()
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = midCurve(Cash(),rates,fechaTN,fechaHoy,fechas,plazo,dfactor,calendario,dConvention,dfCompounding)
dfactor[stIdx] =  dfactor[stIdx] * dfactor[2]

#mid curve Futures
stIdx = minimum(findall(x->x=="Future", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Future", rates.typeRate)[:])
qtyFuturesIdx = endIdx-stIdx+1
dConvention = Array{Any,2}(undef,endIdx-stIdx+1,1)
dConvention .= ACT360.()
dfCompounding = Array{Any,2}(undef,endIdx-stIdx+1,1)
dfCompounding .= Linear.()
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = midCurve(Future(),rates,fechaHoy,fechaHoy,fechas,plazo,dfactor,calendario,dConvention,dfCompounding)
dfactor[stIdx] =  dfactor[stIdx] * loglininterpol(plazo[1:stIdx-1],dfactor[1:stIdx-1],Dates.value(fechas[stIdx,1]-fechaHoy))
for i=stIdx+1:endIdx
    dfactor[i] = dfactor[i]*dfactor[i-1]
end

#Calculo de flujos (Boostrapp)

stIdx = minimum(findall(x->x=="Swap", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Swap", rates.typeRate)[:])
dConvFL = ACT360()
freqCountFL =Quarterly()
dConvFX = dc30360()
freqCountFX = SemiAnnual()
paymentFreqFL = "1Q"
paymentFreqFX = "1S"
#fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = longCurve(spotCurve(),Bond(),rates,fechaTN,fechas,plazo,dfactor,calendario,dConv,freqCount)
fechas[stIdx:endIdx,1] .= fechaTN
fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaTN,rates.tenor[stIdx:endIdx],calendario))
plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaHoy)
tenorsBoots = rates[in.(rates.typeRate, Ref(["Swap"])), :tenor] |> Array
#for i=1:length(tenorsBoots) #tratamiento swap como bono
i=1
tenorString = tenorsBoots[i]
tenorData = tenorDef(tenorString)
fechaFin = shiftDate(addDays(fechaTN,tenorString,calendario))
tasa = getIndexRate(rates,tenorString)
paymentsFX = payments(SemiAnnual(),fechaHoy,fechaFin)
paymentsFL = payments(Quarterly(),fechaHoy,fechaFin)
plazoFix, fixFlow = InstrumentFlow(Bond(),dConvFX,fechaTN,fechaHoy,fechaFin,tasa,paymentsFX,freqCountFX,notional)
plazoFL, floatFlow = InstrumentFlow(Swap(),dConvFL,fechaTN,fechaHoy,fechaFin,paymentsFL,freqCountFL,notional,dfactor,plazo)
#aca esta el objetivo
sfixFlow = InstrumentFlow(Bond(),dConvFX,fechaTN,fechaHoy,fechaFin,tasa,paymentsFX,freqCountFX,notional,dsctCurve,plazoDsct)
indexDF = findall(x->x==plazoFL[paymentsFL], plazo)[1][1]
dfactor[indexDF]=falsePosition(Swap(),dConvFL,fechaTN,fechaHoy,fechaFin,paymentsFL,freqCountFL,notional,dfactor,plazo,dsctCurve,plazoDsct,sfixFlow,indexDF)
#end
