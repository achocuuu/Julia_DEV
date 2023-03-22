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
# include("curveFunctions.jl")
include("InstrumentDiscountFactor.jl")

##################################load Data#############################################
#Tasas:
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\bidaskOIS.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor,:typeRate ,:mid]), names(dataMktRate))]
rates.mid = rates.mid

#Definiciones/Datos
fechaStrHoy = "20200131"#una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
notional = 1.0
n = length(rates[:, 1])
settlementDays = 2
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(1))
fechaTN = shiftDate(fechaON + Dates.Day(settlementDays - 1))
calendario = "cUSD"
paymentFreq = "1Y"
indices = indexCurve(rates)

#Inicializacion de arreglos el total se separa
fechas = Array{Date,2}(undef, n, 2)
plazo = Array{Int64,2}(undef, n, 1)
dfactor = Array{Float64,2}(undef, n, 1)

#Short Curve OverNight
stIdx = minimum(findall(x->x=="OverNight", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="OverNight", rates.typeRate)[:])
fechas[1,1] = fechaHoy
fechas[1,2] = fechaON
fechas[2,1] = fechaON
fechas[2,2] = fechaTN #Starting date
plazo[1] = Dates.value(fechaON-fechaHoy)
plazo[2] = Dates.value(fechaTN-fechaHoy)
dfactor[1] = dfInstrument(kk(rates.typeRate[1]),ACT360(),Linear(),fechas[1,1],fechas[1,2],rates.mid[1])
dfactor[2] = dfInstrument(kk(rates.typeRate[2]),ACT360(),Linear(),fechas[2,1],fechas[2,2],rates.mid[2]) * dfactor[1]

#mid Curve
stIdx = minimum(findall(x->x=="Cash", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Cash", rates.typeRate)[:])
fechas[stIdx:endIdx,1] .= fechaTN
fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaTN,rates.tenor[stIdx:endIdx],calendario))
plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaTN)
dfactor[stIdx:endIdx] = dfInstrument.(kk.(rates.typeRate[stIdx:endIdx]),ACT360.(),Linear.(),fechas[2,2],fechas[stIdx:endIdx,2],rates.mid[stIdx:endIdx])

#Calculo de flujos (Boostrapp)
stIdx = minimum(findall(x->x=="Bond", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Bond", rates.typeRate)[:])
fechas[stIdx:endIdx,1] .= fechaTN
fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaTN,rates.tenor[stIdx:endIdx],calendario))
plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaTN)
tenorsBoots = rates[in.(rates.typeRate, Ref(["Bond"])), :tenor] |> Array
startingDate = fechaTN
for i=1:length(tenorsBoots) #tratamiento swap como bono
# i = 5
    tenorString = tenorsBoots[i]
    tenorData = tenorDef(tenorString)
    fechaFin = shiftDate(addDays(startingDate,tenorString,calendario))
    tasa = getIndexRate(rates,tenorString)
    payments = convert(Int,ceil(Dates.value(shiftDate(addDays(startingDate,tenorString,calendario))-startingDate)/Dates.value(shiftDate(addDays(startingDate,paymentFreq,calendario))-startingDate)))
    plazoVector, flujo = InstrumentFlow(Bond(),ACT360(),startingDate,fechaFin,tasa,payments,Annual(),notional)
    indexDF = findall(x->x==plazoVector[payments], plazo)[1][1]
    dfactor[indexDF] = falsePosition(payments,flujo,plazo,dfactor,plazoVector,indexDF)
end

##Print curve
curva = DataFrame()
curva.fechaIni = fechas[:,1]
curva.fechaFin = fechas[:,2]
curva.plazo = plazo[:]
curva.df= dfactor[:]


XLSX.writetable(string(fechaStrHoy, " OIS Curva.xlsx"),
                    # curva_t = (collect(DataFrames.eachcol(curvaFinal)),collect(DataFrames.names(curvaFinal))),
                    curva_settlement = (collect(DataFrames.eachcol(curva)),collect(DataFrames.names(curva)))
)
