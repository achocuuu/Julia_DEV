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

##################################load Data#############################################
#Tasas:
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\bidaskGOBIERNOUDI.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor,:typeRate ,:mid]), names(dataMktRate))]
rates.mid = rates.mid / 100

#Definiciones/Datos
notional = 1.0
fechaStrHoy = "20200131"#una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = fechaHoy + Dates.Day(1)
fechaTN = shiftDate(fechaHoy + Dates.Day(0)) #Starting date
calendario = "cMXN"
n = length(rates[:, 1])
#Inicializacion de arreglos el total se separa
fechas = Array{Date,2}(undef, n, 2)
plazo = Array{Int64,2}(undef, n, 1)
dfactor = Array{Float64,2}(undef, n, 1)
dfactor[1:end] .= 1.0

#Short Curve OverNight
stIdx = minimum(findall(x->x=="OverNight", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="OverNight", rates.typeRate)[:])
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = shortCurve(zeroCurve(),rates,fechaHoy,fechaON,fechas,plazo,dfactor,ACT360(),Linear())

#mid Curve cash
stIdx = minimum(findall(x->x=="Cash", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Cash", rates.typeRate)[:])
dConvention = Array{Any,2}(undef,endIdx-stIdx+1,1)
dConvention .= ACT360.()
dfCompounding = Array{Any,2}(undef,endIdx-stIdx+1,1)
dfCompounding .= Linear.()
fechas[stIdx:endIdx,:], plazo[stIdx:endIdx], dfactor[stIdx:endIdx] = midCurve(Cash(),rates,fechaTN,fechaTN,fechas,plazo,dfactor,calendario,dConvention,dfCompounding)

#Calculo de flujos (Boostrapp)
stIdx = minimum(findall(x->x=="Bond", rates.typeRate)[:])
endIdx = maximum(findall(x->x=="Bond", rates.typeRate)[:])
fechas[stIdx:endIdx,1] .= fechaTN
fechas[stIdx:endIdx,2] = shiftDate.(addDays.(fechaTN,rates.tenor[stIdx:endIdx],calendario))
plazo[stIdx:endIdx] = Dates.value.(fechas[stIdx:endIdx,2] - fechaTN)
tenorsBoots = rates[in.(rates.typeRate, Ref(["Bond"])), :tenor] |> Array
paymentFreq = SemiAnnual()
for i=1:length(tenorsBoots) #tratamiento swap como bono
# i = 19
    tenorString = tenorsBoots[i]
    tenorData = tenorDef(tenorString)
    fechaFin = shiftDate(addDays(fechaTN,tenorString,calendario))
    tasa = getIndexRate(rates,tenorString)
    paymentsFl = payments(paymentFreq,fechaTN,fechaFin)#convert(Int,ceil(Dates.value(shiftDate(addDays(startingDate,tenorString,calendario))-startingDate)/Dates.value(shiftDate(addDays(startingDate,paymentFreq,calendario))-startingDate)))
    plazoVector, flujo = InstrumentFlow(Bond(),ACT360(),fechaTN,fechaTN,fechaFin,tasa,paymentsFl,paymentFreq,notional,cMXN())
    indexDF = findall(x->x==plazoVector[paymentsFl], plazo)[1][1]
    obj = 1.0
    dfactor[indexDF] = falsePosition(Bond(),ACT360(),fechaTN,fechaTN,fechaFin,tasa,paymentsFl,paymentFreq,notional,dfactor,plazo,obj,indexDF,cMXN())
end

curva = DataFrame()
curva.plazo = plazo[:]
curva.df= dfactor[:]


XLSX.writetable(string(fechaStrHoy, " Gobierno UDI Curve v4.xlsx"),
                    curva_t = (collect(DataFrames.eachcol(curva)),collect(DataFrames.names(curva)))
)
