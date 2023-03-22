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
fechaStrHoy = "20200402"#una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(1))
fechaTN = shiftDate(fechaHoy + Dates.Day(2)) #Starting date
calendario = "cUSD"
startingDate = fechaTN
paymentFreq = "6M"

fechas, plazo, dfactor = initCurve(rates,fechaHoy,fechaON,fechaTN)

#Calculo de flujos (Boostrapp) [Definir instrumentos a boostrappear]
tenorsBoots = rates[in.(rates.typeRate, Ref(["Swap"])), :tenor] |> Array
for i=1:length(tenorsBoots) #tratamiento swap como bono
    tenorString = tenorsBoots[i]
    tenorData = tenorDef(tenorString)
    payments = convert(Int,round(Dates.value(shiftDate(addDays(startingDate,tenorString,calendario))-startingDate)/(yieldConv(SemiAnnual()) * 365),digits=0))
    arraySize = collect(1:1:payments-1)
    fechasFin = Array{Date,2}(undef,payments,1)
    fechasFin[1:payments-1] = shiftDate.(shiftDay.(startingDate,SemiAnnual.(),arraySize[:]))
    fechasFin[payments] = shiftDate(addDays(startingDate,tenorString,calendario))

    fechasIni = Array{Date,2}(undef,payments,1)
    fechasIni[1] = startingDate
    fechasIni[2:payments] = fechasFin[1:payments-1]
    #flujofijo
    flujo = Array{Float64,2}(undef,payments,1)
    tasa = getIndexRate(rates,tenorString)
    flujo[1:payments-1] = notional * tasa * dayCountFactor.(ACT360.(),fechasIni[1:payments-1],fechasFin[1:payments-1])
    flujo[payments] = notional + notional * tasa * dayCountFactor(ACT360(),fechasIni[payments],fechasFin[payments])
    plazoVector = Dates.value.(fechasFin[:] - startingDate)

    indexDF = findall(x->x==plazoVector[payments], plazo)[1][1]
    dfactor[indexDF] = falsePosition(payments,flujo,plazo,dfactor,plazoVector,indexDF)
end

#solo si hay settlement date
function initCurveFinal(rates::DataFrame,fechaHoy::Date,startingDate::Date) #tratamiento cash
    n = length(rates[:, 1])
    cashn = length(rates[in.(rates.typeRate, Ref(["Cash"])), :tenor]) #hay que ver como programar el instrumento
    stnnIni = 2
    stnnFin = stnnIni + 1

    plazo = Array{Int64,2}(undef, n, 1)
    fechas = Array{Date,2}(undef, n, 1)
    fechas[1:stnnIni] = shiftDate.(addDays.(fechaHoy,rates.tenor[1:2],calendario))
    fechas[stnnFin:end] = shiftDate.(addDays.(startingDate,rates.tenor[stnnFin:end],calendario))
    plazo[1:stnnIni] = Dates.value.(fechas[1:stnnIni]-fechaHoy)
    plazo[stnnFin:end] = Dates.value.(fechas[stnnFin:end]-fechaHoy)
    return fechas, plazo
end

dfactorFinal = dfactor
dfactorFinal[3:end] = dfactor[2]*dfactor[3:end]
fechasFinal, plazoFinal = initCurveFinal(rates,fechaHoy,startingDate)

XLSX.writetable(string(fechaStrHoy, " ",curveInfo.name[1] , " Curva.xlsx"),
                    curva_t = (collect(DataFrames.eachcol(curvaFinal)),collect(DataFrames.names(curvaFinal))),
                    curva_settlement = (collect(DataFrames.eachcol(curva)),collect(DataFrames.names(curva)))
)
