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
##################################load Data#############################################
#Tasas:
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\bidaskCamaraBBG.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor,:typeRate ,:mid]), names(dataMktRate))]
rates.mid = rates.mid / 100

#Definiciones/Datos
notional = 1.0
n = length(rates[:, 1])
fechaStrHoy = "20200402"#una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(1))
fechaTN = shiftDate(fechaHoy + Dates.Day(2)) #Starting date
calendario = "cUSD"
paymentFreq = "6M"
indices = indexCurve(rates)

#Inicializacion de arreglos el total se separa
fechas = Array{Date,2}(undef, n, 2)
plazo = Array{Int64,2}(undef, n, 1)
dfactor = Array{Float64,2}(undef, n, 1)

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
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = midCurve(spotCurve(),Cash(),rates,fechaTN,fechas,plazo,dfactor,calendario,dConvention,dfCompounding)

#Calculo de flujos (Boostrapp)
stIdx = minimum(findall(x->x=="Bond", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Bond", rates.typeRate)[:])
dConv = ACT360()
freqCount = SemiAnnual()
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = longCurve(spotCurve(),Bond(),rates,fechaTN,fechas,plazo,dfactor,calendario,dConv,freqCount)

#traer a curva zero
fechasZero = Array{Date,2}(undef, n, 2)
plazoZero = Array{Int64,2}(undef, n, 1)
dfactorZero = Array{Float64,2}(undef, n, 1)

fechasZero = fechas
fechasZero[3:end,1] .= fechaHoy
plazoZero[1:2] = plazo[1:2]
plazoZero[3:end] = Dates.value.(fechasZero[3:end,2] - fechaHoy)
dfactorZero[1:2] = dfactor[1:2]
dfactorZero[3:end] = dfactor[3:end] * dfactor[2]

##Print curve
curva = DataFrame()
curva.fechaIni = fechas[:,1]
curva.fechaFin = fechas[:,2]
curva.plazo = plazo[:]
curva.df= dfactor[:]

curvaFinal = DataFrame()
curvaFinal.fechaIni = fechasZero[:,1]
curvaFinal.fechaFin = fechasZero[:,2]
curvaFinal.plazo = plazoZero[:]
curvaFinal.df= dfactorZero[:]

XLSX.writetable(string(fechaStrHoy, " Camara Curva.xlsx"),
                    curva_t = (collect(DataFrames.eachcol(curvaFinal)),collect(DataFrames.names(curvaFinal))),
                    curva_settlement = (collect(DataFrames.eachcol(curva)),collect(DataFrames.names(curva)))
)
